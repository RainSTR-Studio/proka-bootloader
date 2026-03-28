//! The memory part of loader init.

/// The E820 memory map, which is provided by BIOS.
#[repr(C, packed)]
#[derive(Debug, Copy, Clone)]
pub struct E820Entry {
    pub addr: u64,
    pub size: u64,
    pub type_: u32,
    pub acpi: u32,
}

/// Max entries of E820 map.
pub const E820_MAX_ENTRIES: usize = 128;

/// The E820 Memory Map.
#[repr(C, packed)]
pub struct E820Map {
    pub entries: [E820Entry; E820_MAX_ENTRIES],
}

impl E820Map {
    pub fn load(addr: usize) -> &'static E820Map {
        unsafe { &*(addr as *const E820Map) }
    }
}
