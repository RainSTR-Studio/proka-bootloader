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
  ; So 0x7c00 + 0x1BE = 0x7DBE, just read it from there.
  mov ax, [bx]
  mov [boot_flag], ax
  mov ax, [bx + 1]
  mov [start_head], ax
  mov ax, [bx + 2]
  mov [start_sector], ax
  mov ax, [bx + 3]
  mov [start_cyl], ax
  mov ax, [bx + 4]
  mov [type], ax
  mov ax, [bx + 5]
  mov [end_head], ax
  mov ax, [bx + 6]
  mov [end_sector], ax
  mov ax, [bx + 7]
  mov [end_cyl], ax
  mov ax, [bx + 8] ; 4 Bytes!
  mov [start_lba], ax
  mov ax, [bx + 12] ; 4 Bytes!
  mov [total_sectors], ax

; Check is the current table is proka os's partition
.check_is_proka_part:
  ; The Proka OS's partition satisfy these conditions:
  ; - Has bootable flag
  ; - Type is 0x91

  ; Check is the current part table has bootable flag.
  mov ax, [boot_flag]
  cmp ax, 0x80 ; Bootable flag is 0x80
  jne .skip

.skip:
  cmp cx, 4 ; Only 4 DPTs
  je .not_found

  shl bx, 4 ; Each DPT size is 16B
  add cx, 1
  jmp init_dpt

.not_found:
  mov si, msg_part_not_found
  call print
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

; Messages
msg_enter_sg1 db "[INFO] Entered stage1",0x0d,0x0a,0
msg_finding_part db "[INFO] Finding and parsing DPT...",0x0d,0x0a,0
msg_part_not_found db "[ERROR] No proka partition found, gotta hang...",0x0d,0x0a,0

times 16*512 - ($ - $$) db 0
