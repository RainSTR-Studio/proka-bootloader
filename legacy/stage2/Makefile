# Proka Bootloader - Driver Build Script
# Copyright (C) 2026 RainSTR Studio. All rights reserved.
#
# Compiles drivers into raw binary format.

NASM := nasm

OUTPUT_DIR ?= output

STAGE2_SRC := main.asm
STAGE2_BIN := $(OUTPUT_DIR)/stage2.bin

all: prepare $(STAGE2_BIN)

prepare:
	mkdir -p $(OUTPUT_DIR)

$(STAGE2_BIN): $(STAGE2_SRC)
	$(NASM) -f bin $< -o $@

clean:
	rm -f $(STAGE2_BIN)

.PHONY: all prepare clean
