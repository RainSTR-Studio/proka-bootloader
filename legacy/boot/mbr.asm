; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the MBR of the bootloader, which will jump
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
	
	; Enable A20
	in al, 0x92	; Read from A20 port
	or al, 2	; Set as 1
	out 0x92, al	; Send port
	
	; Prepare for Stage 2
	; Read the stage 2 code to 0x8000
	mov ah, 0x2	; Read disk
	mov al, 1	; 16 sectors
	mov ch, 0	; Read from cylinder 0
	mov cl, 2	; Start read from sector 2
	mov dl, 0x80	; Disk head number
	mov bx, 0x8000	; Target address
	int 0x13	; Let's gooo!
	
  ; Output a message
  mov si, msg_stg1
  call print

  ; Check is read succeed
  jc disk_read_error

	; Jump to 0x8000
	jmp 0x0000:0x8000

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

msg_stg1 db "[INFO] Preparing for stage0 -> stage1...",0x0d,0x0a,0
msg_disk_err db "[ERROR] Cannot read stage1 data!",0x0d,0x0a,0
msg_loaded_mbr db "Welcome to Proka Bootloader!",0x0d,0x0a,0

; Add MBR sign
times 510 - ($ - $$) db 0
dw 0xAA55
