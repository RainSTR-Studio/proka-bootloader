#!/usr/bin/env python3
# Proka Bootloader - Python Build System
# Copyright (C) 2026 RainSTR Studio. Licensed under GNU GPLv3.
# Usage:
#     python3 build.py            # build all (legacy + uefi), same as `make`
#     python3 build.py legacy     # build the legacy (BIOS) bootloader only
#     python3 build.py uefi       # build the UEFI bootloader only
#     python3 build.py clean      # remove all build artifacts
import os
import shutil
import subprocess
import sys
import argparse
import logging

# ANSI color codes
BOLD = "\033[1m"
RESET = "\033[0m"
CYAN = "\033[36m"

class CustomFormatter(logging.Formatter):
    def format(self, record):
        if record.levelno == logging.INFO:
            return f"{BOLD}[INFO]{RESET} {record.getMessage()}"
        return super().format(record)

# Configure logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setFormatter(CustomFormatter())
logger.addHandler(handler)
# Prevent duplicate messages
logger.propagate = False

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BUILD_DIR = os.path.join(BASE_DIR, "cache")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
SUBDIRS = ["boot", "stage2", "stage3", "stage4"]


def run(cmd, cwd=BASE_DIR, check=True):
    """Run a command, log it. Mirrors Make's command echo."""
    logger.info(f"{BOLD}{CYAN}Running:{RESET} {' '.join(cmd)}")
    subprocess.run(cmd, cwd=cwd, check=check)


def find_tool(name, fallback):
    """Locate a tool on PATH, falling back to a hard-coded name."""
    path = shutil.which(name)
    return path if path else fallback


def ensure_dirs():
    os.makedirs(BUILD_DIR, exist_ok=True)
    os.makedirs(OUTPUT_DIR, exist_ok=True)


def gen_version():
    """`prepare` hook: generate version headers (C / ASM / Rust)."""
    logger.info("Generating version headers...")
    run(["python3", "gen_version.py"])


class Builder:
    """Base builder class"""
    def __init__(self):
        raise NotImplementedError

    def clean(self):
        raise NotImplementedError


class Legacy(Builder):
    def build_boot(self):
        logger.info("Building in boot")
        nasm = find_tool("nasm", "nasm")
        boot_dir = os.path.join(BASE_DIR, "legacy", "boot")
        run([nasm, "-f", "bin", "mbr.asm", "-o", os.path.join(BUILD_DIR, "mbr.bin")], cwd=boot_dir)
        run([nasm, "-f", "bin", "stg1.asm", "-o", os.path.join(BUILD_DIR, "stg1.bin")], cwd=boot_dir)
        run([nasm, "-f", "bin", "cdrom.asm", "-o", os.path.join(OUTPUT_DIR, "cdboot.bin")], cwd=boot_dir)

    def build_stage2(self):
        logger.info("Building in stage2")
        nasm = find_tool("nasm", "nasm")
        stage2_dir = os.path.join(BASE_DIR, "legacy", "stage2")
        run([nasm, "-f", "elf32", "main.asm", "-o", os.path.join(BUILD_DIR, "stage2.o")], cwd=stage2_dir)

    def build_stage3(self):
        logger.info("Building in stage3")
        nasm = find_tool("nasm", "nasm")
        cc = find_tool("gcc", "gcc")
        stage3_dir = os.path.join(BASE_DIR, "legacy", "stage3")
        # C source -> stage3.o
        cflags = [
            "-m32", "-ffreestanding", "-fno-pie", "-fno-stack-protector",
            "-fno-builtin", "-Wall", "-Wextra", "-c",
        ]
        run([cc, *cflags, "main.c", "-o", os.path.join(BUILD_DIR, "stage3.o")], cwd=stage3_dir)

        # ASM sources -> error.o / prestg4.o / load.o
        for src in ["error.asm", "prestg4.asm", "load.asm"]:
            obj = os.path.join(BUILD_DIR, src.replace(".asm", ".o"))
            run([nasm, "-f", "elf32", src, "-o", obj], cwd=stage3_dir)

    def build_stage4(self):
        logger.info("Building in stage4")
        stage4_dir = os.path.join(BASE_DIR, "legacy", "stage4")
        run(["cargo", "build", "--release", "--target", "i686-unknown-none.json"], cwd=stage4_dir)
        lib = os.path.join(stage4_dir, "target", "i686-unknown-none", "release", "libstage4.a")
        shutil.copyfile(lib, os.path.join(BUILD_DIR, "stage4.a"))

    def build_steps(self):
        logger.info("======= BUILD LEGACY =======")
        self.build_boot()
        self.build_stage2()
        self.build_stage3()
        self.build_stage4()

    def pack(self):
        """Link pkldr.elf, emit binary, and assemble the BOOTMBR disk image."""
        logger.info("Linking legacy bootloader...")
        ld = find_tool("ld", "ld")
        link_objects = [
            os.path.join(BUILD_DIR, "load.o"),
            os.path.join(BUILD_DIR, "stage2.o"),
            os.path.join(BUILD_DIR, "stage3.o"),
            os.path.join(BUILD_DIR, "error.o"),
            os.path.join(BUILD_DIR, "prestg4.o"),
            os.path.join(BUILD_DIR, "stage4.a"),
        ]
        ldflags = [
            "-m", "elf_i386",
            "-T", "linker.ld",
            "--oformat", "elf32-i386",
            "--accept-unknown-input-arch",
        ]
        legacy_dir = os.path.join(BASE_DIR, "legacy")
        run([ld, *ldflags, *link_objects, "-o", os.path.join(BUILD_DIR, "pkldr.elf")], cwd=legacy_dir)

        objcopy = find_tool("objcopy", "objcopy")
        run([objcopy, "-O", "binary",
             os.path.join(BUILD_DIR, "pkldr.elf"),
             os.path.join(OUTPUT_DIR, "pkldr")], cwd=legacy_dir)

        # Assemble BOOTMBR: zero-filled 1MiB image + mbr.bin + stg1.bin
        logger.info("Assembling BOOTMBR...")
        bootmbr = os.path.join(OUTPUT_DIR, "BOOTMBR")
        with open(bootmbr, "wb") as out:
            out.write(b"\x00" * (1024 * 1024))
            for name in ["mbr.bin", "stg1.bin"]:
                with open(os.path.join(BUILD_DIR, name), "rb") as f:
                    out.write(f.read())
        logger.info(f"Successfully built legacy bootloader in {OUTPUT_DIR} !")

    def __init__(self):
        gen_version()
        ensure_dirs()
        self.build_steps()
        self.pack()

    def clean(self):
        logger.info("Cleaning Legacy bootloader artifacts...")
        stage4_dir = os.path.join(BASE_DIR, "legacy", "stage4")
        run(["cargo", "clean"], cwd=stage4_dir)
        shutil.rmtree(BUILD_DIR, ignore_errors=True)


class Uefi(Builder):
    def build_steps(self):
        logger.info("======= BUILD UEFI =======")
        uefi_dir = os.path.join(BASE_DIR, "uefi")
        run(["cargo", "build", "--release", "--target", "x86_64-unknown-uefi"], cwd=uefi_dir)
        efi = os.path.join(uefi_dir, "target", "x86_64-unknown-uefi", "release", "pkbl-uefi.efi")
        shutil.copyfile(efi, os.path.join(OUTPUT_DIR, os.path.basename(efi)))

    def pack(self):
        logger.info(f"Successfully built UEFI bootloader in {OUTPUT_DIR} !")

    def __init__(self):
        gen_version()
        ensure_dirs()
        self.build_steps()
        self.pack()

    def clean(self):
        logger.info("Cleaning UEFI bootloader artifacts...")
        uefi_dir = os.path.join(BASE_DIR, "uefi")
        run(["cargo", "clean"], cwd=uefi_dir)


def clean_all():
    logger.info("Cleaning up process started...")
    legacy = Legacy.__new__(Legacy)
    legacy.clean()
    uefi = Uefi.__new__(Uefi)
    uefi.clean()
    shutil.rmtree(OUTPUT_DIR, ignore_errors=True)
    shutil.rmtree(BUILD_DIR, ignore_errors=True)
    logger.info("Cleaning up process completed.")


def main():
    parser = argparse.ArgumentParser(description="Proka Bootloader build script")
    # XXX: Compat from parent builder (proka-os)
    parser.add_argument("--profile", default="release", choices=["release", "debug"])
    parser.add_argument("target", nargs="?", default="all", choices=["all", "legacy", "uefi", "clean"],
                        help="Build target: all (default), legacy, uefi, clean")
    args = parser.parse_args()

    if args.target == "all":
        Legacy()
        Uefi()
        logger.info("All platforms' bootloader file are built successfully!")
    elif args.target == "legacy":
        Legacy()
    elif args.target == "uefi":
        Uefi()
    elif args.target == "clean":
        clean_all()


if __name__ == "__main__":
    main()
