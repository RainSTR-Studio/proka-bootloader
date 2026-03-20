/*
 * Proka Bootloader - The bootloader of Proka OS
 * Copyright (C) RainSTR Studio 2026, All rights reserved.
 *
 * This file is the stage 3 of the whole boot process, which
 * will load kernel and prepare for long mode.
 */
#include <stdbool.h>
#define phyaddr(x) ((x)-0x20000)

// Stage3 main entry point
void stage3_start(void) {
    *(unsigned char *)phyaddr(0x1000f0) = 0x41;
    while (true) {}
}
