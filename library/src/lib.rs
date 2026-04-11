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
#[repr(C, packed)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BootInfo {
    /// The boot mode, see the [`BootMode`] enum.
    boot_mode: BootMode,
    framebuffer: Framebuffer,
    memmap: MemoryMap,
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

/// Get the bootinfo.
///
/// The BootInfo is pre-copied & fixed at the dedicated constant physical address
/// 0x100000 by UEFI boot stage, never modified nor released in kernel lifetime.
///
/// # Safety
/// Caller must ensure **before invoking**:
/// 1. Address `0x100000` is allocated & filled with valid initialized BootInfo;
/// 2. This range is reserved, never overwritten/freed by kernel/UEFI;
/// 3. No mutable aliasing exists for this memory region.
///
/// These steps are already guaranteed by the bootloader, so invocation is generally safe
/// in normal kernel runtime.
///
/// # Returns
/// - &'static BootInfo: immutable static reference to the pre-filled BootInfo
pub const fn get_bootinfo() -> &'static BootInfo {
    const BI_PHYS: u64 = 0x100000;
    unsafe { &*(BI_PHYS as *const BootInfo) }
}

#[cfg(test)]
fn test_runner(tests: &[&dyn Fn()]) {
    for test in tests {
        test();
    }
}
