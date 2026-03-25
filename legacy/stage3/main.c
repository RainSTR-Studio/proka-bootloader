/*
 * Proka Bootloader - The bootloader of Proka OS
 * Copyright (C) RainSTR Studio 2026, All rights reserved.
 * This file is the stage 3 of the whole boot process, which
 * will load kernel and prepare for long mode.
 */
#include "paging.h"
#include <stdbool.h>
#include <stdint.h>
#define phyaddr(x) ((x) - 0x20000)

// Externs
extern void loadkrnl(void);
extern void prepare_sg4(void);

// Page tables placed at fixed physical addresses (4K aligned)
#define PML4_PADDR 0x40000
#define PDPT_LOW_PADDR 0x41000
#define PDPT_HIGH_PADDR 0x42000
#define PDT_LOW_PADDR 0x43000
#define PDT_HIGH_PADDR 0x44000

PML4 *pml4 = (PML4 *)phyaddr(PML4_PADDR);
PDPT *pdpt_low = (PDPT *)phyaddr(PDPT_LOW_PADDR);
PDPT *pdpt_high = (PDPT *)phyaddr(PDPT_HIGH_PADDR);
PDT *pdt_low = (PDT *)phyaddr(PDT_LOW_PADDR);
PDT *pdt_high = (PDT *)phyaddr(PDT_HIGH_PADDR);

// Stage3 main entry point
void stage3_start(void) {
    // Invoke the load kernel in assembly
    loadkrnl();

    // And paging initializator
    init_paging();

    // And can do the next stage preparation
    prepare_sg4();
}

void init_paging(void) {
    // Write the PML4 table
    pml4->entries[0].present = 1;
    pml4->entries[0].writable = 1;
    pml4->entries[0].nx = 0;
    pml4->entries[0].pfn = PDPT_LOW_PADDR >> 12;

    pml4->entries[256].present = 1;
    pml4->entries[256].writable = 1;
    pml4->entries[256].nx = 0;
    pml4->entries[256].pfn = PDPT_HIGH_PADDR >> 12;

    // Write the low PDPT table
    pdpt_low->entries[0].present = 1;
    pdpt_low->entries[0].writable = 1;
    pdpt_low->entries[0].nx = 0;
    pdpt_low->entries[0].pfn = PDT_LOW_PADDR >> 12;

    // Write the low PDT table (0x20000~0x21FFFF)
    pdt_low->entries[0].present = 1;
    pdt_low->entries[0].writable = 1;
    pdt_low->entries[0].huge = 1;
    pdt_low->entries[0].nx = 0;
    pdt_low->entries[0].pfn = 0 >> 12; // PA=0x20000

    // Write the high PDPT table
    pdpt_high->entries[0].present = 1;
    pdpt_high->entries[0].writable = 1;
    pdpt_high->entries[0].nx = 0;
    pdpt_high->entries[0].pfn = PDT_HIGH_PADDR >> 12;

    // Write the high PDT table (128MiB, 64 entries)
    for (uint64_t i = 0; i < 64; i++) {
        pdt_high->entries[i].present = 1;
        pdt_high->entries[i].writable = 1;
        pdt_high->entries[i].huge = 1;
        pdt_high->entries[i].nx = 0;
        pdt_high->entries[i].pfn = ((i + 1) * 0x200000) >> 12;
    }
}
