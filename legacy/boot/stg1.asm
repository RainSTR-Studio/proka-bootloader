; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the stage 2 of the whole boot process, which
; will initialize more things, such as VBE, disk and so on.

[org 0x8000]  ; The jumped target
[bits 16]     ; Real mode still

start:
  ; Entered stage 1
  mov si, msg_enter_sg1
  call print

  mov si, msg_finding_part
  call print

  mov bx, 0x7DBE
  mov cx, 0

; Load DPT to data
.load_dpt:
  ; The default DPT partition is at 0x1BE in the partition
  ; However, the MBR is loaded at 0x7c00, so that we won't read it again
  ; So 0x7c00 + 0x1BE = 0x7DBE, just read from there.
  mov al, [bx]
  mov [boot_flag], al

  mov al, [bx + 1]
  mov [start_head], al

  mov al, [bx + 2]
  mov [start_sector], al
  mov al, [bx + 3]
  mov [start_cyl], al

  mov al, [bx + 4]
  mov [type], al

  mov al, [bx + 5]
  mov [end_head], al

  mov al, [bx + 6]
  mov [end_sector], al
  mov al, [bx + 7]
  mov [end_cyl], al

  ; Start LBA (4 bytes)
  mov ax, [bx + 8]
  mov dx, [bx + 10]
  mov [start_lba], ax
  mov [start_lba + 2], dx

  ; Total sectors (4 bytes)
  mov ax, [bx + 12]
  mov dx, [bx + 14]
  mov [total_sectors], ax
  mov [total_sectors + 2], dx

.check_is_proka_part:
  ; The Proka OS's partition satisfy these conditions:
  ; - Has bootable flag
  ; - Type is 0x91
  cmp byte [boot_flag], 0x80
  jne .check_is_windows_part

  cmp byte [type], 0x91
  jne .check_is_windows_part
  je .found_proka_part

.check_is_windows_part:
  ; The Windows partition must satisfy these:
  ; - Has bootable flag
  ; - Type is 0x07 (HPFS/NTFS/exFAT)
  cmp byte [boot_flag], 0x80
  jne .next_part

  cmp byte [type], 0x07
  je .found_windows_part

.next_part:
  cmp cx, 4
  je .not_found

  add bx, 16
  inc cx
  jmp .load_dpt

.found_proka_part:
  mov si, msg_proka_part_found
  call print
  mov byte [is_proka_part_found], 1

  ; Save start LBA
  mov ax, [start_lba]
  mov dx, [start_lba + 2]
  mov [proka_start_lba], ax
  mov [proka_start_lba + 2], dx

  ; Save total sectors
  mov ax, [total_sectors]
  mov dx, [total_sectors + 2]
  mov [proka_total_sectors], ax
  mov [proka_total_sectors + 2], dx

  jmp .next_part

.found_windows_part:
  mov si, msg_windows_part_found
  call print
  
  ; Set is_windows to 1 (true)
  mov byte [is_windows_part_found], 1

  ; Save start LBA
  mov ax, [start_lba]
  mov dx, [start_lba + 2]
  mov [windows_start_lba], ax
  mov [windows_start_lba + 2], dx

  ; Save total sectors
  mov ax, [total_sectors]
  mov dx, [total_sectors + 2]
  mov [windows_total_sectors], ax
  mov [windows_total_sectors + 2], dx

  jmp .next_part

.not_found:
  cmp byte [is_proka_part_found], 0
  jne boot_main

  cmp byte [is_windows_part_found], 0
  jne boot_main

  jmp .all_not_found

.all_not_found:
  mov si, msg_part_not_found
  call print
  hlt

boot_main:
  mov si, msg_find_part_complete
  call print
  
  ; Print tip message
  mov si, msg_ask_os
  call print
  
  ; Init menu count
  mov byte [menu_item_count], 0

.is_show_proka:
  cmp byte [is_proka_part_found], 1
  jne .is_show_windows
  inc byte [menu_item_count]
  mov byte [proka_menu_index], 1
  mov si, msg_proka
  call print

.is_show_windows:
  cmp byte [is_windows_part_found], 1
  jne .choose
  inc byte [menu_item_count]
  mov al, [menu_item_count]
  mov byte [win_menu_index], al
  mov si, msg_windows
  call print

.choose:
  mov si, msg_choose
  call print
  jmp wait_input

; Wait for user input
wait_input:
  mov ah, 0x00
  int 0x16

  cmp al, 0x0D
  je .do_jmp

  cmp al, '1'
  jb .invalid

  cmp al, '2'
  ja .invalid

  mov ah, 0x0E
  int 0x10

  mov al, 0x08   ; Back one 
  int 0x10

  mov [input_buf], al

  jmp wait_input

.do_jmp:
  ; Output Enter
  mov ah, 0x0e
  mov al, 0x0d
  int 0x10
  mov al, 0x0a
  int 0x10

  mov al, [input_buf]

  cmp al, [proka_menu_index]
  je boot_proka

  cmp al, [win_menu_index]
  je boot_windows

  jmp .invalid

.invalid:
  mov ah, 0x0E
  mov al, 0x07  ; Beep!
  int 0x10

  jmp wait_input

boot_proka:
  hlt

boot_windows:
  ; Find Windows PBR and load
  mov ah, 0x2 ; Read disk
  mov al, 1   ; Only 1 sector
  mov ch, 0   ; Read from cylinder 0
  mov cl, [proka_start_lba]
  mov dl, 0x80
  mov bx, 0x7c00	; Target address
  int 0x13  ; Read!

  ; Ask for info
  mov si, msg_boot_windows
  call print

  ; Back to PBR!
  jmp 0x0000:0x7c00
  
print:
  push ax
  mov ah, 0x0e

.next:
  mov al, [si]
  cmp al, 0 
  je .done

  int 0x10
  inc si
  jmp .next

.done:
  pop ax
  ret

; Data sections
; DPT structures
boot_flag db 0
start_head db 0
start_sector db 0
start_cyl db 0
type db 0
end_head db 0
end_sector db 0
end_cyl db 0
start_lba dd 0
total_sectors dd 0

; Bool data
; If the current data is one, it's true.
is_proka_part_found db 0
is_windows_part_found db 0

; Essential data
proka_start_lba dd 0
proka_total_sectors dd 0
windows_start_lba dd 0
windows_total_sectors dd 0

; Menu data
menu_item_count db 0    ; How many choices (1 or 2)
proka_menu_index db 0   ; Which one is proka
win_menu_index db 0     ; Which ome is Windows
input_buf db 0          ; Input data

; Messages
msg_enter_sg1 db "[STAGE] Entered stage1",0x0d,0x0a,0
msg_finding_part db "[INFO] Finding and parsing DPT...",0x0d,0x0a,0
msg_part_not_found db "[ERROR] No known partition found, gotta hang...",0x0d,0x0a,0 
msg_proka_part_found db "[INFO] Found Proka partition!",0x0d,0x0a,0
msg_windows_part_found db "[INFO] Found Windows partition!",0x0d,0x0a,0
msg_find_part_complete db "[INFO] Parsing DPT has been completed",0x0d,0x0a,0
msg_ask_os db "Please select an OS that you want to boot:",0x0d,0x0a,0
msg_proka db " - ProkaOS ",0x0d,0x0a,0
msg_windows db " - Windows ",0x0d,0x0a,0
msg_choose db "Enter your choice (1/2) : ",0
msg_boot_windows db "[INFO] Booting Windows..."0x0d,0x0a,0
msg_boot_proka db "[INFO] Booting ProkaOS...",0x0d,0x0a,0

times 16*512 - ($ - $$) db 0
