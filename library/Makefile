# Proka Bootloader - The bootloader for Proka OS
# Copyright (C) RainSTR Studio 2026, All Rights Reserved.
#
# This file is the library part bootloader builder, which will
# build the library and provide some APIs to those loader.

all:
	@echo "[INFO] Building library part for none..."
	cargo build --release --target x86_64-unknown-none
	@echo "[INFO] Building library part for UEFI..."
	cargo build --release --target x86_64-unknown-uefi

clean:
	@echo "[INFO] Cleaning library Build targets..."
	cargo clean

.PHONY: all clean
