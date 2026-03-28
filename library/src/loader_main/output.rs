/// Mandatory information for all VBE revisions
#[repr(C, packed)]
#[derive(Debug, Clone, Copy)]
pub struct VBEInfo {
    // ==== Mandatory for all VBE revisions ====
    /// Mode attributes (linear framebuffer, color, etc.)
    pub mode_attributes: u16,
    pub win_a_attributes: u8,
    pub win_b_attributes: u8,
    pub win_granularity: u16,
    pub win_size: u16,
    pub win_a_segment: u16,
    pub win_b_segment: u16,
    pub win_func_ptr: u32,
    pub bytes_per_scan_line: u16,

    // ==== Mandatory for VBE 1.2+ ====
    /// Horizontal resolution (pixels/characters)
    pub x_resolution: u16,
    /// Vertical resolution (pixels/characters)
    pub y_resolution: u16,
    pub x_char_size: u8,
    pub y_char_size: u8,
    pub number_of_planes: u8,
    /// Bits per pixel (color depth)
    pub bits_per_pixel: u8,
    pub number_of_banks: u8,
    /// Memory model type (text, planar, linear, direct color, etc.)
    pub memory_model: u8,
    pub bank_size: u8,
    pub number_of_image_pages: u8,
    pub _reserved1: u8,

    // ==== Direct Color Fields (required for mode 6/7) ====
    pub red_mask_size: u8,
    pub red_field_position: u8,
    pub green_mask_size: u8,
    pub green_field_position: u8,
    pub blue_mask_size: u8,
    pub blue_field_position: u8,
    pub rsvd_mask_size: u8,
    pub rsvd_field_position: u8,
    pub direct_color_mode_info: u8,

    // ==== Mandatory for VBE 2.0+ ====
    /// Physical address of linear frame buffer
    pub phys_base_ptr: u32,
    pub off_screen_mem_offset: u32,
    pub off_screen_mem_size: u16,
    /// Reserved padding to full block size
    pub _reserved2: [u8; 206],
}

impl VBEInfo {
    /// Load the VBE info from a fixed address.
    pub fn load(addr: u32) -> &'static Self {
        unsafe { &*(addr as *const Self) }
    }
}
