# Proka Bootloader - The bootloader of ProkaOS

[![Rust Nightly](https://img.shields.io/badge/rust-nightly-orange?style=flat-square&logo=rust)](https://www.rust-lang.org/)
[![License: GPLv3](https://img.shields.io/badge/License-GPLv3-yellow.svg?style=flat-square)](https://opensource.org/license/gpl-3.0)
[![GitHub Stars](https://img.shields.io/github/stars/RainSTR-Studio/proka-bootloader?style=flat-square)](https://github.com/RainSTR-Studio/proka-bootloader/stargazers)
[![GitHub Issues](https://img.shields.io/github/issues/RainSTR-Studio/proka-bootloader?style=flat-square)](https://github.com/RainSTR-Studio/proka-bootloader/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/RainSTR-Studio/proka-bootloader?style=flat-square)](https://github.com/RainSTR-Studio/proka-bootloader/pulls)
[![Documentation](https://img.shields.io/badge/docs-prokadoc-brightgreen?style=flat-square)](https://prokadoc.pages.dev/)

**Copyright (C) 2026 RainSTR Studio. Licensed under GNU GPLv3.**

---

## Introduction
This is the main repository of the `proka-bootloader`, which contains the bootloader code (including BIOS and UEFI), and the library to help you parse the info easily.

This project is written in Rust, so you can use it through `cargo add proka-bootloader` and look for docs on [Docs.rs](https://docs.rs/proka-bootloader/latest/proka_bootloader/).

## How to use
Here, we'd like to introduce the usage of this bootloader.

### Build the bootloader code
To build the bootloader, you shall install these components:

 - NASM: For the bootloader code written in assembly;
 - GCC: For the bootloader code written in C;
 - Nightly Rust: For the bootloader code written in Rust;
 - Make: To build the code

For nightly Rust, you should install these components and targets:

 - `rust-src`: To rebuild the core crate;
 - `x86_64-unknown-none`: To generate the bare code;
 - `x86_64-unknown-uefi`: To generate UEFI code;

Here's the example command that helps you install them:

```bash
# Debian/Ubuntu
sudo apt install gcc nasm make

# Arch Linux
sudo pacman -Sy gcc make nasm

# After installing rustup...
rustup component install rust-src
rustup target add x86_64-unknown-none x86_64-unknown-uefi
```

After installing these, go to the project root, run:

```bash
# If you want to build both BIOS and UEFI...
make

# If build BIOS only...
make legacy

# If build UEFI only...
make uefi
```

The assets will put in `output/` in project root.

**NOTE**: The file `pkldr` is the stage2/3/4 file and MUST put into root; The partition must be FAT32 and with type `0x91`!

If you want to install it to your disk, follow this file structures:

```
/mnt/
├── EFI
│   └── Boot
│       └── bootx64.efi
├── initprt.img
├── NvVars
├── pkldr
└── proka-kernel
```

### Use this as a crate
1. Do this command in your project root:

`cargo add proka-bootloader`

2. Write the following example code:

```rust
#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(self::test_runner)]
#![reexport_test_harness_main = "test_main"]

use proka_bootloader::BootInfo;
use core::panic::PanicInfo;

// Panic handler
#[panic_handler]
pub fn panic(_: &PanicInfo) -> ! {
    loop {}
}


#[unsafe(no_mangle)]
#[unsafe(link_section = ".text")]
pub extern "C" fn kernel_main() -> ! {
    let info = proka_bootloader::get_bootinfo();
    let framebuffer = info.framebuffer();
    unsafe {
        let ptr = framebuffer.address() as *mut u8;
        for i in 0..500 {
            let offset = framebuffer.pitch() * i + i * framebuffer.bpp();
            ptr.add(offset as usize).cast::<u32>().write(0x00FFFFFF);
        }
    }
    loop {}
}

// Test runner 
#[cfg(test)]
fn test_runner(tests: &[&'static dyn Fn()]) {
    for test in tests {
        test();
    }
}
```

3. Build your project

Run this command: `cargo build --target x86_64-unknown-none`

## Contributing
Thank you to all contributors!

 - **zhangxuan2011** <zx20110412@outlook.com>

### How to contribute
We welcome your contributions: Bug reports, Pull Requests (features, fixes, optimizations), documentation improvements, and feedback.

Also don't forget to add your name to [**Contributors List**](#contributors)! :)

# License
This project is under license [**GPL-v3**](LICENSE), and you should follow this license during contributing.

See [LICENSE](LICENSE) for more details.
