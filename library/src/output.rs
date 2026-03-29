//! The output module, which provides framebuffer info and
//! its utilities.

/// The framebuffer structure, which provides basic 5
/// elements:
///
/// - Framebuffer base address;
/// - Framebuffer height;
/// - Framebuffer width;
/// - Framebuffer BPB
/// - Framebuffer pitch
///
/// You can use it to do output/graphics operations.
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[cfg_attr(feature = "default", derive(Default))]
pub struct Framebuffer {
    fb_addr: u64,
    width: u32,
    height: u32,
    bpp: u8,
    pitch: u16,
}

impl Framebuffer {
    /// Creates a nee framebuffer object.
    ///
    /// Note: This method will automatically create by
    /// bootloader entry, if you are using kernel, this
    /// method is not needed and not usable.
    #[cfg(feature = "loader_main")]
    pub fn new(addr: u64, width: u32, height: u32, bpp: u8, pitch: u16) -> Self {
        Self {
            fb_addr: addr,
            width,
            height,
            bpp,
            pitch,
        }
    }

    /// Get the framebuffer address.
    pub fn address(&self) -> u64 {
        self.fb_addr
    }

    /// Get the framebuffer width.
    pub fn width(&self) -> u32 {
        self.width
    }

    /// Get the framebuffer height.
    pub fn height(&self) -> u32 {
        self.height
    }

    /// Get the framebuffer BPP.
    pub fn bpp(&self) -> u8 {
        self.bpp
    }

    /// Get the framebuffer pitch.
    pub fn pitch(&self) -> u16 {
        self.pitch
    }
}
