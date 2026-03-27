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

  ; Setup page table
  mov eax, 0x60000  ; Hard-coded in C
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
  jmp .flush

extern stage4_entry
.flush:
  mov ax, 0x10
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax

  jmp stage4_entry
