; ==============================================
; FAT32 File Loader Driver (16-bit Version)
; All temporary buffers are within 0xA000~0xFFFF
; Interface:
;   Partition LBA stored at [0x7E00]
;   DS:SI = 8.3 filename (11 bytes)
;   ES:BX = load destination
;   Return: CF = 0 success, CF = 1 error
; ==============================================

%define FAT32_DEBUG 1
; Safe memory regions (all in 0xA000~0xFFFF segment)
%define BPB_CACHE_OFF     0xA000
%define ROOT_CACHE_OFF    0xA200
%define FAT_CACHE_OFF     0xA600
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
    mov  eax, [0x7E00]
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
    call fat32_calculate_data_start
    mov   [data_start], edx
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

    ; Search file and get start cluster
    mov  si, [bp + 6]
    call fat32_get_start_cluster
    jc   .err_not_found

%if FAT32_DEBUG
    mov  si, fat32_msg_found
    call print
%endif

.load_file_init:
    ; Read current cluster
    mov  eax, [file_start_cluster]
    mov  es, [save_es]
    mov  bx, [save_bx]

    ; Load FAT to memory
    call fat32_load_fat_to_memory

.load_file_loop:
    ; Get next cluster
    call fat32_load_cluster      ; Load one full cluster
    jc   .err_read_file
  
    ; The fat32_load_cluster automatically
    ; Moved the address, so no need anymore

    ; Check is it the file_end sign
    cmp  eax, 0x0FFFFFF8
    jae  .done

    ; Get next cluster
    call fat32_next_cluster
    jc   .err_read_file

    jmp .load_file_loop

.done:
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
; fat32_calculate_data_start
; Calculate FAT32 data area start LBA
; In:  BPB cached at BPB_CACHE_SEG:BPB_CACHE_OFF
;      Partition LBA at [es:0x7E00]
; Out: EDX = data area start LBA
; ==============================================
fat32_calculate_data_start:
    push ebx
    push ecx
    push esi
    push edi

    mov  ax, BPB_CACHE_SEG
    mov  es, ax

    ; Calculate FAT count * sectors per FAT
    movzx eax, byte [es:BPB_CACHE_OFF + 0x10]
    mov   ebx, [es:BPB_CACHE_OFF + 0x24]
    xor   edx, edx
    mul   ebx

    ; Add reserved sectors
    movzx ecx, word [es:BPB_CACHE_OFF + 0x0E]
    add   eax, ecx

    ; Add partition start LBA
    add   eax, [es:0x7E00]

    ; Output in EDX
    mov   edx, eax

    pop edi
    pop esi
    pop ecx
    pop ebx
    ret

; ==============================================
; fat32_get_start_cluster
; Search root directory and get file first cluster
; In:  DS:SI = 8.3 filename (11 bytes uppercase)
; Out: CF=0 success, EAX = start cluster
;      CF=1 error (not found / bad cluster)
; ==============================================
fat32_get_start_cluster:
    push ebx
    push ecx
    push edx
    push es

    ; Search for file in root directory (manual compare, no cmpsb)
    push es
    mov  ax, ROOT_CACHE_SEG
    mov  es, ax
    mov  di, ROOT_CACHE_OFF
    mov  cx, 512

.search_loop:
    ; Deleted
    cmp  byte [es:di], 0xE5
    je   .next_entry

    ; LFN 
    mov  al, [es:di + 11]
    cmp  al, 0x0F
    je   .next_entry

    mov  bx, 0
.try_match:
    mov  al, [ds:si + bx]
    mov  dl, [es:di + bx]
    cmp  al, dl
    jne  .not_match

    inc  bx
    cmp  bx, 11
    jb   .try_match

    ; All 11 bytes matched
    jmp  .file_found

.not_match:
.next_entry:
    add  di, 32
    loop .search_loop

    ; Not found
    pop  es
    jmp  .fail

.file_found:
    ; Save the offset of the found directory entry
    mov  [found_dir_offset], di
    pop  es

    ; Get file start cluster
    push es
    mov  ax, ROOT_CACHE_SEG
    mov  es, ax
    mov  di, [found_dir_offset]

    ; High 16 bits at 0x14, low 16 bits at 0x1A
    movzx eax, word [es:di + 0x14]
    shl  eax, 16
    movzx ebx, word [es:di + 0x1A]
    or   eax, ebx
    and  eax, 0x0FFFFFFF

    ; Save to global variables
    mov  [file_start_cluster], eax
    mov  ecx, [es:di + 0x1C]
    mov  [file_size], ecx

    pop  es

    ; Validate cluster
    cmp  eax, 2
    jb   .fail
    cmp  eax, 0x0FFFFFF8
    jae  .fail

    ; Now EAX = start cluster, return it
    clc
    jmp  .exit

.fail:
    stc

.exit:
    pop  es
    pop edx
    pop ecx
    pop ebx
    ret


; ==============================================
; fat32_load_cluster
; Load one cluster from FAT32
; In:  EAX = cluster number
;      ES:BX = destination
; ==============================================
fat32_load_cluster:
    push eax

    ; Check is it end sign
    cmp eax, 0x0FFFFFF8
    jae .set_end_and_return

    sub  eax, 2
    jc   .error

    push eax
    mov  ax, BPB_CACHE_SEG
    mov  fs, ax
    pop  eax
    movzx ecx, byte [fs:BPB_CACHE_OFF + 0x0D]  ; Sectors per cluster
    mul  ecx                                   ; EDX:EAX = (cluster-2)*SecPerClust
    add  eax, [data_start]
    adc  edx, 0

.read:
    movzx cx, byte[fs:BPB_CACHE_OFF + 0x0D]    ; SPC times
    call fat32_read_lba
    jc   .error

    ; Update next addr and return
    shl cx, 9
    add bx, cx
    jnc .return

    push ax
    mov ax, es
    add ax, 0x1000
    mov es, ax
    pop ax
    mov bx, 0

.return:
    clc
    pop  eax
    ret

.set_end_and_return:
    mov eax, 0x0FFFFFF8     ; Force set
    jmp .return

.error:
    stc
    pop  eax
    ret

; ==============================================
; fat32_next_cluster
; Get next cluster from FAT32 FAT
; In:  EAX = current cluster (32-bit cluster number)
; Out: EAX = next cluster
;      CF = 0 on success
;      CF = 1 on failure
; ==============================================
fat32_next_cluster:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push fs
    push es

    ; Check the current cluster
    cmp eax, 0x0FFFFFF8
    jae .return

    ; Get the offset
    mov esi, eax
    shl esi, 2
    
    ; Load the target cluster
    mov ax, FAT_CACHE_SEG
    mov fs, ax
    mov bx, FAT_CACHE_OFF
    add bx, si
    mov eax, [fs:bx]
    and eax, 0x0FFFFFFF

    ; Check is that available
    cmp eax, 0 
    je  .error

    cmp eax, 0x0FFFFFF7
    je  .error

.return:
    clc

.pop_out:
    pop es 
    pop fs
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

.error:
    stc
    jmp .pop_out

; ==============================================
; fat32_load_fat_to_memory
; Load FAT table into cache, only call ONCE
; ==============================================
fat32_load_fat_to_memory:
    push eax
    push ebx
    push ecx
    push es

    ; Get ReservedSector and FATSz32 from BPB
    mov ax, BPB_CACHE_SEG
    mov fs, ax
    movzx eax, word [fs:BPB_CACHE_OFF + 0x0E]   ; BPB_RsvdSecCnt
    mov ebx, [0x7E00] ; Partition start LBA
    add eax, ebx

    ; Load FAT table
    push es
    mov cx, FAT_CACHE_SEG
    mov es, cx
    mov bx, FAT_CACHE_OFF
    mov cx, 32
    call fat32_read_lba
    pop es

    pop es
    pop ecx
    pop ebx
    pop eax
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

.fill_dap:
    ; Fill DAP structure for BIOS extended read
    mov word [dap + 2], cx      ; Number of sectors to read
    mov word [dap + 4], bx      ; Buffer offset
    mov word [dap + 6], es      ; Buffer segment
    mov dword [dap + 8], eax    ; LBA low 32 bits
    mov dword [dap + 12], 0     ; LBA high 32 bits (set to 0)

    ; Issue BIOS disk interrupt
    push eax
    xor ax, ax
    mov fs, ax
    pop eax
    mov si, dap
    mov ah, 0x42
    mov dl, [fs:0x0500]   ; Disk number stored by stage0
    int 0x13
    jc .disk_error

    popad
    ret

.disk_error:
    popad
    stc
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
fat32_msg_init     db  '[FAT32] [INFO] Initializing...',13,10,0
fat32_msg_bpb_ok   db  '[FAT32] [INFO] Successfully read BPB',13,10,0
fat32_msg_root_ok  db  '[FAT32] [INFO] Root dir loaded',13,10,0
fat32_msg_found    db  '[FAT32] [INFO] File discovered',13,10,0
fat32_msg_done     db  '[FAT32] [INFO] Load complete',13,10,0

fat32_err_bpb      db  '[FAT32] [ERROR] Read BPB failed',13,10,0
fat32_err_root     db  '[FAT32] [ERROR] Read root failed',13,10,0
fat32_err_notfound db  '[FAT32] [ERROR] File not found',13,10,0
fat32_err_cluster  db  '[FAT32] [ERROR] bad cluster',13,10,0
fat32_err_file     db  '[FAT32] [ERROR] Read file failed',13,10,0
%endif
