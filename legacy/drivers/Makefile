# Proka Bootloader - Driver Build Script
# Copyright (C) 2026 RainSTR Studio. All rights reserved.
#
# Compiles drivers into raw binary format.

NASM := nasm

OUTPUT_DIR ?= output

FAT32_SRC := fat32.asm
FAT32_BIN := $(OUTPUT_DIR)/fat32.bin

all: prepare $(FAT32_BIN)

prepare:
	mkdir -p $(OUTPUT_DIR)

$(FAT32_BIN): $(FAT32_SRC)
	$(NASM) -f bin $< -o $@

clean:
	rm -f $(FAT32_BIN)

.PHONY: all prepare clean
