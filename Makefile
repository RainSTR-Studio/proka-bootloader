# This is the main makefile of the whole project
OUTPUT_DIR := $(CURDIR)/output
export OUTPUT_DIR

all: legacy uefi
	@echo "[INFO] All platforms' bootloader file are built successfully!"

legacy:
	make -C legacy OUTPUT_DIR=$(OUTPUT_DIR)

uefi:
	make -C uefi

.PHONY: all legacy uefi
