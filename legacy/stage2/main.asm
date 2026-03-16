[org 0]
[bits 16]

stage2_start:
  ; Set up segment
  mov ax, cs
  mov ds, ax

  ; Print message
  mov si, msg_enter_stg2
  call print
  hlt

print:
  push ax
  mov ah, 0x0e

.loop:
  lodsb
  cmp al, 0 
  je .done
  int 0x10
  jmp .loop

.done:
  pop ax
  ret

msg_enter_stg2 db "[STAGE] Entered stage2",0x0d,0x0a,0

%include "../drivers/fat32.asm"
