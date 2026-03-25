; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is will prepare for stage4, and load up the 
; Rust code, which is the generic entry of bootloader.
;
; The stage4 will prepare for kernel, and jump into the
; kernel address finally.
[bits 32]


section .text
global prepare_sg4
prepare_sg4:
  ; Now ready to enable long mode
  ; Load GDT
  lgdt [gdt64.pointer]

  ; Setup page table
  mov eax, 0x40000  ; Hard-coded in C
  mov cr3, eax

  ; Enable CR4.PAE 
  mov eax, cr4 
  or eax, (1 << 5)
  mov cr4, eax

  ; Enable EMER.LME
  mov ecx, 0xC0000080
  rdmsr
  or  eax, 1 << 8
  wrmsr

  ; Enable paging & Write protect
  mov eax, cr0
  or eax, 1 << 31 | 1 << 16
  mov cr0, eax

  ; Jump to long mode!
  jmp gdt64.code:long_mode + 0x20000

[bits 64]
long_mode:
  mov ax, 0
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax

  hlt
  jmp $

section .rodata
gdt64:
    dq 0 ; zero entry
.code: equ $ - gdt64 ; new
    dq (1<<43) | (1<<44) | (1<<47) | (1<<53)
.pointer:
    dw $ - gdt64 - 1
    dq gdt64 + 0x20000
