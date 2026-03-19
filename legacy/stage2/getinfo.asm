; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the info getter of stage2, it will actually
; save essential things to 0x10000 (0x1000:0x0000).

; Get VBE Info
get_vbe_info:
  mov si, msg_get_vbe
  call print

  ; Get VBE info by using int 0x10
  mov ax, 0x4F01
  mov cx, 0x0118        ; 1024×768×32
  mov dx, 0x1000
  mov es, dx
  mov di, 0x0000        ; Write to 0x10000
  int 0x10

  cmp ax, 0x004F
  jne .vbe_failed

  jmp get_memory_map

.vbe_failed:
  mov si, msg_get_vbe_err
  call print
  jmp fallback_stg1

get_memory_map:
  mov si, msg_get_memmap
  call print

  ; We want physical address 0x10100 ~
  ; So set ES = 0x1010, offset 0x0000 = phys 0x10100
  mov ax, 0x1010
  mov es, ax

  ; DI = 0x0000 → ES:DI = 0x1010:0000 = physical 0x10100
  mov di, 0x0000
  xor bx, bx          ; Start with first entry
  xor bp, bp          ; Entry counter

.e820_read:
  ; Required registers for INT 0x15 0xE820
  mov eax, 0xE820
  mov ecx, 24         ; Each entry is 24 bytes
  mov edx, 0x534D4150 ; Signature 'SMAP'
  int 0x15

  jc .e820_end        ; Carry = end of list

  inc bp              ; Count valid entry
  add di, 24          ; Next entry (still 16-bit, no overflow)
  test bx, bx
  jne .e820_read

.e820_end:
  jmp enable_vbe      ; prestg3.asm, included by main.asm

msg_get_vbe db "[INFO] Getting VBE info (1024x768x32)...",0x0d,0x0a,0
msg_get_memmap db "[INFO] Getting memory map...",0x0d,0x0a,0
msg_get_vbe_err db "[ERROR] Failed to get VBE info",0x0d,0x0a,0
