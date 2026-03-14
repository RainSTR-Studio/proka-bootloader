; Proka Bootloader - The Bootloader for Proka OS
; Copyright (C) RainSTR Studio 2026, All Rights Reserved.
;
; FAT32 Driver Core - 16-bit Real Mode File Reader
; Input: DS:SI = filename (8.3 format), ES:BX = target memory, DL = drive number
; Output: CF=1 on error, AX = error code (0=success)

; Constants
FAT32_EOC        equ 0x0FFFFFF8  ; End of cluster marker
DIR_ENTRY_SIZE   equ 32
ATTR_ARCHIVE     equ 0x20

; FAT32 Structures with Correct DAP Access
; ----------------------------------------

; Disk Address Packet (DAP) Structure
struc DAP
    .size:      resb 1
    .unused:    resb 1
    .count:     resw 1  ; Number of sectors
    .offset:    resw 1  ; Buffer offset
    .segment:   resw 1  ; Buffer segment
    .lba_low:   resd 1  ; LBA low 32-bits
    .lba_high:  resd 1  ; LBA high 32-bits
endstruc

; Global DAP Instance (initialized)
dap:
    istruc DAP
        at DAP.size,      db 0x10
        at DAP.unused,    db 0
        at DAP.count,     dw 0
        at DAP.offset,    dw 0
        at DAP.segment,   dw 0
        at DAP.lba_low,   dd 0
        at DAP.lba_high,  dd 0
    iend

; DBR Structure
struc DBR
    .jump_code          resb 3
    .oem_name           resb 8
    .bytes_per_sector   resw 1
    .sectors_per_cluster resb 1
    .reserved_sectors   resw 1
    .fat_count          resb 1
    .root_entries       resw 1
    .total_sectors16    resw 1
    .media_type         resb 1
    .sectors_per_fat16  resw 1
    .sectors_per_track  resw 1
    .heads_count        resw 1
    .hidden_sectors     resd 1
    .total_sectors32    resd 1
    .sectors_per_fat32  resd 1
    .flags              resw 1
    .version            resw 1
    .root_cluster       resd 1
    .fsinfo_sector      resw 1
    .backup_boot_sector resw 1
    .reserved           resb 12
    .drive_number       resb 1
    .nt_flags           resb 1
    .signature          resb 1
    .volume_id          resd 1
    .volume_label       resb 11
    .system_id          resb 8
endstruc

struc BPB
    .jmp:           resb 3
    .oem:           resb 8
    .bytes_per_sec: resw 1
    .sec_per_clust: resb 1
    .reserved_sec:  resw 1
    .fat_count:     resb 1
    .root_entries:  resw 1
    .total_sec16:   resw 1
    .media_type:    resb 1
    .fat_size16:    resw 1
    .sec_per_track: resw 1
    .heads:         resw 1
    .hidden_sec:    resd 1
    .total_sec32:   resd 1
    .fat_size32:    resd 1
    .ext_flags:     resw 1
    .fs_version:    resw 1
    .root_cluster:  resd 1
    .fs_info:       resw 1
    .backup_boot:   resw 1
    .reserved:      resb 12
    .drive_num:     resb 1
    .nt_flags:      resb 1
    .signature:     resb 1
    .volume_id:     resd 1
    .volume_label:  resb 11
    .fs_type:       resb 8
endstruc

bpb: istruc BPB
    iend

dbr_buffer times 512 db 0
fat_buffer times 512 db 0
current_cluster dd 0
cluster_low dw 0
cluster_high dw 0
fat_sector_low dw 0
fat_sector_high dw 0
root_dir_sector_low dw 0
root_dir_sector_high dw 0
data_sector_low dw 0
data_sector_high dw 0
data_start_low  dd 0
data_start_high dd 0
fat_size_low dw 0
fat_size_high dw 0
fat_start_low dw 0
fat_start_high dw 0
root_start_low dw 0
root_start_high dw 0
target_segment dw 0
target_offset dw 0
sectors_per_cluster db 0
bytes_per_sector dw 0
boot_drive db 0
buffer times 512 db 0

; Main function to load file
; Input: DS:SI=filename, ES:BX=target, DL=drive
; Output: CF=0 success, CF=1 error
load_file:
    mov [boot_drive], dl
    mov [target_segment], es
    mov [target_offset], bx

    ; Read BPB (LBA 0)
    mov word [dap + DAP.lba_low], 0
    mov word [dap + DAP.lba_low+2], 0
    call read_sector
    jc .error

    ; Copy BPB
    mov si, buffer
    mov di, bpb
    mov cx, BPB_size
    rep movsb

    ; Calculate FAT32 parameters
    mov ax, [bpb + BPB.reserved_sec]
    mov [fat_start_low], ax
    mov word [fat_start_high], 0

    mov ax, [bpb + BPB.fat_size32]
    mov [fat_size_low], ax
    mov ax, [bpb + BPB.fat_size32+2]
    mov [fat_size_high], ax

    mov al, [bpb + BPB.sec_per_clust]
    mov [sectors_per_cluster], al

    ; Calculate root directory location
    mov ax, [bpb + BPB.root_cluster]
    mov dx, [bpb + BPB.root_cluster+2]
    call cluster_to_lba
    mov [root_start_low], ax
    mov [root_start_high], dx

    ; Find file in root directory
    call find_file
    jc .error

    ; Read file clusters
    mov ax, [cluster_low]
    mov dx, [cluster_high]
    call read_file_clusters
    jc .error

    clc
    ret
.error:
    stc
    ret

; Read sector using LBA (INT 13h AH=42h)
; Input: DX:AX=LBA (32-bit)
read_sector:
    mov [dap + DAP.lba_low], ax
    mov [dap + DAP.lba_low+2], dx
    mov word [dap + DAP.count], 1
    mov word [dap + DAP.offset], buffer
    mov word [dap + DAP.segment], 0

    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap
    int 0x13
    ret

; Read sector to target memory
; Input: DX:AX=LBA, CX=sectors
read_sector_to_target:
    mov [dap + DAP.lba_low], ax
    mov [dap + DAP.lba_low+2], dx
    mov [dap + DAP.count], cx
    mov ax, [target_offset]
    mov [dap + DAP.offset], ax
    mov ax, [target_segment]
    mov [dap + DAP.segment], ax

    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap
    int 0x13
    jc .error

    ; Update target pointer
    mov ax, [dap + DAP.count]
    mov dx, 0
    shl ax, 1  ; sectors * 512 / 16
    rcl dx, 1
    shl ax, 1
    rcl dx, 1
    shl ax, 1
    rcl dx, 1
    shl ax, 1
    rcl dx, 1
    shl ax, 1
    rcl dx, 1
    
    add [target_offset], ax
    mov ax, dx
    adc [target_segment], ax
    
    clc
    ret
.error:
    stc
    ret

; Read file clusters
; Input: DX:AX=first cluster
read_file_clusters:
    mov [cluster_low], ax
    mov [cluster_high], dx
.next_cluster:
    ; Check end of chain (DX:AX >= 0x0FFFFFF8)
    mov bx, dx
    cmp bx, 0x0FFF
    ja .check_high
    jb .read_cluster
.check_high:
    mov bx, ax
    cmp bx, 0xFFF8
    jae .done
.read_cluster:
    mov ax, [cluster_low]
    mov dx, [cluster_high]
    call cluster_to_lba
    movzx cx, byte [sectors_per_cluster]
    call read_sector_to_target
    jc .error

    ; Get next cluster from FAT
    mov ax, [cluster_low]
    mov dx, [cluster_high]
    call read_fat_entry
    mov [cluster_low], ax
    mov [cluster_high], dx
    jmp .next_cluster
.done:
    clc
    ret
.error:
    stc
    ret

; Read FAT entry for given cluster
; Input: DX:AX=cluster
; Output: DX:AX=next cluster
read_fat_entry:
    push bx
    push cx
    push si
    push di
    
    ; Calculate FAT sector = fat_start + (cluster / 128)
    mov bx, ax
    mov cx, dx  ; CX:BX = cluster
    
    ; Divide by 128 (shift right 7)
    mov si, bx
    mov di, cx
    shr di, 1
    rcr si, 1
    shr di, 1
    rcr si, 1
    shr di, 1
    rcr si, 1
    shr di, 1
    rcr si, 1
    shr di, 1
    rcr si, 1
    shr di, 1
    rcr si, 1
    
    ; Add fat_start
    add si, [fat_start_low]
    adc di, [fat_start_high]
    
    ; Read FAT sector (DI:SI)
    mov ax, si
    mov dx, di
    call read_sector
    jc .error
    
    ; Calculate entry offset = (cluster % 128) * 4
    mov ax, bx
    and ax, 0x007F
    shl ax, 1
    shl ax, 1
    
    ; Get next cluster (mask to 28 bits)
    mov si, ax
    mov ax, [buffer + si]
    mov dx, [buffer + si + 2]
    and dx, 0x000F
    
    clc
    jmp .done
.error:
    stc
.done:
    pop di
    pop si
    pop cx
    pop bx
    ret

; Convert cluster to LBA
; Input: DX:AX=cluster
; Output: DX:AX=LBA
cluster_to_lba:
    ; Input: DX:AX = cluster number
    ; Output: DX:AX = LBA address
    push bx
    push cx
    
    ; Calculate data_start from DBR
    mov ax, [bpb + BPB.reserved_sec]
    xor dx, dx
    movzx cx, byte [dbr_buffer + DBR.fat_count]
    mov bx, [dbr_buffer + DBR.sectors_per_fat32]
    mul cx
    add ax, [dbr_buffer + DBR.reserved_sectors]
    adc dx, 0
    mov [data_start_low], ax
    mov [data_start_high], dx
    
    ; Convert cluster to LBA
    sub ax, 2
    sbb dx, 0
    movzx bx, byte [dbr_buffer + DBR.sectors_per_cluster]
    mul bx
    add ax, [data_start_low]
    adc dx, [data_start_high]
    
    pop cx
    pop bx
    ret

advance_pointer:
    ; Input: CX = bytes to advance
    ; Modifies: target_offset, target_segment
    push ax
    push dx
    
    mov ax, [target_offset]
    add ax, cx
    mov [target_offset], ax
    jnc .no_carry
    mov ax, [target_segment]
    add ax, 0x1000
    mov [target_segment], ax
.no_carry:
    pop dx
    pop ax
    ret

; Fixed FAT32 cluster chain check
is_last_cluster:
    ; Input: EBX = cluster value
    ; Output: CF set if last cluster
    cmp ebx, FAT32_EOC
    jae .last_cluster
    clc
    ret
.last_cluster:
    stc
    ret

; FAT32 Cluster Operations (Real-mode optimized)
; ---------------------------------------------
; read_cluster: Loads cluster data into memory (16-bit compatible)
; In:  DX:AX - Cluster number (32-bit in DX:AX)
;      ES:BX - Destination buffer
; Out: CF=0 success, CF=1 error
read_cluster:
    pusha
    push ds
    
    ; Convert cluster to LBA (16-bit math)
    sub ax, 2                  ; Cluster - 2 (low word)
    sbb dx, 0                  ; Borrow for high word
    
    ; Multiply by sectors_per_cluster
    mov cx, [sectors_per_cluster]
    xor si, si                 ; SI:DI = multiplier
    mov di, cx
    call mul32                 ; DX:AX * SI:DI -> DX:AX
    
    ; Add data_start (32-bit addition)
    add ax, [data_start_low]
    adc dx, [data_start_high]
    
    ; Setup disk read parameters
    mov [dap + DAP.lba_low], ax
    mov [dap + DAP.lba_high], dx
    mov [dap + DAP.offset], bx
    mov [dap + DAP.segment], es
    mov ax, [sectors_per_cluster]
    mov [dap + DAP.count], ax
    
    ; Perform extended read
    mov ah, 0x42               ; Extended read function
    mov dl, [boot_drive]
    lea si, [dap]              ; DS:SI points to DAP
    int 0x13
    
    pop ds
    popa
    ret

; get_next_cluster: Finds next cluster in FAT (16-bit optimized)
; In:  DX:AX - Current cluster number
; Out: DX:AX - Next cluster number (0xFFFFFFFF if end)
;      CF=0 valid, CF=1 error
get_next_cluster:
    push es
    push di
    push si
    
    ; Calculate FAT offset = cluster * 4 (32-bit math)
    mov si, ax                 ; SI:DI = cluster * 4
    mov di, dx
    shl si, 1
    rcl di, 1                  ; ×2
    shl si, 1
    rcl di, 1                  ; ×4
    
    ; Calculate FAT sector: offset / bytes_per_sector
    xor dx, dx
    mov ax, si
    div word [bytes_per_sector] ; AX=sector offset, DX=byte offset
    push dx                    ; Save remainder (byte offset)
    
    ; Add FAT start LBA
    add ax, [fat_start_low]
    adc dx, [fat_start_high]
    
    ; Read FAT sector
    mov bx, fat_buffer
    call read_sector
    jc .error
    
    ; Get FAT entry (32-bit)
    pop di                     ; DI = byte offset
    mov ax, [bx+di]
    mov dx, [bx+di+2]
    and dx, 0x0FFF             ; Mask high nibble
    
    ; Check end-of-chain (0x0FFFFFF8-0x0FFFFFFF)
    cmp dx, 0x0FFF
    jb .valid
    cmp ax, 0xFFF8
    jb .valid
    
.end_chain:
    mov ax, 0xFFFF
    mov dx, 0xFFFF
    clc
    jmp .done
    
.valid:
    clc
    jmp .done
    
.error:
    stc
    
.done:
    pop si
    pop di
    pop es
    ret

; 32-bit multiplication (DX:AX * SI:DI -> DX:AX)
mul32:
    push bx
    push cx
    mov bx, ax
    mov cx, dx
    
    ; Multiply low words (BX * DI)
    mov ax, bx
    mul di
    push ax                    ; Result low
    push dx                    ; Result high
    
    ; Multiply high words (CX * SI)
    mov ax, cx
    mul si
    push ax
    push dx
    
    ; Cross terms (BX*SI + CX*DI)
    mov ax, bx
    mul si
    xchg ax, cx                ; CX = BX*SI low
    mov ax, di
    mul dx                     ; DX = CX*DI low
    add cx, dx
    
    ; Combine results
    pop dx
    pop ax
    add ax, cx
    adc dx, 0
    pop cx
    add ax, cx
    adc dx, 0
    pop cx
    
    pop cx
    pop bx
    ret

; Find file in root directory
; Input: DS:SI=filename
; Output: CF=0 found, DX:AX=first cluster; CF=1 not found
find_file:
    ; Input: DS:SI = filename (8.3 format)
    ; Output: CF clear if found, DX:AX = first cluster
    push es
    push di
    push bx
    push cx
    
    mov ax, [dbr_buffer + DBR.root_cluster]
    mov word [current_cluster], ax
    mov word [current_cluster+2], dx
    
.search_loop:
    ; Read cluster
    call read_cluster
    
    ; Scan directory entries
    mov cx, [dbr_buffer + DBR.bytes_per_sector]
    shr cx, 5  ; entries per sector
    mov di, fat_buffer
    
.check_entry:
    cmp byte [di], 0
    je .not_found
    cmp byte [di], 0xE5
    je .next_entry
    
    ; Compare filename
    push si
    push di
    push cx
    mov cx, 11
    repe cmpsb
    pop cx
    pop di
    pop si
    je .found
    
.next_entry:
    add di, DIR_ENTRY_SIZE
    loop .check_entry
    
    ; Get next cluster
    call get_next_cluster
    jnc .search_loop
    
.not_found:
    stc
    jmp .done
    
.found:
    mov ax, [di + 0x1A]  ; Low cluster
    mov dx, [di + 0x14]  ; High cluster
    clc
    
.done:
    pop cx
    pop bx
    pop di
    pop es
    ret
