# Proka Bootloader - Top-level Build Script
# Copyright (C) 2026 RainSTR Studio. All rights reserved.
#
# Builds all boot components and creates a plain concatenated disk image.

SUBDIRS := boot stage2 stage3
LDFLAGS = -m elf_i386 -T linker.ld --oformat elf32-i386
SHOULD_LINK = $(BUILD_DIR)/stage2.o $(BUILD_DIR)/stage3.o
LINK_TARGET = $(BUILD_DIR)/pkldr.elf
BIN_TARGET = $(OUTPUT_DIR)/pkldr

# Default target
all: build-subdirs $(OUTPUT_DIR)/BOOTMBR bin
	@echo "[INFO] Successfully built legacy bootloader in $(OUTPUT_DIR) !"

# Build all subdirectories
build-subdirs:
	@for dir in $(SUBDIRS); do \
		echo "== Building in $$dir =="; \
		$(MAKE) -C $$dir; \
	done

$(OUTPUT_DIR)/BOOTMBR:
	dd if=/dev/zero of=$@ bs=1M count=1 status=none
	cat $(BUILD_DIR)/mbr.bin \
	    $(BUILD_DIR)/stg1.bin \
            > $@

# The after-hook of linking
bin: $(LINK_TARGET)
	objcopy -O binary $< $(BIN_TARGET)

$(LINK_TARGET): $(SHOULD_LINK)
	$(LD) $(LDFLAGS) $^ -o $@

# Clean
clean:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done
	rm -rf $(BUILD_DIR)
	@echo "[INFO] Clean complete"

.PHONY: all build-subdirs run clean
