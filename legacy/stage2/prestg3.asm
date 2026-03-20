; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is will prepare for stage3, and load 
; The C code

section .text
enable_vbe:
  mov si, msg_enable_vbe
  call print

  ; Delay 250ms
  mov ah, 0x86
  mov cx, 0x0003 
  mov dx, 0xD090
  int 0x15

  ; Enable VBE 
  mov ax, 0x4F02
  mov bx, 0x4118
  int 0x10

  cmp ax, 0x004F
  jne .failed

  jmp enter_stg3

.failed:
  mov ax, 0x0003
  int 0x10
  mov si, msg_enable_vbe_err
  call print
  jmp fallback_stg1

; Ready to switch to protected mode...
enter_stg3:
  cli

  ; Disable NMI
  in al, 0x70
  or al, 0x80
  out 0x70, al

  ; Enable A20
  call enable_a20

  lgdt [gdt_ptr]

  mov eax, cr0
  or eax, 1    ; PE=1 
  mov cr0, eax

  ; Byebye, real mode :)
  jmp dword 0x08:protected_mode

enable_a20:
  cli           ; disable interrupts

  call  a20wait
  mov   al,0xAD
  out   0x64,al ; disable keyboard

  call  a20wait
  mov   al,0xD0
  out   0x64,al ; read controller output port

  call  a20wait2
  in    al,0x60 ; save response byte
  push  eax

  call  a20wait
  mov   al,0xD1
  out   0x64,al ; write next byte into controller output port

  call  a20wait
  pop   eax
  or    al,2    ; set A20 enable bit
  out   0x60,al ; activate A20

  call  a20wait
  mov   al,0xAE
  out   0x64,al ; re-enable keyboard

  ret

a20wait:        ; wait input buffer clear
  in    al,0x64
  test  al,2
  jnz   a20wait
  ret

a20wait2:       ; wait output buffer ready
  in    al,0x64
  test  al,1
  jz    a20wait2
  ret


[bits 32]
protected_mode:
  ; Set up segment
  mov ax, 0x10
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax

  cld

  mov esp, 0x80000
  mov ebp, 0x80000

  jmp $

section .data
; Messages
msg_enable_vbe db "[INFO] Enabling VBE...",0x0d,0x0a,0
msg_enable_vbe_err db "[ERROR] Failed to enable VBE",0x0d,0x0a,0

; GDT 
gdt:

gdt_null:
  dq 0
gdt_code:
  dw 0xFFFF
  dw 0 
  db 0x02
  db 0b10011010
  db 0b11001111
  db 0 
gdt_data:
  dw 0xFFFF
  dw 0 
  db 0x02
  db 0b10010010
  db 0b11001111
  db 0 
gdt_end:

gdt_ptr:
  dw gdt_end - gdt - 1
  dd gdt + 0x20000
