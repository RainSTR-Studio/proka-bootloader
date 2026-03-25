# This is the main makefile of the whole project
BUILD_DIR := $(CURDIR)/build
OUTPUT_DIR := $(CURDIR)/output
export BUILD_DIR
export OUTPUT_DIR

all: legacy uefi
	@echo "[INFO] All platforms' bootloader file are built successfully!"

legacy: clean prepare
	@echo "======= BUILD LEGACY ======="
	make -C legacy

uefi: prepare
	@echo "======= BUILD UEFI ======="
	make -C uefi

clean: clean-sub
	make -C uefi clean
	make -C library clean
	rm -rf $(OUTPUT_DIR) $(BUILD_DIR)

prepare:
	mkdir -p $(OUTPUT_DIR) $(BUILD_DIR)
	@echo "======= BUILD CORE LIBRARY ======="
	make -C library


.PHONY: all legacy uefi clean clean-sub
