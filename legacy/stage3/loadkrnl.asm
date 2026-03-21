; Proka Bootloader - The bootloader of Proka OS 
; Copyright (C) RainSTR Studio 2026, All rights reserved.
; 
; This file is the kernel loader of stage3, which will
; use real/mode to read 1 cluster kernel and load it
; to 0x100000 (phys).

section .text
; ===== 32-bit area =====
[bits 32]
extern gdt
extern gdt_ptr
extern print
extern fallback_stg1

global loadkrnl
loadkrnl:
  xor ecx, ecx
  call switch_real_load_file
  
; Switch back to real mode
switch_real_load_file:
  cli   ; No interrupts

  ; Disable paging
  mov eax, cr0
  and eax, 0x7FFFFFFF   ; Clear PG
  mov cr0, eax

  ; Enter 16-bit protected mode
  jmp 0x18:prot16_entry

; ===== 16-bit area =====
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

  jmp 0x2000:real_mode

real_mode:
  ; Reset segments
  mov ax, cs 
  mov ds, ax

  ; Reset es
  xor ax, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax
  mov sp, 0x7c00

  ; Recover BIOS IVT
  lidt [real_mode_idt]
  lgdt [empty_gdt_ptr]

  ; Now Real mode is fully normal working!
  ; Then, just use this driver to read kernel!

  mov ah, 0x00
  mov dl, [0x0500]
  int 0x13

  mov si, kernel_filename
  call fat32_get_start_cluster
  jc .file_not_found
  mov ecx, eax

  ; Calculate data start 
  call fat32_calculate_data_start
  mov [data_start], edx
  mov eax, ecx

  ; Set up segment 
  ; The file buffer is 0x78000~0x7FFFF, so segment 
  ; is 0x8800 
  mov cx, 0x7800
  mov es, cx
  xor bx, bx
  call fat32_load_cluster

  jmp $

.file_not_found:
  ; Disable VBE
  mov ax, 0x0012
  int 0x10 

  ; Text mode
  mov ax, 0x0003
  int 0x10

  mov si, msg_kernel_not_found
  call print

  jmp fallback_stg1

%include "../drivers/fat32.asm"

section .data
; Kernel filename (8.3)
kernel_filename db 'PROKA-~1   '
msg_kernel_not_found db "[ERROR] Kernel not found",0x0d,0x0a,0

; Real mode IDT (IVT)
real_mode_idt:
  dw 0x3FF
  dd 0

; Empty GDT 
empty_gdt:
    ; Null descriptor (required by CPU)
    dd  0
    dd  0

; GDT limit (size - 1)
empty_gdt_limit equ $ - empty_gdt - 1

; GDT pointer for LGDT instruction
empty_gdt_ptr:
    dw empty_gdt_limit   ; 16-bit limit
    dd empty_gdt         ; 32-bit linear base address
