; Proka Bootloader - The bootloader of Proka OS 
; Copyright (C) RainSTR Studio 2026, All rights reserved.
; 
; This file is the kernel loader of stage3, which will
; use real/mode to read 1 cluster kernel and load it
; to 0x100000 (phys).

%define BPB_CACHE_OFF 0xA000
%define BPB_CACHE_SEG 0x0000

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
  ret
  
; Switch back to real mode
switch_real_load_file:
  cli   ; No interrupts

  ; Disable paging
  mov eax, cr0
  and eax, 0x7FFFFFFF   ; Clear PG
  mov cr0, eax

  ; Enter 16-bit protected mode
  jmp 0x18:prot16_entry

back_protected_mode:
  ; Set up segment
  mov ax, 0x10
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax

  ; Now we are back to protected mode!
  ;
  ; Just copy the content from buffer to destination
  ; address!
  mov edi, [dest_current]  ; Destination (0x100000 - 0x20000)
  mov esi, 0x68000  ; Source (0x88000 - 0x20000)
  movzx ecx, byte [fat32_spc]
  shl ecx, 9  ; SPC x 512 = 1 cluster bytes

  ; Copy!
  cld 
  rep movsb
  add edi, ecx
  mov [dest_current], edi

  ; Check is it completed reading
  cmp byte [complete_read], 1 
  je  .done

  jmp switch_real_load_file

.done:
  ret

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
  lgdt [empty_gdt_ptr]

  ; Now Real mode is fully normal working!
  ; Then, just use this driver to read kernel!

  ; Reset disk service
  mov ah, 0x00
  mov dl, [0x0500]
  int 0x13

  cmp byte [is_first_read], 0 
  je .read

.first_read:
  ; Get file start cluster
  mov si, kernel_filename
  call fat32_get_start_cluster
  jc .file_not_found
  mov dword [current_cluster], eax

  ; Calculate data start 
  call fat32_calculate_data_start
  mov [data_start], edx

  ; Get sectors per cluster
  push fs 
  push cx
  mov cx, BPB_CACHE_SEG ; Defined at fat32.asm
  mov fs, cx
  mov cl, [fs:BPB_CACHE_OFF + 0x0D]  ; SPC
  mov [fat32_spc], cl 
  pop cx
  pop fs

  ; Set is_first_read to false (0)
  mov byte [is_first_read], 0

.read:
  ; Set up segment 
  ; The file buffer is 0x88000~0x8FFFF, so segment 
  ; is 0x8800 
  mov cx, 0x8800
  mov es, cx
  xor bx, bx
  mov eax, [current_cluster]
  call fat32_load_cluster

  ; Check is it end sign
  cmp eax, 0x0FFFFFF8
  jae .done

  ; Get next cluster
  ; Now EAX = current cluster
  call fat32_next_cluster
  mov [current_cluster], eax

  jmp switch_prot_copy_file

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

.done:
  ; Set complete_read = 1 (true)
  mov byte [complete_read], 1 
  jmp switch_prot_copy_file

switch_prot_copy_file:
  ; Disable interrupts
  cli

  ; Disable NMI
  in al, 0x70
  or al, 0x80
  out 0x70, al

  lgdt [gdt_ptr]

  ; Set up CRO.PE
  mov eax, cr0
  or eax, 1    ; PE=1 
  mov cr0, eax

  ; Exit the real mode and back to protected mode
  jmp dword 0x08:back_protected_mode

; Include driver file
%include "../drivers/fat32.asm"

; ======= Data section =======
section .data
; Variables
is_first_read db 1
current_cluster dd 0
complete_read db 0
fat32_spc db 0
dest_current dd 0xE0000

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
