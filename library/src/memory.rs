//! The generic memory module, which provides memory info to
//! kernel, so that kernel can know the memory structure 
//! easily.

/// The generic Memory Map, which can contains 128 memory map
/// entries.
#[repr(C, packed)]
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MemoryMap {
    /// Available counts
    pub count: u32,

    /// Total entries
    pub entries: [MemoryEntry; 128],
}

/// The memory entry.
#[repr(C, packed)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MemoryEntry {
    /// The memory region start address
    pub base_addr: u64,

    /// The memory region length
    pub length: u64,

    /// The type of this memory region
    pub mem_type: MemoryType
}

/// The memory type.
#[repr(u8)]
#[derive(Debug, Clone, Copy, Eq, PartialEq)]
pub enum MemoryType {
    FreeRAM = 1,
    Reserved = 2,
    AcpiReclaim = 3,
    AcpiNvs = 4,
    BadMemory = 5,
    Mmio = 6,
}
