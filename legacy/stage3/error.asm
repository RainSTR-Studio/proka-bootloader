; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the kernel error handler, which will handle
; the errors during parsing header, or something else.

%include "../../build/version.inc"

section .text
; ===== 32-bit area =====
[bits 32]
global error
error:
  cli   ; No interrupts

  ; Save args
  mov ebx, [ebp+8]

  ; Disable paging
  mov eax, cr0
  and eax, 0x7FFFFFFF   ; Clear PG
  mov cr0, eax

  ; Enter 16-bit protected mode
  jmp 0x18:prot16_entry

; ===== 16-bit area =====
section .text16

; Externs
extern print
extern fallback_stg1

[bits 16]
prot16_entry:
  ; Set to 16-bit data
  mov ax, 0x20
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax

  ; Clear CR0 PE
  mov eax, cr0
  and eax, 0xFFFFFFFE       ; Clear PE
  mov cr0, eax

  jmp 0x2000:real_mode_entry

real_mode_entry:
  ; Reset segments
  mov ax, cs
  mov ds, ax

  ; Reset es
  xor ax, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax

  ; Recover BIOS IVT
  lidt [real_mode_idt]

  ; Reset VGA text mode
  mov ax, 0x0003
  int 0x10

  ; Now check the branches
  cmp ebx, 1 
  je .err_magic
  cmp ebx, 2 
  je .err_ver

  mov si, msg_err_unknown
  call print
  
.fallback:
  jmp fallback_stg1

.err_magic:
  mov si, msg_err_magic
  call print
  mov si, msg_err_magic_2
  call print
  jmp .fallback

.err_ver:
  mov si, msg_err_ver
  call print
  mov si, msg_err_ver2
  call print
  call print_version
  jmp .fallback

print_version:
  mov al, PROKA_VERSION_MAJ
  add al, '0'
  mov ah, 0x0E
  int 0x10

  mov al, '.'
  int 0x10

  mov al, PROKA_VERSION_MIN
  add al, '0'
  int 0x10

  mov al, '.'
  int 0x10

  mov al, PROKA_VERSION_PAT
  add al, '0'
  int 0x10

  ; Next line
  mov al, 0x0a
  int 0x10
  mov al, 0x0d
  int 0x10

  ret

; ======= Data section =======
section .data16

; Messages
msg_err_magic db "[ERROR] The kernel's magic is mismatched, perhaps not valid or old proka kernel",0x0d,0x0a,0
msg_err_magic_2 db "[ERROR] Please check is your kernel not corrupted or the latest",0x0d,0x0a,0
msg_err_ver db "[ERROR] Version mismatched, perhaps you are using older/younger kernel",0x0d,0x0a,0
msg_err_ver2 db "[ERROR] Current bootloader version: ",0
msg_err_unknown db "[ERROR] Unknown error occurred in stage3",0x0d,0x0a,0

; Real mode IDT (IVT)
real_mode_idt:
  dw 0x3FF
  dd 0
