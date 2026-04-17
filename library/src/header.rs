//! The definition of proka-kernel header.
//!
//! This module will help you to create a header, and
//! all you need to do is put it into the head of the kernel
//! file.

#[repr(C, packed)]
#[derive(Debug, Clone, Copy)]
pub(crate) struct Header {
    /// The magic number of this header
    pub magic: u32,

    /// The version of this kernel.
    ///
    /// # Structures of this field
    /// To create this version, this must obey this rule:
    ///
    /// - For bit 0~2, that's the first version number;
    /// - For bit 3~4, that's the second version number;
    /// - And bit 5~6, it's the last version number.
    ///
    /// This field has 3 u16 values, so the version
    /// format shall like this: `X.Y.Z`
    ///
    /// # Example
    /// - `0.3.1` => `0x0000_0003_0001 [0, 3, 1]`;
    /// - `1.0.3` => `0x0001_0000_0003 [1, 0, 3]`;
    /// - `0.1.218` => 0x0000_0001_026a [0, 1, 218].
    pub version: [u16; 3],

    /// The kernel start address.
    pub kernel_entry: u64,

    /// The length of this kernel (Byte).
    pub length: u64,

    /// Reserved bits
    pub _reserved: [u8; 6],
}

impl Default for Header {
    fn default() -> Self {
        Self {
            magic: 0x504b4e4c,  // PKNL
            version: [0, 3, 2],
            kernel_entry: 0,
            length: 0,
            _reserved: [0u8; 6],
        }
    }
}