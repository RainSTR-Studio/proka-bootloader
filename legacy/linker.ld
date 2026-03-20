/*
 * Proka Bootloader
 * Linker Script for 16-bit stage2 and 32/64-bit stage3
 * Copyright (C) RainSTR Studio 2026, All Rights Reserved.
 *
 * This script separates 16-bit real-mode code and data
 * with VMA = 0 (to fit 16-bit offsets) and LMA = 0x20000
 * (loaded to 0x2000:0000). 32-bit code is placed above
 * the 16-bit region with full 32-bit addressing.
 */

OUTPUT_FORMAT(elf32-i386)
ENTRY(stage2_start)

SECTIONS
{
    /*
     * Base for 16-bit code: VMA starts at 0
     * to ensure all offsets fit in 16 bits.
     */
    . = 0x0;

    /*
     * 16-bit code section
     * Loaded (LMA) at 0x20000 (0x2000:0000)
     * Data is also here (.text.data)
     */
    .text : AT(0x20000)
    {
        *(.text.head)
        *(.text*)
	*(.rodata*)
	*(.data*)
	*(.bss)
    }

    /* Discard unused sections to avoid warnings */
    /DISCARD/ :
    {
        *(.comment)
        *(.note.gnu.property)
    }
}
