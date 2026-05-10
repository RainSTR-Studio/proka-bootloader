/*
 * Proka Bootloader - The bootloader of Proka OS
 * Copyright (C) RainSTR Studio 2026, All rights reserved.
 *
 * This file defines ACPI structures to help bootloader 
 * discovor and validate the RSDP table, then put to an
 * specified address.
 */
#ifndef ACPI_H
#define ACPI_H

#include <stdint.h>

// The RSDP magic signature
#define RSDP_SIG "RSD PTR "

// The RSDP struct
typedef struct {
    char        sig[8];
    uint8_t     checksum;
    char        oem[6];
    uint8_t     rev;
    uint32_t    rsdt;
    uint32_t    len;
    uint64_t    xsdt;
    uint8_t     ext_csum;
    uint8_t     resv[3];
} __attribute__((packed)) RSDP;

// The validater of RSDP
static inline int rsdp_validate(const RSDP *r) {
    uint8_t sum = 0;
    int len = (r->rev >= 2) ? 36 : 20;
    for (int i = 0; i < len; i++)
        sum += ((uint8_t *)r)[i];
    return sum == 0;
}

// The signature matcher
static inline int sig_match(const void *addr, const char *sig, uint32_t len) {
    const uint8_t *a = (const uint8_t *)addr;
    const uint8_t *b = (const uint8_t *)sig;

    for(uint32_t i = 0; i < len; i++)
    {
        if(a[i] != b[i])
            return 0;
    }
    return 1;
}

#endif	// ACPI_H

