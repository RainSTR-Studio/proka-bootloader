# Proka Bootloader - Driver Build Script
# Copyright (C) 2026 RainSTR Studio. All rights reserved.
#
# Compiles drivers into raw binary format.

NASM := nasm

OUTPUT_DIR ?= output

STAGE2_SRC := main.asm
STAGE2_BIN := $(BUILD_DIR)/stage2.o

all: $(STAGE2_BIN)

$(STAGE2_BIN): $(STAGE2_SRC)
	$(NASM) -f elf32 $< -o $@

clean:
	rm -f $(STAGE2_BIN)

.PHONY: all prepare clean
