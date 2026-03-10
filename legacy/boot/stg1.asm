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

init_dpt:
  ; The default DPT partition is at 0x1BE in the partition
  ; However, the MBR is loaded at 0x7c00, so that we won't read it again
  ; So 0x7c00 + 0x1BE = 0x7DBE, just read it from there.
  mov boot_flag, [0x7DBE]
  mov start_head, [0x7DBF]
  mov start_sector, [0x7DC0]
  mov start_cyl, [0x7DC1]
  mov type, [0x7DC2]
  mov end_head, [0x7DC3]
  mov end_sector, [0x7DC4]
  mov end_cyl, [0x7DC5]
  mov start_lba, [0x7DC6] ; 4 Bytes!
  mov total_sectors, [0x7DCA] ; 4 Bytes!
  
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
total_sectors dwd 0

; Messages
msg_enter_sg1 db "[INFO] Entered stage1",0x0d,0x0a,0
msg_find_part db "[INFO] Finding and parsing DPT..."

times 16*512 - ($ - $$) db 0
