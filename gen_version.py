#!/usr/bin/env python3
import os

os.makedirs("build", exist_ok=True)

with open("version", "r", encoding="utf-8") as f:
    ver_str = f.read().strip()

ma, mi, pa = map(int, ver_str.split("."))

# C
with open("build/version.h", "w") as f:
    f.write(f"""
#ifndef PROKA_VERSION_H
#define PROKA_VERSION_H

#define PROKA_VERSION_MAJ {ma}
#define PROKA_VERSION_MIN {mi}
#define PROKA_VERSION_PAT {pa}
#define PROKA_VERSION {{ {ma}, {mi}, {pa} }}

#endif
""")

# ASM
with open("build/version.inc", "w") as f:
    f.write(f"""
%define PROKA_VERSION_MAJ {ma}
%define PROKA_VERSION_MIN {mi}
%define PROKA_VERSION_PAT {pa}
PROKA_VERSION dw {ma}, {mi}, {pa}
""")

# Rust
with open("library/src/version.rs", "w") as f:
    f.write(f"""
pub const VERSION: [u16; 3] = [{ma}, {mi}, {pa}];
""")

with open("build/version.rs", "w") as f:
    f.write(f"""
pub const VERSION: [u16; 3] = [{ma}, {mi}, {pa}]; 
""")

print(f"[INFO] Version {ma}.{mi}.{pa} → build/")
