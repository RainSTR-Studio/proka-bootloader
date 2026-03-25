/*
 * Proka Bootloader - The bootloader of Proka OS
 * Copyright (C) RainSTR Studio 2026, All rights reserved.
 *
 * This file defines 64-bit long mode paging structures
 * which is used for virtual memory initialization in
 * boot stage3.
 */

#ifndef PAGING_H
#define PAGING_H

#include <stdint.h>

/*
 * Page Table Entry (64-bit)
 * Used by PML4, PDPT and PDT
 */
typedef union PageEntry {
    uint64_t value;
    struct {
        uint64_t present : 1;       /* Present in memory */
        uint64_t writable : 1;      /* Writable */
        uint64_t user : 1;          /* User-mode accessible */
        uint64_t write_through : 1; /* Write-through caching */
        uint64_t cache_disable : 1; /* Cache disable */
        uint64_t accessed : 1;      /* Software accessed */
        uint64_t dirty : 1;         /* Dirty (only for PT) */
        uint64_t huge : 1;          /* Huge page (2MB/1GB) */
        uint64_t global : 1;        /* Global page */
        uint64_t _reserved0 : 3;    /* Reserved */
        uint64_t pfn : 40;          /* Physical frame number */
        uint64_t _reserved1 : 11;   /* Reserved */
        uint64_t nx : 1;            /* No-execute */
    } __attribute__((packed));
} pte_t, pde_t, pdpe_t, pml4e_t;

/* Each table holds exactly 512 entries (4KB) */
#define PTE_ENTRY_COUNT 512

/* Long-mode 3-level paging hierarchy */
typedef struct {
    pde_t entries[PTE_ENTRY_COUNT];
} PDT;

typedef struct {
    pdpe_t entries[PTE_ENTRY_COUNT];
} PDPT;

typedef struct {
    pml4e_t entries[PTE_ENTRY_COUNT];
} PML4;

/* Common page flags */
#define PAGE_PRESENT (1ULL << 0)
#define PAGE_WRITABLE (1ULL << 1)
#define PAGE_HUGE (1ULL << 7)
#define PAGE_NX (1ULL << 63)

/* Page size constants */
#define PAGE_SIZE 4096
#define PAGE_MASK (~(PAGE_SIZE - 1))

/* Virtual address indexing */
#define PML4_IDX(va) (((uint64_t)(va) >> 39) & 0x1FF)
#define PDPT_IDX(va) (((uint64_t)(va) >> 30) & 0x1FF)
#define PDT_IDX(va) (((uint64_t)(va) >> 21) & 0x1FF)

/* Offset within a 4KB page */
#define PAGE_OFFSET(va) ((uint64_t)(va) & 0xFFF)

#endif
