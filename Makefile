# This is the main makefile of the whole project
OUTPUT_DIR := $(CURDIR)/output
export OUTPUT_DIR

all: legacy uefi
	@echo "[INFO] All platforms' bootloader file are built successfully!"

legacy: clean
	make -C legacy OUTPUT_DIR=$(OUTPUT_DIR)

uefi:
	make -C uefi

clean:
	rm -rf $(OUTPUT_DIR)

.PHONY: all legacy uefi clean
