; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the ISO9660 reader.

; ==============================
; load_iso9660_file
; Load one file from ISO9660 filesystem.
; In: DS:SI = The filename
;     ES:BX = The load position
;     [0x500] = The disk type
; ==============================   
load_iso9660_file:
  pushad
  push es
  mov bp, sp
  cld

  ; Save ES, BX
  mov [save_es], es
  mov [save_bx], bx

  ; Since we saved the essential thing, we shall 
  ; read the ISO9660's PVD to 0xc000.
  ; So, we should fill an DAP and specify LBA 64 (an LBA size is 512)
  ; Note: The ISO's LBA size is 2048, the specification says it's LBA 16,
  ; but here we have to (x << 2).
  mov eax, 64
  mov cx, 4	; 2048 / 512 = 4
  push eax
  xor ax, ax
  mov es, ax
  pop eax
  mov bx, 0xc000
  call iso9660_read_lba

; ==============================
; iso9660_read_lba
; Read the disk through LBA (int 13h AH=0x42)
; In: EDX:EAX = LBA
;     CX = Sector count 
;     ES:BX = buffer
; ==============================
iso9660_read_lba:
  pushad

.fill_dap:
  ; Fill the DAP sturcture
  mov word [dap + 2], cx	; Sectors to read
  mov word [dap + 4], bx	; Buffer offset
  mov word [dap + 6], es	; Buffer segment
  mov dword [dap + 8], eax	; LBA low 32-bit
  mov dword [dap + 12], 0	; LBA high 32-bit (set to 0)

.read:
  ; Issue BIOS interrupt
  push eax
  xor ax, ax
  mov fs, ax
  pop eax
  mov si, dap
  mov ah, 0x42
  mov dl, [fs:0x0500]
  int 0x13
  jc .disk_err
  
  popad
  ret

.disk_err:
  popad
  stc
  ret

; =======================================
; DATA SECTIONS
; =======================================
save_es dw 0
save_bx dw 0

; DAP structure
dap:
  db 0x10	; DAP size (fixed)
  db 0		; Reserved
  dw 0		; The sectors which you want to read
  dw 0		; Buffer offset
  dw 0		; Buffer segment
  dd 0		; LBA sector (low)
  dd 0		; LBA sector (high)
