/*
 * Proka Bootloader 
 * Linker Script for 16-bit stage2 and 32/64-bit stage3
 * Copyright (C) RainSTR Studio 2026, All Rights Reserved.     
 *
 * This script separates 16-bit real-mode code (VMA=0)
 * from 32/64-bit protected mode code (VMA=0x20000)
 * All code is loaded contiguously starting at 0x20000.
 */ 

OUTPUT_FORMAT(elf32-i386)  
ENTRY(stage2_start)

SECTIONS
{
    /*
     * 16-bit code and data: VMA starts at 0 to fit 16-bit offsets
     * Loaded (LMA) at 0x20000 (0x2000:0000)
     * Contains all 16-bit related code and data
     */
    .text16 0x0 : AT(0x20000)
    {
        *(.text16.head)
        *(.text16*)
        *(.rodata16*)
        *(.data16*)
        *(.bss16*)
    }
    
    /*
     * 32/64-bit code and data: VMA starts at 0x20000 to match LMA
     * This prevents the linker from adding base offset to symbols
     * Loaded immediately after the 16-bit section
     */
    .text 0x20000 + SIZEOF(.text16) : AT(0x20000 + SIZEOF(.text16))
    {
        *(.text*)
        *(.rodata*)
        *(.data*)
        *(.bss)
    }
    
    /* Align to page boundary for cleaner loading */
    . = ALIGN(0x1000);
    
    /* Discard unused sections to avoid warnings */
    /DISCARD/ :
    {
        *(.comment)
        *(.note.gnu.property)
        *(.eh_frame)
        *(.eh_frame_hdr)
    }
}
