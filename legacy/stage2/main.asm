; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the stage 2 of the whole boot process, which
; will initialize more things, such as VBE, memmap and so on.

[bits 16]	; Still real mode :/

section .text.head
global stage2_start
stage2_start:
  ; Set up segment
  mov ax, cs
  mov ds, ax

  ; Print message
  mov si, msg_enter_stg2
  call print
  jmp get_vbe_info	; getinfo.asm

section .text
global fallback_stg1
; Fallback (only for failed)
fallback_stg1:
  mov si, msg_fallback_stg1
  call print
  xor ax, ax
  mov ds, ax
  jmp 0x0000:0x8000

global print
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

section .data
msg_enter_stg2 db "[STAGE] Entered stage2",0x0d,0x0a,0
msg_fallback_stg1 db "[ERROR] Critical error happened, falling back to stage1...",0x0d,0x0a,0
%include "getinfo.asm"
%include "prestg3.asm"
