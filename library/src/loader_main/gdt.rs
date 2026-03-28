//! The GDT definition.

/// The GDT pointer
#[repr(C, packed)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct GdtPtr {
    /// GDT size - 1
    pub limit: u16,
    /// Linear address of GDT
    pub base: u64,
}
