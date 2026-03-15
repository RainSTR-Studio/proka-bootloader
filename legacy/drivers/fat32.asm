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
%define BPB_CACHE_OFF     0xA000
%define ROOT_CACHE_OFF    0xA200
%define FAT_CACHE_OFF     0xA400
%define BPB_CACHE_SEG     0x0000
%define ROOT_CACHE_SEG    0x0000
%define FAT_CACHE_SEG     0x0000

load_file:
    pushad
    push es
    mov  bp, sp
    cld

    ; Save ES:BX 
    mov  [save_es], es
    mov  [save_bx], bx

    ; Ensure DS points to our code segment (where filename and data are)
    push cs
    pop  ds

%if FAT32_DEBUG
    mov  si, fat32_msg_init
    call print
%endif

    ; Read FAT32 BPB from partition start (safe buffer)
    mov  eax, [0x7DF0]
    mov  edx, eax
    mov  cx, 1
    push es
    mov  ax, BPB_CACHE_SEG
    mov  es, ax
    mov  bx, BPB_CACHE_OFF
    mov  eax, edx
    call fat32_read_lba
    pop  es
    jc   .err_read_bpb

%if FAT32_DEBUG
    mov  si, fat32_msg_bpb_ok
    call print
%endif

    ; Calculate data area start LBA (fixed 32-bit calculation)
    pushad
    xor  ax, ax
    mov  es, ax

    ; Calculate FAT count * sectors per FAT
    movzx eax, byte [es:0xA000 + 16]      ; Number of FATs
    mov   ebx, [es:0xA000 + 36]            ; Sectors per FAT
    xor   edx, edx
    mul   ebx                              ; eax = FATs * sectors per FAT

    ; Add reserved sectors (16-bit field!)
    movzx ecx, word [es:0xA000 + 14]       ; Reserved sectors
    add   eax, ecx

    ; Add partition start LBA
    add   eax, [es:0x7DF0]                  ; Partition start LBA

    ; Store final data area start LBA
    mov   [data_start], eax
    popad

    ; Load root directory cluster (safe buffer)
    push es
    mov  ax, BPB_CACHE_SEG
    mov  es, ax
    mov  eax, [es:BPB_CACHE_OFF + 44]      ; Root directory cluster
    mov  edx, eax
    pop  es
    push es
    mov  ax, ROOT_CACHE_SEG
    mov  es, ax
    mov  bx, ROOT_CACHE_OFF
    mov  eax, edx
    call fat32_load_cluster
    pop  es
    jc   .err_read_root

%if FAT32_DEBUG
    mov  si, fat32_msg_root_ok
    call print
%endif

    ; Search for file in root directory (manual compare, no cmpsb)
    push es
    mov  ax, ROOT_CACHE_SEG
    mov  es, ax
    mov  di, ROOT_CACHE_OFF
    mov  cx, 0xFFFF
    mov  si, [bp + 6]

.search_loop:
    cmp  byte [es:di], 0xE5
    je   .next_entry

    mov  bx, 0
.try_match:
    mov  al, [ds:si + bx]
    mov  dl, [es:di + bx]

    mov  al, [ds:si + bx]
    mov  dl, [es:di + bx]
    cmp  al, dl
    jne  .not_match

    inc  bx
    cmp  bx, 11
    jb   .try_match

    ; All 11 bytes matched
    jmp  .file_found_save

.not_match:
.next_entry:
    add  di, 32
    loop .search_loop

.err_not_found_pop:
    pop  es
    jmp  .err_not_found


.file_found_save:
    ; Save the offset of the found directory entry
    mov  [found_dir_offset], di
    pop  es                    ; Restore caller's ES
    jmp  .file_found_continue

.file_found_continue:
%if FAT32_DEBUG
    mov  si, fat32_msg_found
    call print
%endif

    ; Get file start cluster using saved offset
    push es
    mov  ax, ROOT_CACHE_SEG
    mov  es, ax
    mov  di, [found_dir_offset]        ; Load saved entry offset

    ; Read 28-bit starting cluster from directory entry
    ; High 16 bits: offset 0x14, low 16 bits: offset 0x1A
    movzx  eax, word [es:di + 0x14]  ; Get high 16 bits of cluster
    shl  eax, 16                     ; Shift to upper half
    movzx  ebx, word [es:di + 0x1A]  ; Get low 16 bits of cluster
    or  eax, ebx                    ; Combine into 32-bit value
    and  eax, 0x0FFFFFFF             ; Keep only FAT32 28-bit cluster
    mov  [file_start_cluster], eax   ; Save start cluster

    ; Read file size (4 bytes at offset 0x1C)
    mov  eax, [es:di + 0x1C]         ; Get 32-bit file length
    mov  [file_size], eax            ; Save file size

    pop  es
    and  eax, 0x0FFFFFFF

    ; Validate cluster
    mov  eax, [file_start_cluster]
    cmp  eax, 2                     ; clusters start at 2
    jb   .err_bad_cluster
    cmp  eax, 0x0FFFFFF8           ; end-of-chain marker
    jae  .err_bad_cluster

.load_file_loop:
    ; Read current cluster
    mov    eax, [file_start_cluster]
    mov    es, [save_es]
    mov    bx, [save_bx]

    call   fat32_load_cluster      ; Load one full cluster
    jc     .err_read_file

    ; Advance destination by one cluster (1 sector = 512 bytes)
    add    word [save_bx], 512

    ; Get next cluster in chain
    mov    eax, [file_start_cluster]
    call   fat32_next_cluster
    mov    [file_start_cluster], eax

    ; Continue if not end of cluster chain
    cmp    eax, 0x0FFFFFF8
    jb     .load_file_loop


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
    push eax
    mov  ax, BPB_CACHE_SEG
    mov  es, ax
    pop  eax
    movzx ecx, byte [es:BPB_CACHE_OFF + 13]  ; Sectors per cluster
    pop  es 
    mul  ecx                                  ; EDX:EAX = (cluster-2)*SecPerClust
    add  eax, [data_start]
    adc  edx, 0
    mov  cx, 1                                 ; Currently hardcoded to 1 sector per cluster

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

    ; FAT sector LBA = partition start + reserved sectors + (cluster / 128)
    mov ebx, eax
    shr ebx, 7                     ; ebx = cluster / 128
    push es
    mov ax, BPB_CACHE_SEG
    mov es, ax
    add ebx, [es:BPB_CACHE_OFF + 14]   ; + Reserved sectors
    pop es
    add ebx, [0x7DF0]                   ; + partition start LBA

    ; Read FAT sector into cache
    push eax
    mov eax, ebx
    push es
    mov ax, FAT_CACHE_SEG
    mov es, ax
    mov bx, FAT_CACHE_OFF
    mov cx, 1
    call fat32_read_lba
    pop es
    jc .error_fat

    pop eax
    ; Offset in FAT sector = (cluster & 0x7F) * 4
    and eax, 0x7F
    shl eax, 2
    push es
    mov ax, FAT_CACHE_SEG
    mov es, ax
    mov eax, [es:FAT_CACHE_OFF + eax]   ; Read the cluster entry
    pop es
    and eax, 0x0FFFFFFF                  ; Mask to 28-bit valid value

    pop es
    pop ebx
    clc
    ret

.error_fat:
    pop eax
    pop es
    pop ebx
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
    pushad                         ; Save all 32-bit registers (important!)

    ; Fill DAP structure for BIOS extended read
    mov word [dap + 2], cx      ; Number of sectors to read
    mov word [dap + 4], bx      ; Buffer offset
    mov word [dap + 6], es      ; Buffer segment
    mov dword [dap + 8], eax    ; LBA low 32 bits
    mov dword [dap + 12], 0     ; LBA high 32 bits (set to 0)

    ; Issue BIOS disk interrupt
    mov si, dap
    mov ah, 0x42
    mov dl, [0x0500]             ; Disk number stored by previous stage (e.g., stage1)
    int 0x13
    jc .disk_error

    popad
    ret

.disk_error:
    popad
    sti
    ret

; ==============================================
; Data & Messages
; ==============================================
data_start          dd  0          ; Data area start LBA (calculated)
found_dir_offset    dw  0          ; Offset of found directory entry within root buffer
file_start_cluster  dd  0
file_size           dd  0

save_es    dw  0 
save_bx    dw  0

dap:
    db  0x10        ; 0: size of DAP (16 bytes)
    db  0           ; 1: reserved, must be 0
    dw  1           ; 2: number of sectors to read
    dw  0           ; 4: buffer offset
    dw  0           ; 6: buffer segment
    dq  0           ; 8: 64-bit LBA

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
