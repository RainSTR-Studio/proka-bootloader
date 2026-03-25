# Proka Bootloader - Driver Build Script
# Copyright (C) 2026 RainSTR Studio. All rights reserved.
#
# Compiles drivers into raw binary format.

NASM := nasm
CC := gcc
CFLAGS = -m32 -ffreestanding -fno-pie -fno-stack-protector -fno-builtin -Wall -Wextra -c

OUTPUT_DIR ?= output

STAGE3_C_SRC := main.c
STAGE3_ASM_SRC := loadkrnl.asm prestg4.asm
STAGE3_C_BIN := $(BUILD_DIR)/stage3.o
STAGE3_ASM_BIN  := $(patsubst %.asm,$(BUILD_DIR)/%.o,$(STAGE3_ASM_SRC))

all: prepare $(STAGE3_C_BIN) $(STAGE3_ASM_BIN)

prepare:
	mkdir -p $(OUTPUT_DIR)

$(STAGE3_C_BIN): $(STAGE3_C_SRC)
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/%.o: %.asm
	$(NASM) -f elf32 $< -o $@

clean:
	rm -f $(STAGE3_BIN)

.PHONY: all prepare clean
