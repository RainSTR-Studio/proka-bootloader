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

clean:
	rm -rf $(OUTPUT_DIR) $(BUILD_DIR)

prepare:
	mkdir -p $(OUTPUT_DIR) $(BUILD_DIR)

.PHONY: all legacy uefi clean
