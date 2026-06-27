; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the ISO9660 reader.
[bits 16]	; Still real mode :/

; ==============================
; load_iso9660_file
; Load one file from ISO9660 filesystem.
; In: DS:SI - The filename
;     ES:BX - The load position
; ==============================   
load_iso9660_file:
  pushad
  push es
  mov bp, sp
  cld

  ; Save ES, BX
  mov [save_es], es
  mov [save_bx], bx


; =======================================
; DATA SECTIONS
; =======================================
save_es dw 0
save_bx dw 0
