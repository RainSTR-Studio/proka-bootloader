//! This crate provides the struct, enums about the Proka
//! bootloader, including the boot information, and so on.
//! 
//! # About proka bootloader
//! Well, this bootloader is for Proka Kernel, which will obey
//! its standard. For more information, see <url>.

#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(self::test_runner)]
#![reexport_test_harness_main = "test_main"]

#[cfg(feature = "loader_main")]
pub mod loader_main;
pub mod output;
pub mod memory;
use self::output::Framebuffer;
use self::memory::MemoryMap;

/// This struct is the boot information struct, which provides
/// the basic information, *memory map*, and so on.
#[repr(C, align(4))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BootInfo {
    /// The boot mode, see the [`BootMode`] enum.
    boot_mode: BootMode,
    memmap: MemoryMap,
    framebuffer: Framebuffer,
}

impl BootInfo {
    /// Initialize a new boot info object.
    ///
    /// Note: this object will be initialized by loader
    /// automatically, so if you are a kernel developer, do
    /// not use this method, because you needn't and unusable.
    #[cfg(feature = "loader_main")]
    pub fn new(boot_mode: BootMode, memmap: MemoryMap, fb: Framebuffer) -> Self {
        Self {
            boot_mode,
            memmap,
            framebuffer: fb
        }
    }

    /// Get the boot mode.
    pub const fn boot_mode(&self) -> BootMode {
        self.boot_mode
    }

    /// Get the framebuffer info.
    pub const fn framebuffer(&self) -> Framebuffer {
        self.framebuffer
    }

    /// Get the memory map.
    pub const fn memory(&self) -> MemoryMap {
        self.memmap
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

#[cfg(test)]
fn test_runner(tests: &[&dyn Fn()]) {
    for test in tests {
        test();
    }
}