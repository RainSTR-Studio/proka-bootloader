; Proka Bootloader - The Bootloader for Proka OS
; Copyright (C) RainSTR Studio 2026, All Rights Reserved.
;
; This file is the minimal driver of FAT32, which will read the kernel
; file from FAT32 partition.

; ------------------------------
; fat32_init
; Inputs:
;   dl = Driver number
; ------------------------------
fat32_init:
    mov [fat32_DriveNum], dl

    ; Read boot sector to 0x7e00
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 1
    mov dh, 0
    mov bx, 0x7e00
    int 0x13
    jc .error

    ; Read BPB
    mov ax, [0x7e0b]
    mov [fat32_BytesPerSector], ax

    mov al, [0x7e0d]
    mov [fat32_SectorsPerCluster], al

    mov ax, [0x7e0e]
    mov word [fat32_ReservedSectors], ax
    mov word [fat32_ReservedSectors+2], 0

    mov al, [0x7e10]
    mov [fat32_FatCount], al

    ; Read SectorsPerFat (32-bit)
    mov ax, [0x7e24]
    mov word [fat32_SectorsPerFat], ax
    mov ax, [0x7e26]
    mov word [fat32_SectorsPerFat+2], ax

    ; Read RootCluster (32-bit)
    mov ax, [0x7e2c]
    mov [fat32_RootClusterLo], ax
    mov ax, [0x7e2e]
    mov [fat32_RootClusterHi], ax

    ; Calculate DataRegionSector = ReservedSectors + FatCount * SectorsPerFat
    mov ax, [fat32_ReservedSectors]
    mov dx, [fat32_ReservedSectors+2]

    mov bl, [fat32_FatCount]
    movzx bx, bl
    mul word [fat32_SectorsPerFat]
    add ax, [fat32_ReservedSectors]
    adc dx, [fat32_ReservedSectors+2]

    mov [fat32_DataRegionSector], ax
    mov [fat32_DataRegionSector+2], dx

    ret
.error:
    stc
    ret

; ------------------------------
; fat32_cluster_to_sector
; Input:  ax = Cluster Lo, dx = Cluster Hi
; Output: ax = Sector Lo, dx = Sector Hi
; ------------------------------
fat32_cluster_to_sector:
    push bx
    push cx

    ; Cluster -= 2
    sub ax, 2
    sbb dx, 0

    ; Multiply by SectorsPerCluster
    mov bl, [fat32_SectorsPerCluster]
    movzx cx, bl
    mul cx

    ; Add DataRegionSector
    add ax, [fat32_DataRegionSector]
    adc dx, [fat32_DataRegionSector+2]

    pop cx
    pop bx
    ret

; ------------------------------
; fat32_read_cluster
; Input:  ax = Cluster Lo, dx = Cluster Hi
;         es:bx = Target buffer
; ------------------------------
fat32_read_cluster:
    call fat32_cluster_to_sector

    push ax
    push bx
    push cx
    push dx

    mov dl, [fat32_DriveNum]
    mov ah, 0x02
    mov al, [fat32_SectorsPerCluster]
    mov ch, 0
    mov cl, 1
    mov dh, 0
    int 0x13
    jc .read_error

    pop dx
    pop cx
    pop bx
    pop ax
    ret
.read_error:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------
; fat32_next_cluster
; Input:  ax = Cluster Lo, dx = Cluster Hi
; Output: ax = Next Cluster Lo, dx = Next Cluster Hi
; ------------------------------
fat32_next_cluster:
    push bx
    push cx
    push dx
    push si

    ; Calculate FAT entry offset: Cluster * 4
    mov bx, ax
    shl bx, 1
    shl bx, 1 ; bx = Cluster * 4

    ; FAT sector = ReservedSectors + (Cluster * 4) / BytesPerSector
    mov ax, [fat32_ReservedSectors]
    add ax, bx
    xor dx, dx
    div word [fat32_BytesPerSector]
    mov cx, ax

    ; Read FAT sector to 0x7e00
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov dh, 0
    mov bx, 0x7e00
    mov dl, [fat32_DriveNum]
    int 0x13
    jc .next_error

    ; Get FAT entry
    and bx, dx
    mov ax, [0x7e00 + bx]
    mov dx, [0x7e00 + bx + 2]

    pop si
    pop dx
    pop cx
    pop bx
    ret
.next_error:
    pop si
    pop dx
    pop cx
    pop bx
    mov ax, 0
    mov dx, 0
    ret

; ------------------------------
; fat32_find_file
; Input:  si = Filename (8.3 uppercase, 0-ended)
; Output: ax = Start Cluster Lo, dx = Start Cluster Hi
;         If not found, ax=0, dx=0
; ------------------------------
fat32_find_file:
    push si
    push di
    push cx
    push bx

    ; Read root directory cluster
    mov ax, [fat32_RootClusterLo]
    mov dx, [fat32_RootClusterHi]
    mov bx, 0x7e00
    call fat32_read_cluster

    mov di, 0x7e00
    mov cx, 16 ; 512 / 32 = 16 entries per cluster

.next_entry:
    cmp byte [di], 0
    je .not_found

    push si
    push di
    push cx
    mov cx, 11
    rep cmpsb
    pop cx
    pop di
    pop si
    je .found

    add di, 32
    loop .next_entry

    ; Read next cluster (simplified)
    mov ax, [fat32_RootClusterLo]
    mov dx, [fat32_RootClusterHi]
    call fat32_next_cluster
    cmp ax, 0x0FFF
    jb fat32_find_file

.not_found:
    xor ax, ax
    xor dx, dx
    jmp .find_done

.found:
    mov ax, [di+26]
    mov dx, [di+20]

.find_done:
    pop bx
    pop cx
    pop di
    pop si
    ret

; ------------------------------
; fat32_read_file
; Input:  ax = Start Cluster Lo, dx = Start Cluster Hi
;         es:bx = Target buffer
;         cx:dx = File size
; ------------------------------
fat32_read_file:
    push ax
    push bx
    push cx
    push dx

.read_loop:
    call fat32_read_cluster

    ; Check if end of cluster chain
    call fat32_next_cluster
    cmp ax, 0xFFF8
    jae .end_chain

    ; Continue reading
    add bx, [fat32_BytesPerSector]
    movzx cx, byte [fat32_SectorsPerCluster]
    shl cx, 9            ; *512
    sub dx, cx
    sbb cx, 0
    jnc .read_loop

.end_chain:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------
; Global variables
; ------------------------------
fat32_BytesPerSector     dw 512
fat32_SectorsPerCluster  db 0
fat32_ReservedSectors    dd 0
fat32_FatCount           db 0
fat32_SectorsPerFat      dd 0
fat32_RootClusterHi      dw 0 ; High part
fat32_RootClusterLo      dw 0 ; Low part
fat32_DataRegionSector   dd 0
fat32_DriveNum           db 0x80 ; The first drive
