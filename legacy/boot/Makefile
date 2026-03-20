# Proka Bootloader - Boot Sector Build Script
# Copyright (C) 2026 RainSTR Studio. All rights reserved.
#
# Compiles MBR and stage2 bootloader into raw binary files.

NASM := nasm

BUILD_DIR ?= output

MBR_SRC := mbr.asm
BOOT_SRC := stg1.asm

MBR_BIN := $(BUILD_DIR)/mbr.bin
BOOT_BIN := $(BUILD_DIR)/stg1.bin

all: $(MBR_BIN) $(BOOT_BIN)

$(MBR_BIN): $(MBR_SRC)
	$(NASM) -f bin $< -o $@

$(BOOT_BIN): $(BOOT_SRC)
	$(NASM) -f bin $< -o $@

clean:
	rm -f $(MBR_BIN) $(BOOT_BIN)

.PHONY: all prepare clean
