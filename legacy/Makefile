# Proka Bootloader - Top-level Build Script
# Copyright (C) 2026 RainSTR Studio. All rights reserved.
#
# Builds all boot components and creates a plain concatenated disk image.

SUBDIRS := boot stage2

# Default target
all: build-subdirs $(OUTPUT_DIR)/BOOTMBR
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

# Clean
clean:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done
	rm -rf $(BUILD_DIR)
	@echo "[INFO] Clean complete"

.PHONY: all build-subdirs run clean
