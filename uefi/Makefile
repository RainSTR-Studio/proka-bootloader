# Proka Bootloader - The bootloader for Proka OS
# Copyright (C) RainSTR Studio 2026, All Rights Reserved.
#
# This is the UEFI part bootloader builder, which will build
# the UEFI part of loader.

OUTPUT_DIR ?= build

all:
	@echo "[INFO] Building UEFI..."
	cargo build --release --target x86_64-unknown-uefi
	@echo "[INFO] Copying built target to output directories..."
	cp target/x86_64-unknown-uefi/release/pkbl-uefi.efi $(OUTPUT_DIR)

clean:
	@echo "[INFO] Cleaning UEFI Build targets..."
	cargo clean

.PHONY: all clean
