/*
 * Proka Bootloader - The bootloader of Proka OS
 * Copyright (C) RainSTR Studio 2026, All rights reserved.
 * This file is the stage 3 of the whole boot process, which
 * will load kernel and prepare for long mode.
 */
#include "paging.h"
#include <stdbool.h>
#include <stdint.h>

// Externs
extern void loadkrnl(void);
extern void prepare_sg4(void);

// Page tables placed at fixed physical addresses (4K aligned)
#define PML4_PADDR 0x60000
#define PDPT_LOW_PADDR 0x61000
#define PDPT_HIGH_PADDR 0x62000
#define PDT_LOW_PADDR 0x63000
#define PDT_HIGH_PADDR 0x64000
#define PDT_FB_PADDR 0x65000

PML4 *pml4 = (PML4 *)PML4_PADDR;
PDPT *pdpt_low = (PDPT *)PDPT_LOW_PADDR;
PDPT *pdpt_high = (PDPT *)PDPT_HIGH_PADDR;
PDT *pdt_low = (PDT *)PDT_LOW_PADDR;
PDT *pdt_high = (PDT *)PDT_HIGH_PADDR;
PDT *pdt_fb = (PDT *)PDT_FB_PADDR;

// Stage3 main entry point
void stage3_start(void) {
    // Invoke the load kernel in assembly
    loadkrnl();

    // Get the VBE phys addr
    uint32_t fb_phys = *(uint32_t*)(0x10000 + 0x28);
    *(uint32_t *)fb_phys = 0xFFFFFFFF;

    // And paging initializator
    init_paging(fb_phys);

    // And can do the next stage preparation
    prepare_sg4();
}

void init_paging(uint32_t fb_phys) {
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
    
    pdpt_high->entries[1].present = 1;
    pdpt_high->entries[1].writable = 1;
    pdpt_high->entries[1].nx = 1; // Framebuffer is not execitable
    pdpt_high->entries[1].pfn = PDT_FB_PADDR >> 12;
    
    // Write the high PDT table (128MiB, 64 entries)
    for (uint64_t i = 0; i < 64; i++) {
        pdt_high->entries[i].present = 1;
        pdt_high->entries[i].writable = 1;
        pdt_high->entries[i].huge = 1;
        pdt_high->entries[i].nx = 0;
        pdt_high->entries[i].pfn = ((i + 1) * 0x200000) >> 12;
    }

    // Map framebuffer address (4MB)
    for (uint64_t i = 0; i < 2; i++) {
        pdt_fb->entries[i].present = 1;
        pdt_fb->entries[i].writable = 1;
        pdt_fb->entries[i].huge = 1;
        pdt_fb->entries[i].nx = 1;
        pdt_fb->entries[i].cache_disable = 1;
        pdt_fb->entries[i].pfn = (fb_phys + i * 0x200000) >> 12;
    }
}
