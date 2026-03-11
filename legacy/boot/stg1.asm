; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the stage 2 of the whole boot process, which
; will initialize more things, such as VBE, disk and so on.

[org 0x8000]	; The jumped target
[bits 16]	; Real mode still

start:
  ; Entered stage 1
  mov si, msg_enter_sg1
  call print

  mov si, msg_finding_part
  call print

init_dpt:
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

.decide_detect_what:
  mov al, [is_proka_part_found]
  cmp al, 1
  je .check_is_windows_part

; Check is the current table is proka os's partition
.check_is_proka_part:
  ; The Proka OS's partition satisfy these conditions:
  ; - Has bootable flag
  ; - Type is 0x91

  ; Check is the current part table has bootable flag.
  cmp byte [boot_flag], 0x80
  jne .next_part

  cmp byte [type], 0x91
  je .found_proka_part

.check_is_windows_part:
  ; The Windows partition must satisfy these:
  ; - Has bootable flag
  ; - Type is 0x07 (HPFS/NTFS/exFAT)

  ; Check is bootable flag
  cmp byte [boot_flag], 0x80
  jne .next_part

  ; Check is Windows part
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
  mov al, 1
  mov [is_proka_part_found], al
  jmp init_dpt

.found_windows_part:
  mov si, msg_windows_part_found
  call print
  mov al, 1 
  mov [is_windows_part_found], al
  jmp boot_main

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
  hlt
  
print:
  mov ah, 0x0e

.next:
  lodsb
  cmp al, 0 
  je .done
  int 0x10
  jmp .next

.done:
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

; Messages
msg_enter_sg1 db "[INFO] Entered stage1",0x0d,0x0a,0
msg_finding_part db "[INFO] Finding and parsing DPT...",0x0d,0x0a,0
msg_part_not_found db "[ERROR] No known partition found, gotta hang...",0x0d,0x0a,0 
msg_proka_part_found db "[INFO] Proka partition found! continuing finding Windows part...",0x0d,0x0a,0
msg_windows_part_found db "[INFO] Found Windows partition!",0x0d,0x0a,0

times 16*512 - ($ - $$) db 0
