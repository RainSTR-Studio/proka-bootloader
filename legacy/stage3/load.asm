; Proka Bootloader - The bootloader of Proka OS 
; Copyright (C) RainSTR Studio 2026, All rights reserved.
; 
; This file is the file loader of stage3, which will
; use real mode to read a file (initprt or kernel) and
; load it to memory. Two entry points:
;   loadinit - loads INITPRT.IMG to 0x3200000
;   loadkrnl - loads PROKA-~1 to 0x200000

%define BPB_CACHE_OFF 0xA000
%define BPB_CACHE_SEG 0x0000

section .text
; ===== 32-bit area =====
[bits 32]
extern gdt
extern gdt_ptr
extern print
extern fallback_stg1

global loadinit
loadinit:
  xor ecx, ecx
  mov byte [is_first_read + 0x20000], 1
  mov byte [complete_read + 0x20000], 0
  mov byte [load_type + 0x20000], 1
  mov dword [dest_current + 0x20000], 0x3200000
  mov word [file_name_ptr + 0x20000], initprt_filename
  mov word [iso_file_name_ptr + 0x20000], initprt_filename_iso
  mov word [error_msg_ptr + 0x20000], msg_initprt_not_found
  call switch_real_load_file
  ret

global loadkrnl
loadkrnl:
  xor ecx, ecx
  mov byte [is_first_read + 0x20000], 1
  mov byte [complete_read + 0x20000], 0
  mov byte [load_type + 0x20000], 2
  mov dword [dest_current + 0x20000], 0x200000
  mov word [file_name_ptr + 0x20000], kernel_filename
  mov word [iso_file_name_ptr + 0x20000], kernel_filename_iso
  mov word [error_msg_ptr + 0x20000], msg_kernel_not_found
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
  mov edi, [dest_current + 0x20000]  ; Destination
  mov esi, 0x78000  ; Source
  mov ecx, [copy_size + 0x20000]     ; Block size (FAT cluster or ISO sector)

  ; Copy!
  cld 
  rep movsb
  mov [dest_current + 0x20000], edi

  ; Check is it completed reading
  cmp byte [complete_read + 0x20000], 1 
  je  .done

  jmp switch_real_load_file

.done:
  ret

; ===== 16-bit area =====
section .text16
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
  ; Then, just use this driver to read file!

  ; Reset disk service
  mov ah, 0x00
  mov dl, [fs:0x0500]
  int 0x13

  ; Check disk type: CD/DVD if >= 0xE0
  cmp dl, 0xE0
  jae isoread

fatread:
  cmp byte [is_first_read], 0 
  je .read

.first_read:
  ; Get file start cluster
  mov si, [file_name_ptr]
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

  ; Calculate copy size = SPC * 512
  movzx eax, byte [fat32_spc]
  shl eax, 9
  mov dword [copy_size], eax

  ; Set is_first_read to false (0)
  mov byte [is_first_read], 0

.read:
  ; Set up segment 
  ; The file buffer is 0x78000~0x7FFFF, so segment 
  ; is 0x7800 
  mov cx, 0x7800
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

  mov si, [error_msg_ptr]
  call print

  jmp fallback_stg1

.done:
  ; Set complete_read = 1 (true)
  mov byte [complete_read], 1 
  jmp switch_prot_copy_file

isoread:
  cmp byte [is_first_read], 0
  je .read_iso

.first_read_iso:
  ; PVD already at 0xC000, Root directory at 0xC800 with ES=0
  ; Get root directory length from PVD record
  mov eax, 0xC09C
  call iso9660_read_record          ; ECX = root data length
  mov dword [iso_root_len], ecx

  ; Search for file in root directory
  mov eax, 0xC800
  mov ecx, dword [iso_root_len]
  mov si, [iso_file_name_ptr]
  call iso9660_get_fileinfo
  jc .file_not_found_iso
  mov dword [current_cluster], eax ; file start LBA
  mov dword [iso_file_size], ecx   ; file size in bytes
  mov byte [is_first_read], 0
  mov dword [copy_size], 2048      ; one ISO sector

.read_iso:
  mov eax, dword [current_cluster]
  mov cx, 1
  mov bx, 0x7800
  mov es, bx
  xor bx, bx
  xor edx, edx
  call iso9660_read_lba
  jc .iso_err

  inc dword [current_cluster]
  sub dword [iso_file_size], 2048
  jbe .done_iso
  jmp switch_prot_copy_file

.done_iso:
  mov byte [complete_read], 1
  jmp switch_prot_copy_file

.file_not_found_iso:
  ; Disable VBE
  mov ax, 0x0012
  int 0x10 
  ; Text mode
  mov ax, 0x0003
  int 0x10
  mov si, [error_msg_ptr]
  call print
  jmp fallback_stg1

.iso_err:
  mov ax, 0x0012
  int 0x10
  mov ax, 0x0003
  int 0x10
  jmp fallback_stg1

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

; Include fat32 driver
%include "../drivers/fat32.asm"
; Include iso9660 driver
%include "../drivers/iso9660.asm"

; ======= Data section =======
section .data16
; Variables
is_first_read db 1
current_cluster dd 0
complete_read db 0
fat32_spc db 0
dest_current dd 0
file_name_ptr dw 0
error_msg_ptr dw 0
iso_file_name_ptr dw 0
iso_file_size dd 0
copy_size dd 0
load_type db 0
iso_root_len dd 0

; Initprt filename (FAT 8.3)
initprt_filename db 'INITPRT IMG'
; Initprt filename (ISO)
initprt_filename_iso db 'INITPRT.IMG;1'
msg_initprt_not_found db "[ERROR] Initprt not found",0x0d,0x0a,0

; Kernel filename (FAT 8.3)
kernel_filename db 'PROKA-~1   '
; Kernel filename (ISO)
kernel_filename_iso db 'PROKA-KERNEL;1'
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
