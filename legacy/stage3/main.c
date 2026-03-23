/*
 * Proka Bootloader - The bootloader of Proka OS
 * Copyright (C) RainSTR Studio 2026, All rights reserved.
 *
 * This file is the stage 3 of the whole boot process, which
 * will load kernel and prepare for long mode.
 */
#include "paging.h"
#include <stdbool.h>
#define phyaddr(x) ((x) - 0x20000)

// Externs
extern void loadkrnl(void);

// Global variables
PML4 pml4 __attribute__((aligned(4096))) = {0};
PDPT pdpt_low __attribute__((aligned(4096))) = {0};
PDPT pdpt_high __attribute__((aligned(4096))) = {0};
PDT pdt_low __attribute__((aligned(4096))) = {0};
PDT pdt_high __attribute__((aligned(4096))) = {0};

// Stage3 main entry point
void stage3_start(void) {
    // Invoke the load kernel in assembly
    loadkrnl();

    // And paging initializator
    init_paging();

    while (true) {}
}

void init_paging(void) {
    // Write the PML4 table
    pml4.entries[0].present = 1;
    pml4.entries[0].writable = 1;
    pml4.entries[0].nx = 0;
    pml4.entries[0].pfn = (uint64_t)&pdpt_low >> 12;
    pml4.entries[256].present = 1;
    pml4.entries[256].writable = 1;
    pml4.entries[256].nx = 0;
    pml4.entries[256].pfn = (uint64_t)&pdpt_high >> 12;

    // Write the low PDPT table
    pdpt_low.entries[0].present = 1;
    pdpt_low.entries[0].writable = 1;
    pdpt_low.entries[0].nx = 0;
    pdpt_low.entries[0].pfn = (uint64_t)&pdt_low >> 12;

    // Write the low PDT table (only 0x200000)
    pdt_low.entries[0].present = 1;
    pdt_low.entries[0].writable = 1;
    pdt_low.entries[0].huge = 1;
    pdt_low.entries[0].nx = 0;
    pdt_low.entries[0].pfn = 0; // Phys addr 0
    pdt_low.entries[0].global = 1;
    
    // Write the high PDPT table
    pdpt_high.entries[0].present = 1;
    pdpt_high.entries[0].writable = 1;
    pdpt_high.entries[0].nx = 0;
    pdpt_high.entries[0].pfn = (uint64_t)&pdt_high >> 12;

    // Write the high PDT table (128MiB, 64 entries)
    for (uint64_t i = 0; i < 64; i++) {
        pdt_high.entries[i].present = 1;
        pdt_high.entries[i].writable = 1;
        pdt_high.entries[i].huge = 1;
        pdt_high.entries[i].nx = 0;
        pdt_high.entries[i].pfn = (0x100000 + i * 0x200000) >> 12;
        pdt_high.entries[i].global = 1;
    }
}
