//! This module is the loader entry, which is used for
//! Proka Bootloader only
//!
//! So if you are using this crate by kernel, do not
//! enable this feature and trying importing this module.

mod memory;
mod output;
use self::memory::E820Map;
use self::output::VBEInfo;
use crate::memory::{MemoryEntry, MemoryMap, MemoryType};
use crate::output::Framebuffer;

/// This function is the generic main entry of the whole
/// bootloader, which will intergrate all infomation that
/// kernel needed, and jump to kernel finally.
///
/// You need to pass one argument, which references to
/// the boot mode, only 0 and 1 are legal
///
/// About this, 0 = Legacy mode, 1 = UEFI mode.
pub fn loader_main(bootmode: u8) -> ! {
    // Announce the global variable in this func.
    let framebuffer = get_framebuffer();
    let memory_map = get_memory_map();

    unsafe {
        let ptr = 0x100000 as *mut MemoryMap;
        *ptr = memory_map;
    }

    loop {}
}

#[cfg(target_os = "none")]
fn get_framebuffer() -> Framebuffer {
    // Init the VBE info
    let vbe = VBEInfo::load(0x10000); // Put in fixed address in stage2
    let fb_addr: u64 = 0xffff800040000000; // Mapped
    let width: u32 = vbe.x_resolution.into();
    let height: u32 = vbe.y_resolution.into();
    let bpp = vbe.bits_per_pixel;
    let pitch = vbe.bytes_per_scan_line;

    // Init the framebuffer struct
    let fb = Framebuffer::new(fb_addr, width, height, bpp, pitch);
    fb
}

#[cfg(target_os = "none")]
fn get_memory_map() -> MemoryMap {
    // Load E820 map from the standard location
    // The E820 map is typically stored at address 0x1000 by the bootloader
    let e820_map = E820Map::load(0x10100);

    let mut memory_map = MemoryMap {
        count: 0,
        entries: [MemoryEntry {
            base_addr: 0,
            length: 0,
            mem_type: MemoryType::Reserved,
        }; 256],
    };

    // Get valid entries as slice
    let entries = e820_map.entries.as_slice();
    let entry_count = entries.len().min(128);
    let mut bad_count: u32 = 0;

    // Convert each e820 entry to MemoryEntry
    for i in 0..entry_count {
        let e820_entry = &entries[i];

        // Convert e820 type to MemoryType
        // e820 standard type values:
        // 1 = RAM (usable memory)
        // 2 = Reserved
        // 3 = ACPI reclaimable memory
        // 4 = ACPI NVS memory
        let mem_type = match e820_entry.type_ {
            1 => MemoryType::FreeRAM,
            2 => MemoryType::Reserved,
            3 => MemoryType::AcpiReclaim,
            4 => MemoryType::AcpiNvs,
            // Other types (e.g., 5 = Unusable) are treated as bad memory
            _ => MemoryType::BadMemory,
        };

        if mem_type == MemoryType::BadMemory {
            bad_count += 1;
        }
        memory_map.entries[i] = MemoryEntry {
            base_addr: e820_entry.addr,
            length: e820_entry.size,
            mem_type,
        };
    }

    memory_map.count = (entry_count as u32) - bad_count;
    memory_map
}
