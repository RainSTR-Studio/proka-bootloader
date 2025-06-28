#!/bin/bash

set -e

# Make the compile mode sure
if [[ $1 == "--release" ]]; then
    MODE="--release"
    shift
else
    MODE=""
fi

# Build UEFI
echo "[BUILDINFO] Building UEFI application ($(if [[ $MODE == "--release" ]]; then echo "release"; else echo "debug"; fi) mode)..."
cargo build $MODE --target x86_64-unknown-uefi -p loader

# Build scripts
echo "[BUILDINFO] Building scripts ($(if [[ $MODE == "--release" ]]; then echo "release"; else echo "debug"; fi) mode)..."
cargo build $MODE -p scripts

echo "[BUILDINFO] Build completed successfully."
