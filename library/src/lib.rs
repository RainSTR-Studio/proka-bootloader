//! # Proka Bootloader - The bootloader of ProkaOS
//!
//! [![Rust Nightly](https://img.shields.io/badge/rust-nightly-orange?style=flat-square&logo=rust)](https://www.rust-lang.org/)
//! [![License: GPLv3](https://img.shields.io/badge/License-GPLv3-yellow.svg?style=flat-square)](https://opensource.org/license/gpl-3.0)
//! [![GitHub Stars](https://img.shields.io/github/stars/RainSTR-Studio/proka-bootloader?style=flat-square)](https://github.com/RainSTR-Studio/proka-bootloader/stargazers)
//! [![GitHub Issues](https://img.shields.io/github/issues/RainSTR-Studio/proka-bootloader?style=flat-square)](https://github.com/RainSTR-Studio/proka-bootloader/issues)
//! [![GitHub Pull Requests](https://img.shields.io/github/issues-pr/RainSTR-Studio/proka-bootloader?style=flat-square)](https://github.com/RainSTR-Studio/proka-bootloader/pulls)
//! [![Documentation](https://img.shields.io/badge/docs-prokadoc-brightgreen?style=flat-square)](https://prokadoc.pages.dev/)
//!
//!**Copyright (C) 2026 RainSTR Studio. All rights reserved.**
//!
//!---
//!
//! ## Introduction
//! This crate provides the struct, enums about the Proka
//! bootloader, including the boot information, and so on.
//!
//! # Example
//! Here's an example to use this crateb
//!
//! ```rust
//! #![no_std]
//! #![no_main]
//! #![feature(custom_test_frameworks)]
//! #![test_runner(self::test_runner)]
//! #![reexport_test_harness_main = "test_main"]
//! 
//! use proka_bootloader::BootInfo;
//! use core::panic::PanicInfo;
//! 
//! // Panic handler
//! #[panic_handler]
//! pub fn panic(_: &PanicInfo) -> ! {
//!     loop {}
//! }
//! 
//! #[unsafe(no_mangle)]
//! #[unsafe(link_section = ".text")]
//! pub extern "C" fn kernel_main() -> ! {
//!     let info = proka_bootloader::get_bootinfo();
//!     let framebuffer = info.framebuffer();
//!     unsafe {
//!         let ptr = framebuffer.address() as *mut u8;     
//!         for i in 0..500 {   
//!             let offset = framebuffer.pitch() * i + i * framebuffer.bpp();
//!             ptr.add(offset as usize).cast::<u32>().write(0x00FFFFFF);
//!         }
//!     }
//!     loop {}
//! }
//! 
//! // Test runner
//! #[cfg(test)]
//! fn test_runner(tests: &[&'static dyn Fn()]) {
//!     for test in tests {
//!         test();
//!     }
//! }
//! ```
//!
//! //! # LICENSE
//! This crate is under license [GPL-v3](https://github.com/RainSTR-Studio/proka-exec/blob/main/LICENSE),
//! and you must follow its rules.
//!
//! See [LICENSE](https://github.com/RainSTR-Studio/proka-exec/blob/main/LICENSE) file for more details.
//!
//! ## MSRV
//! This crate's MSRV is `1.85.0` stable.
#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(self::test_runner)]
#![reexport_test_harness_main = "test_main"]

pub mod header;
#[cfg(feature = "loader_main")]
pub mod loader_main;
pub mod memory;
pub mod output;
mod version;
use self::memory::MemoryMap;
use self::output::Framebuffer;

/// This struct is the boot information struct, which provides
/// the basic information, *memory map*, and so on.
#[repr(C)]
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BootInfo {
    boot_mode: BootMode,
    framebuffer: Framebuffer,
    memmap: MemoryMap,
    acpi_addr: u64,
}

impl BootInfo {
    /// Initialize a new boot info object.
    ///
    /// Note: this object will be initialized by loader
    /// automatically, so if you are a kernel developer, do
    /// not use this method, because you needn't and unusable.
    #[cfg(feature = "loader_main")]
    pub fn new(boot_mode: BootMode, memmap: MemoryMap, fb: Framebuffer, acpi_addr: u64) -> Self {
        Self {
            boot_mode,
            acpi_addr,
            memmap,
            framebuffer: fb,
        }
    }

    /// Get the boot mode.
    pub const fn boot_mode(&self) -> &BootMode {
        &self.boot_mode
    }

    /// Get the framebuffer info.
    pub const fn framebuffer(&self) -> &Framebuffer {
        &self.framebuffer
    }

    /// Get the memory map.
    pub const fn memory(&self) -> &MemoryMap {
        &self.memmap
    }

    /// Get the ACPI RSDP's address.
    pub const fn acpi(&self) -> u64 {
        self.acpi_addr
    }
}

/// This is the boot mode, only support 2 modes, which are legacy(BIOS) and UEFI.
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BootMode {
    /// The Legacy boot mode, also called BIOS boot mode.
    ///
    /// This mode is for older machine, and we needs implement
    /// lots of things in it.
    Legacy,

    /// The UEFI boot mode, which is the newer mode. Lots of
    /// new machines uses it.
    ///
    /// Also, some machine only support it (such as mine awa).
    Uefi,
}

/// Get the bootinfo.
///
/// The BootInfo is pre-copied & fixed at the dedicated constant physical address
/// 0x10000 by UEFI boot stage, never modified nor released in kernel lifetime.
///
/// # Safety
/// Caller must ensure **before invoking**:
/// 1. Address `0x10000` is allocated & filled with valid initialized BootInfo;
/// 2. This range is reserved, never overwritten/freed by kernel/UEFI;
/// 3. No mutable aliasing exists for this memory region.
///
/// These steps are already guaranteed by the bootloader, so invocation is generally safe
/// in normal kernel runtime.
///
/// # Returns
/// - `&'static BootInfo`: immutable static reference to the pre-filled BootInfo
pub const fn get_bootinfo() -> &'static BootInfo {
    const BI_PHYS: u64 = 0x10000;
    unsafe { &*(BI_PHYS as *const BootInfo) }
}

#[cfg(test)]
fn test_runner(tests: &[&dyn Fn()]) {
    for test in tests {
        test();
    }
}
