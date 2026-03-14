[BITS 16]

; ==============================================
; FAT32 File Loader Driver (Safe Memory Version)
; All temporary buffers are within 0xA000~0xFFFF
; Interface:
;   Partition LBA stored at [0x7DF0]
;   DS:SI = 8.3 filename (11 bytes)
;   ES:BX = load destination
;   Return: CF = 0 success, CF = 1 error
; ==============================================

%define FAT32_DEBUG 1
; Safe memory regions (all in 0xA000~0xFFFF segment)
%define BPB_CACHE_SEG     0xA000   ; BPB cache at 0xA000:0x0000 (linear 0xA0000)
%define ROOT_CACHE_SEG    0xA200   ; Root dir cache at 0xA200:0x0000 (linear 0xA2000)
%define FAT_CACHE_SEG     0xA400   ; FAT cache at 0xA400:0x0000 (linear 0xA4000)
%define BPB_CACHE_OFF     0x0000
%define ROOT_CACHE_OFF    0x0000
%define FAT_CACHE_OFF     0x0000

load_file:
    pushad
    push es
    mov  bp, sp

%if FAT32_DEBUG
    mov  si, fat32_msg_init
    call print
%endif

    ; Read FAT32 BPB from partition start (safe buffer)
    mov  eax, [0x7DF0]
    mov  cx, 1
    push es
    mov  ax, BPB_CACHE_SEG
    mov  es, ax
    mov  bx, BPB_CACHE_OFF
    call fat32_read_lba
    pop  es
    jc   .err_read_bpb

%if FAT32_DEBUG
    mov  si, fat32_msg_bpb_ok
    call print
%endif

    ; Calculate data area start LBA (fixed 32-bit calculation)
    push es
    mov  ax, BPB_CACHE_SEG
    mov  es, ax
    movzx eax, byte [es:BPB_CACHE_OFF + 16]  ; Number of FATs
    mov  ebx, [es:BPB_CACHE_OFF + 36]        ; Sectors per FAT
    pop  es
    mul  ebx                                  ; EDX:EAX = nFats * SecPerFAT
    push es
    mov  ax, BPB_CACHE_SEG
    mov  es, ax
    mov  ecx, [es:BPB_CACHE_OFF + 14]         ; Reserved sectors
    pop  es
    add  eax, ecx
    adc  edx, 0                               ; handle carry
    add  eax, [0x7DF0]                        ; Add partition base LBA
    adc  edx, 0
    mov  [data_start], eax                    ; store 32-bit LBA

    ; Load root directory cluster (safe buffer)
    push es
    mov  ax, BPB_CACHE_SEG
    mov  es, ax
    mov  eax, [es:BPB_CACHE_OFF + 44]         ; Root directory cluster
    pop  es
    push es
    mov  ax, ROOT_CACHE_SEG
    mov  es, ax
    mov  bx, ROOT_CACHE_OFF
    call fat32_load_cluster
    pop  es
    jc   .err_read_root

%if FAT32_DEBUG
    mov  si, fat32_msg_root_ok
    call print
%endif

    ; Search for file in root directory (safe buffer)
    push es
    mov  ax, ROOT_CACHE_SEG
    mov  es, ax
    mov  di, ROOT_CACHE_OFF
    mov  cx, 16 * 16                          ; Max directory entries
.search_loop:
    push si
    push di
    mov  cx, 11
    repe cmpsb
    pop  di
    pop  si
    je   .file_found

    add  di, 32
    loop .search_loop
    pop  es
    jmp  .err_not_found

.file_found:
    pop  es  ; restore ES from ROOT_CACHE_SEG
%if FAT32_DEBUG
    mov  si, fat32_msg_found
    call print
%endif

    ; Get file start cluster
    push es
    mov  ax, ROOT_CACHE_SEG
    mov  es, ax
    mov  eax, [es:ROOT_CACHE_OFF + 20]
    shl  eax, 16
    mov  ax, [es:ROOT_CACHE_OFF + 26]
    pop  es

    ; Validate cluster
    cmp  eax, 0x0FFFFFF8
    jae  .err_bad_cluster

    ; Restore original ES for loading
    pop  es

.load_file_loop:
    push bx
    push es
    call fat32_load_cluster
    pop  es
    pop  bx
    jc   .err_read_file

    call fat32_next_cluster
    cmp  eax, 0x0FFFFFF8
    jb   .load_file_loop

%if FAT32_DEBUG
    mov  si, fat32_msg_done
    call print
%endif

    clc
    jmp  .exit

; ==============================================
; Error handlers with debug messages
; ==============================================
.err_read_bpb:
%if FAT32_DEBUG
    mov  si, fat32_err_bpb
    call print
%endif
    jmp  .fail

.err_read_root:
%if FAT32_DEBUG
    mov  si, fat32_err_root
    call print
%endif
    jmp  .fail

.err_not_found:
%if FAT32_DEBUG
    mov  si, fat32_err_notfound
    call print
%endif
    jmp  .fail

.err_bad_cluster:
%if FAT32_DEBUG
    mov  si, fat32_err_cluster
    call print
%endif
    jmp  .fail

.err_read_file:
%if FAT32_DEBUG
    mov  si, fat32_err_file
    call print
%endif

.fail:
    stc

.exit:
    mov  sp, bp
    pop  es
    popad
    ret

; ==============================================
; fat32_load_cluster
; Load one cluster from FAT32
; In:  EAX = cluster number
;      ES:BX = destination
; ==============================================
fat32_load_cluster:
    push eax
    sub  eax, 2
    jc   .error

    push es
    mov  ax, BPB_CACHE_SEG
    mov  es, ax
    movzx ecx, byte [es:BPB_CACHE_OFF + 13]  ; Sectors per cluster
    pop  es
    mul  ecx                                  ; EDX:EAX = (cluster-2)*SecPerClust
    add  eax, [data_start]
    adc  edx, 0
    mov  cx, 1

.read_loop:
    call fat32_read_lba
    jc   .error
    add  bx, 512
    inc  eax
    loop .read_loop

    pop  eax
    clc
    ret

.error:
    pop  eax
    stc
    ret

; ==============================================
; fat32_next_cluster
; Get next cluster from FAT32 FAT
; In:  EAX = current cluster
; Out: EAX = next cluster
; ==============================================
fat32_next_cluster:
    push ebx
    push es
    mov  ebx, eax
    shr  ebx, 7
    add  eax, ebx
    mov  ebx, eax
    shr  ebx, 9
    push es
    mov  ax, BPB_CACHE_SEG
    mov  es, ax
    add  ebx, [es:BPB_CACHE_OFF + 14]         ; Reserved sectors
    pop  es
    add  ebx, [0x7DF0]                        ; Add partition base LBA

    push eax
    mov  eax, ebx
    push es
    mov  ax, FAT_CACHE_SEG
    mov  es, ax
    mov  bx, FAT_CACHE_OFF
    mov  cx, 1
    call fat32_read_lba
    pop  es
    jc   .error_fat

    pop  eax
    and  eax, 0x7F
    shl  eax, 2
    push es
    mov  ax, FAT_CACHE_SEG
    mov  es, ax
    mov  eax, [es:FAT_CACHE_OFF + eax]
    pop  es
    and  eax, 0x0FFFFFFF

    pop  es
    pop  ebx
    clc
    ret

.error_fat:
    pop  eax
    pop  es
    pop  ebx
    stc
    ret

; ==============================================
; fat32_read_lba
; Read sectors using BIOS extended read
; In:  EDX:EAX = LBA
;      CX = sector count
;      ES:BX = buffer
; ==============================================
fat32_read_lba:
    pusha
    mov  word [dap + 2], cx
    mov  [dap + 8], eax
    mov  [dap + 4], bx
    mov  [dap + 6], es
    mov  si, dap
    mov  ah, 0x42
    int  0x13
    popa
    ret

; ==============================================
; Data & Messages
; ==============================================
data_start  dd  0

dap:
    db  0x10, 0
    dw  0, 0, 0
    dq  0

%if FAT32_DEBUG
fat32_msg_init     db  '[FAT32] Initializing...',13,10,0
fat32_msg_bpb_ok   db  '[FAT32] BPB read OK',13,10,0
fat32_msg_root_ok  db  '[FAT32] Root dir loaded',13,10,0
fat32_msg_found    db  '[FAT32] File found',13,10,0
fat32_msg_done     db  '[FAT32] Load complete',13,10,0

fat32_err_bpb      db  '[FAT32] ERR: read BPB failed',13,10,0
fat32_err_root     db  '[FAT32] ERR: read root failed',13,10,0
fat32_err_notfound db  '[FAT32] ERR: file not found',13,10,0
fat32_err_cluster  db  '[FAT32] ERR: bad cluster',13,10,0
fat32_err_file     db  '[FAT32] ERR: read file failed',13,10,0
%endif
