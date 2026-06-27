; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the CD-ROM bootloader, which will jump
; to the loader_main to do more initializations.
; 
; Also, This part is the stage 0 -> stage 1 
; of the boot process.
[org 0x7c00]	; MBR code at 0x7c00
[bits 16]	; Real mode code

; Stage 0: Set up MBR
boot:
  cli		; Disable interrupt
  
  ; Clear all Segment
  xor ax, ax	; Set AX as 0
  mov ds, ax	; Clear DS
  mov es, ax	; Clear ES
  mov ss, ax	; Clear SS
  
  ; Set up stack
  mov sp, 0x7c00	; Set stack pointer as 0x7c00

  mov byte [0x0500], dl

  ; Clear screen
  mov ax, 0x0600
  mov bh, 0x07
  xor cx, cx
  mov dx, 0x184f
  int 0x10

  ; Reset cursor position
  mov ah, 0x02
  mov bh, 0 
  mov dh, 0 
  mov dl, 0 
  int 0x10

  ; Print welcome message
  mov si, msg_loaded_mbr
  call print
	
  ; Output a message
  mov si, msg_stg1
  call print

  ; Check is read succeed
  jc disk_read_error

  ; Jump to 0x8000
  jmp stage1

stage1:
  mov si, msg_enter_stg1
  call print

  mov si, msg_emit_cdrom
  call print

  mov si, filename
  mov ax, 0x2000
  mov es, ax
  mov bx, 0 
  call load_iso9660_file

  jmp $

print:
  mov ah, 0x0e

.next:
  lodsb
  cmp al, 0 
  je .done
  int 0x10
  jmp .next
.done:
  ret

disk_read_error:
  ; Output msg_disk_err
  mov si, msg_disk_err
  call print
  jmp hang

hang:
  hlt
  jmp hang


msg_stg1 db "[STAGE] Preparing for stage0 -> stage1...",0x0d,0x0a,0
msg_enter_stg1 db "[STAGE] Entered stage1",0x0d,0x0a,0
msg_emit_cdrom db "[INFO] This is CD-ROM boot mode, will use ISO9660 reader...",0x0d, 0x0a, 0
msg_disk_err db "[ERROR] Cannot read stage1 data!",0x0d,0x0a,0
msg_loaded_mbr db "Welcome to Proka Bootloader!",0x0d,0x0a,0
filename db "PROKA-KERNEL",0

%include "../drivers/iso9660.asm"
