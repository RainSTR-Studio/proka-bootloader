; Proka Bootloader - The bootloader of Proka OS
; Copyright (C) RainSTR Studio 2026, All rights reserved.
;
; This file is the ISO9660 reader.
[bits 16]

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
  mov [save_si], si
  mov [save_ds], ds

  ; Read ISO9660 PVD to 0000:0c000
  ; ISO logical block LBA=16 (2048B)
  xor edx, edx        ; Clear LBA high 32bit
  mov eax, 16
  mov cx, 1
  push eax
  xor ax, ax
  mov es, ax
  pop eax
  mov bx, 0xc000
  call iso9660_read_lba
  jc .err

.validate:
  ; Now the CD-ROM's PVD is at 0xc000.
  ; Since then, we can read it and parse it.
  ; But, we should verify it first!
  ;
  ; According to the specification, we shall
  ; check is the first byte 0x1 and 1-5 is "CD001".
  xor ax, ax
  mov ds, ax
  mov si, 0xc001

  ; Check is this CD001
  mov di, signature
  mov cx, 5
  repe cmpsb   ; Continuiously cmp 5 bytes
  jnz .bad_sig

  ; Check is this PVD
  mov al, byte [0xc000]
  cmp al, 1
  jne .inv_pvd

.parse_pvd:
  ; After we validate PVD, we can read the record of
  ; the root directory.
  mov eax, 0xc09c       ; Root entry record
  call iso9660_read_record

  ; It's time to fill DAP again...
  mov dword [root_dir_len], ecx
  push eax
  xor ax, ax
  mov es, ax
  pop eax
  mov bx, 0xc800
  add ecx, 2047
  shr ecx, 11   ; ECX / 2048
  call iso9660_read_lba
  jc .err

  ; Just loaded the root dir's record, the next one is to
  ; parse it
  mov si, word [save_si]
  mov ds, [save_ds]
  mov eax, 0xc800
  mov ecx, [root_dir_len]
  call iso9660_get_fileinfo
  jc .err

  ; Load the file content into ES:BX
  mov edx, 0
  add ecx, 2047
  shr ecx, 11
  mov es, [save_es]
  mov bx, [save_bx]
  call iso9660_read_lba
  jc .err
  pop es
  popad
  clc
  ret

.inv_pvd:
  mov si, msg_inv_pvd
  call print
  jmp .err

.bad_sig:
  mov si, msg_bad_sig
  call print
  jmp .err

.err:
  pop es
  popad
  stc
  ret

; ==============================
; iso9660_read_record
; Read the directory record from specified address.
; In: EAX = The record start address
; Out: EAX = The LBA which is contained in record
;      ECX = The length of this file (byte)
;      SI = The record length
; ==============================
iso9660_read_record:
  push ebx
  push es

  ; set data segment
  mov bx, ax
  shr eax, 16
  mov es, ax

  ; SI = record length (offset 0, 1 byte)
  movzx si, byte [es:bx]

  ; load LBA (offset 2, 8 bytes, ISO dual-endian)
  mov eax, [es:bx + 2]

  ; load file length (offset 10, 8 bytes)
  mov ecx, [es:bx + 10]
  pop es
  pop ebx
  ret

; ==============================
; iso9660_get_fileinfo
; Get the file info through filename
; In:  EAX = Root directory record start addr
;      ECX = Max length of all record
;      DS:SI = The source of the file name
; Out: EAX = The file's LBA
;      ECX = The file size (in bytes)
; ==============================
iso9660_get_fileinfo:
  clc
  push es
  push eax
  xor ax, ax
  mov es, ax
  pop eax
  mov [length], ecx
  mov [nameptr], si
  mov edx, eax
  add edx, ecx
  mov [dir_end], edx

.read:
  ; So, in this fn, we need to compare the filename
  ; The filename is at offset 0x22, so the record which
  ; is lower than 0x22 is being passed.
  movzx esi, byte [eax]
  cmp esi, 0x22
  jb .update
  mov [rec_len], esi

  ; If not lower, we shall compare it...
  movzx ecx, byte [eax + 0x20]
  movzx esi, word [nameptr]
  mov edi, eax
  add edi, 0x21
  repe cmpsb
  jz .info

.update:
  ; Check: Is ESI zero
  mov esi, [rec_len]
  test esi, esi
  jz .not_found
  add eax, esi

  ; Check: Is over than ECX's specified length
  cmp eax, [dir_end]
  jae .not_found
  jmp .read

.info
  ; If we are here, seems we have matched.
  call iso9660_read_record
  pop es
  clc
  ret

.not_found:
  pop es
  stc
  ret

; ==============================
; iso9660_read_lba
; Read the disk through LBA (int 13h AH=0x42)
; In: EDX:EAX = LBA
;     ECX = Sector count
;     ES:BX = buffer
; ==============================
iso9660_read_lba:
  pushad
.fill_dap:
  ; Fill the DAP sturcture
  mov word [dap + 2], cx        ; Sectors to read
  mov word [dap + 4], bx        ; Buffer offset
  mov word [dap + 6], es        ; Buffer segment
  mov dword [dap + 8], eax      ; LBA low 32-bit
  mov dword [dap + 12], edx     ; LBA high 32-bit

.read:
  ; Issue BIOS interrupt
  mov si, dap
  mov ah, 0x42
  mov dl, [0x0500]
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
save_si dw 0
save_ds dw 0
root_dir_len dd 0
length dd 0
nameptr dw 0
dir_end dd 0
rec_len dd 0
signature db "CD001"
msg_bad_sig db "[ISO9660] [ERROR] Bad signature",0x0d,0x0a,0
msg_inv_pvd db "[ISO9660] [ERROR] Invalid PVD!",0x0d,0x0a,0

; DAP structure
dap:
  db 0x10        ; DAP size (fixed)
  db 0           ; Reserved
  dw 0           ; The sectors which you want to read
  dw 0           ; Buffer offset
  dw 0           ; Buffer segment
  dd 0           ; LBA sector (low)
  dd 0           ; LBA sector (high)
