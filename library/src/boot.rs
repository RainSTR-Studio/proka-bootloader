//! This module provides the boot information.

/// This struct is the boot information struct, which provides
/// the basic information, *memory map*, and so on.
#[repr(C, align(4))]
#[derive(Debug, Clone, Copy)]
pub struct BootInfo {
    /// The boot mode, see the [`BootMode`] enum.
    boot_mode: BootMode,
}

impl BootInfo {
    /// Initialize a new boot info object.
    pub fn new(boot_mode: BootMode) -> Self {
        Self { boot_mode }
    }

    /// Put the boot information to a fixed address
    ///
    /// # Safety
    /// This is unsafe because we need to operate the pointer.
    ///
    /// This function is for loader only.
    pub unsafe fn put_addr(self, address: u64) {
        let pointer = address as *mut BootInfo;
        unsafe {
            pointer.write_volatile(self);
        }
    }

    /// Load the boot infomation from an address.
    ///
    /// # Safety
    /// This is unsafe because we need to read from a pointer.
    pub unsafe fn load(address: u64) -> Self {
        let pointer = address as *const BootInfo;
        unsafe {
            pointer.read_volatile()
        }
    }

    /// Get the boot mode.
    pub const fn boot_mode(&self) -> &BootMode {
        &self.boot_mode
    }
}

/// This is the boot mode, only support 2 modes, which are legacy(BIOS) and UEFI.
#[derive(Debug, Clone, Copy)]
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
