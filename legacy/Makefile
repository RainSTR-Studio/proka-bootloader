# Proka Bootloader - Top-level Build Script
# Copyright (C) 2026 RainSTR Studio. All rights reserved.
#
# Builds all boot components and creates a plain concatenated disk image.
# No linking, no ELF, just raw binary concatenation.

SUBDIRS := boot drivers

# Default target
all: build-subdirs $(OUTPUT_DIR)/hd.img
	@echo "[INFO] Build complete: $(OUTPUT_DIR)/hd.img"

# Build all subdirectories
build-subdirs:
	@for dir in $(SUBDIRS); do \
		echo "== Building in $$dir =="; \
		$(MAKE) -C $$dir; \
	done

# Create disk image by RAW CONCATENATION (no linking)
$(OUTPUT_DIR)/hd.img:
	dd if=/dev/zero of=$@ bs=1M count=1 status=none
	cat $(OUTPUT_DIR)/mbr.bin \
	    $(OUTPUT_DIR)/boot.bin \
	    $(OUTPUT_DIR)/fat32.bin > $@

# Run QEMU
run: $(OUTPUT_DIR)/hd.img
	qemu-system-x86_64 -hda $(OUTPUT_DIR)/hd.img -vnc :0 -serial stdio

# Clean
clean:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done
	rm -rf $(OUTPUT_DIR)
	@echo "[INFO] Clean complete"

.PHONY: all build-subdirs run clean
