; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the stage 2 of the whole boot process, which
; will initialize more things, such as VBE, disk and so on.

[org 0x8000]	; The jumped target
[bits 16]	; Real mode still

start:
  ; Entered stage 2
  mov si, msg_enter_sg2
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

msg_enter_sg2 db "Proka Bootloader: Entered stage2",0x0d,0x0a,0

times 16*512 - ($ - $$) db 0
