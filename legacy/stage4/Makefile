# Proka Bootloader - Driver Build Script
# Copyright (C) 2026 RainSTR Studio. All rights reserved.
#
# Compiles the stage4 code file

NASM := nasm

BUILD_DIR ?= build
LIB_FILE := target/i686-unknown-none/release/libstage4.a

all:
	@echo "[INFO] Building stage4 code in release..."
	cargo build --release --target i686-unknown-none.json
	@echo "[INFO] Copying the lib file to build dir..."
	cp $(LIB_FILE) $(BUILD_DIR)/stage4.a

clean:
	cargo clean

.PHONY: all prepare clean
