# Proka Bootloader - Boot Sector Build Script
# Copyright (C) 2026 RainSTR Studio. All rights reserved.
#
# Compiles MBR and stage2 bootloader into raw binary files.

NASM := nasm

OUTPUT_DIR ?= output

MBR_SRC := mbr.asm
BOOT_SRC := stg1.asm

MBR_BIN := $(OUTPUT_DIR)/mbr.bin
BOOT_BIN := $(OUTPUT_DIR)/stg1.bin

all: prepare $(MBR_BIN) $(BOOT_BIN)

prepare:
	mkdir -p $(OUTPUT_DIR)

$(MBR_BIN): $(MBR_SRC)
	$(NASM) -f bin $< -o $@

$(BOOT_BIN): $(BOOT_SRC)
	$(NASM) -f bin $< -o $@

clean:
	rm -f $(MBR_BIN) $(BOOT_BIN)

.PHONY: all prepare clean
