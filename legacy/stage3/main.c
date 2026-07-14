/*
 * Proka Bootloader - The bootloader of Proka OS
 * Copyright (C) RainSTR Studio 2026, All rights reserved.
 * This file is the stage 3 of the whole boot process, which
 * will load kernel and prepare for long mode.
 */
#include "paging.h"
#include "acpi.h"
#include "../../build/version.h"
#include <stdbool.h>
#include <stdint.h>

// Externs
extern void loadkrnl(void);
extern void loadinit(void);
extern void prepare_sg4(void);
extern void error(uint32_t errcode);
void init_paging(uint32_t fb_phys);
RSDP *find_rsdp(void);

// Page tables placed at fixed physical addresses (4K aligned)
#define PML4_PADDR 0x40000
#define PDPT_LOW_PADDR 0x41000
#define PDPT_HIGH_PADDR 0x42000
#define PDPT_FB_PADDR 0x43000
#define PDT_LOW_PADDR 0x44000
#define PDT_HIGH_PADDR 0x45000
#define PDT_FB_PADDR 0x46000

PML4 *pml4 = (PML4 *)PML4_PADDR;
PDPT *pdpt_low = (PDPT *)PDPT_LOW_PADDR;
PDPT *pdpt_high = (PDPT *)PDPT_HIGH_PADDR;
PDPT *pdpt_fb = (PDPT *)PDPT_FB_PADDR;
PDT *pdt_low = (PDT *)PDT_LOW_PADDR;
PDT *pdt_high = (PDT *)PDT_HIGH_PADDR;
PDT *pdt_fb = (PDT *)PDT_FB_PADDR;

// Stage3 main entry point
void stage3_start(void)
{
    // Invoke the load kernel and initprt in assembly
    loadkrnl();
    loadinit();

    // Get the VBE phys addr
    uint32_t fb_phys = *(uint32_t *)(0x10000 + 0x28);

    // Do parsing header
    uint32_t magic = *(uint32_t *)0x200000;
    if (magic != 0x504B4E4C)
    {
        error(1);
    }

    uint16_t kmaj = *(uint16_t *)(0x200004);
    uint16_t kmin = *(uint16_t *)(0x200006);
    uint16_t kpat = *(uint16_t *)(0x200008);

    // Check is version mismatched
    if (kmaj != PROKA_VERSION_MAJ ||
        kmin != PROKA_VERSION_MIN ||
        kpat != PROKA_VERSION_PAT)
    {
        error(2);
    }

    // And scan RSDP
    RSDP *ptr = find_rsdp();

    // Check: is RSDP null
    if (!ptr)
    {
        // No ACPI found...
        error(3);
    }

    // Save to 0x10100
    *(volatile uint64_t *)0x10100 = (uint64_t)(uint32_t)ptr;

    // And paging initializator
    init_paging(fb_phys);

    // And can do the next stage preparation
    prepare_sg4();
}

void init_paging(uint32_t fb_phys)
{
    // Write the PML4 table
    pml4->entries[0].value = 0;
    pml4->entries[0].present = 1;
    pml4->entries[0].writable = 1;
    pml4->entries[0].nx = 0;
    pml4->entries[0].pfn = PDPT_LOW_PADDR >> 12;

    pml4->entries[256].value = 0;
    pml4->entries[256].present = 1;
    pml4->entries[256].writable = 1;
    pml4->entries[256].nx = 0;
    pml4->entries[256].pfn = PDPT_HIGH_PADDR >> 12;

    pml4->entries[448].value = 0;
    pml4->entries[448].present = 1;
    pml4->entries[448].writable = 1;
    pml4->entries[448].nx = 0;
    pml4->entries[448].pfn = PDPT_FB_PADDR >> 12;

    // Write the low PDPT table
    pdpt_low->entries[0].value = 0;
    pdpt_low->entries[0].present = 1;
    pdpt_low->entries[0].writable = 1;
    pdpt_low->entries[0].nx = 0;
    pdpt_low->entries[0].pfn = PDT_LOW_PADDR >> 12;

    // Write the low PDT table (0x000000~0x40000000)
    for (uint64_t i = 0; i < 512; i++)
    {
        pdt_low->entries[i].present = 1;
        pdt_low->entries[i].writable = 1;
        pdt_low->entries[i].huge = 1;
        pdt_low->entries[i].nx = 0;
        pdt_low->entries[i].pfn = i * 0x200000 >> 12;
    }

    // Write the high PDPT table
    pdpt_high->entries[0].value = 0;
    pdpt_high->entries[0].present = 1;
    pdpt_high->entries[0].writable = 1;
    pdpt_high->entries[0].nx = 0;
    pdpt_high->entries[0].pfn = PDT_HIGH_PADDR >> 12;

    pdpt_fb->entries[0].value = 0;
    pdpt_fb->entries[0].present = 1;
    pdpt_fb->entries[0].writable = 1;
    pdpt_fb->entries[0].nx = 0;
    pdpt_fb->entries[0].pfn = PDT_FB_PADDR >> 12;

    // Write the high PDT table (128MiB, 64 entries)
    for (uint64_t i = 0; i < 64; i++)
    {
        pdt_high->entries[i].value = 0;
        pdt_high->entries[i].present = 1;
        pdt_high->entries[i].writable = 1;
        pdt_high->entries[i].huge = 1;
        pdt_high->entries[i].nx = 0;
        pdt_high->entries[i].pfn = ((i + 1) * 0x200000) >> 12;
    }

    // Map framebuffer address (16MB)
    for (uint64_t i = 0; i < 8; i++)
    {
        pdt_fb->entries[i].present = 1;
        pdt_fb->entries[i].writable = 1;
        pdt_fb->entries[i].huge = 1;
        pdt_fb->entries[i].write_through = 1;
        pdt_fb->entries[i].pfn = (fb_phys + i * 0x200000) >> 12;
    }
}

RSDP *find_rsdp(void)
{
    // Scan EBDA
    uint16_t ebda_seg = *(uint16_t *)0x40E;
    uintptr_t ebda = (uintptr_t)ebda_seg << 4;

    for (uintptr_t p = ebda; p < ebda + 1024; p += 16)
    {
        if (sig_match((void *)p, RSDP_SIG, 8))
        {
            RSDP *cand = (RSDP *)p;
            if (rsdp_validate(cand))
                return cand;
        }
    }

    // Scan 0xE0000~0xFFFFF
    for (uintptr_t p = 0xE0000; p <= 0xFFFFF; p += 16)
    {
        if (sig_match((void *)p, RSDP_SIG, 8))
        {
            RSDP *cand = (RSDP *)p;
            if (rsdp_validate(cand))
                return cand;
        }
    }

    return 0;
}
