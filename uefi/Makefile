# The UEFI part bootloader builder

OUTPUT_DIR ?= build

all:
	@echo "Building UEFI part (release mode)..."
	cargo build --release --target x86_64-unknown-uefi
	@echo "Copying built target to output directories..."
	cp target/x86_64-unknown-uefi/release/proka_bootloader.efi $(OUTPUT_DIR)

clean:
	@echo "Cleaning UEFI Build targets..."
	cargo clean

debug:
	@echo "Building UEFI part (debug mode)..."
	cargo build --target x86_64-unknown-uefi
	# No need copy if in debug mode...

.PHONY: all clean debug
