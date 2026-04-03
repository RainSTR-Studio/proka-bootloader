//! This module is the loader entry, which is used for
//! Proka Bootloader only
//!
//! So if you are using this crate by kernel, do not
//! enable this feature and trying importing this module.

mod memory;
mod output;
mod gdt;
use self::memory::E820Map;
use self::output::VBEInfo;
use self::gdt::GdtPtr;
use core::arch::asm;
use crate::memory::{MemoryEntry, MemoryMap, MemoryType};
use crate::output::Framebuffer;
use crate::{BootMode, BootInfo};
use uefi::mem::memory_map::MemoryMapOwned;

/// The GDT structures.
#[used]
static GDT: [u64; 3] = [
    // Empty entry
    0,
    // The code segment
    (1<<43) | (1<<44) | (1<<47) | (1<<53) | (0<<22),
    // The data segment
    (1<<44) | (1<<47) | (1<<41) | (1<<53) | (1<<55)
];

/// The GDT pointer.
#[used]
static mut GDT_PTR: GdtPtr = GdtPtr {
    limit: 25,
    base: 0     // Will change in runtime
};

/// This function is the generic main entry of the whole
/// bootloader, which will intergrate all infomation that
/// kernel needed, and jump to kernel finally.
///
/// You need to pass one argument, which references to
/// the boot mode, only Legacy and Uefi are legal
pub fn loader_main(bootmode: BootMode) -> ! {
    // Get the essential information for kernel
    let framebuffer = get_framebuffer();
    let memory_map = get_memory_map();

    // Intergrate them into a BootInfo struct
    let boot_info = BootInfo::new(bootmode, memory_map, framebuffer);

    let kernel_start: u32 = 0;

    // Jump to kernel
    unsafe {
        // Update GDT_PTR
        GDT_PTR.base = GDT.as_ptr() as u64;
        asm!(
            "lgdt [{0}]",
            in(reg) &raw const GDT_PTR,
            options(nomem, nostack)
        );
        asm!(
            "and esp, 0xFFFFFF00",
            in("eax") &boot_info
        );
        asm!(
            "push eax",
            "push 0xffff8000",
            "push {entry:e}",
            entry = in(reg) kernel_start
        );
        asm!(
            "ljmp $0x8, $2f", "2:",
            options(att_syntax)
        );
        asm!(
            ".code64",

            // Refresh segment registers
            "mov {0}, 0x10",
            "mov ds, {0}",
            "mov es, {0}",
            "mov ss, {0}",
            "mov fs, {0}",
            "mov gs, {0}",

            // Set up the last work
            "pop rax",
            "pop rdi",

            // Finally, the work are fully completed.
            //
            // The bootloader's mission has done, and
            // the next step is for kernel.
            //
            // Anyway, see you in my kernel :)
            "jmp rax",

            out(reg) _,
            out("rax") _,
            out("rdi") _,
        );
    }

    loop {}
}

#[cfg(target_os = "none")]
fn get_framebuffer() -> Framebuffer {
    // Init the VBE info
    let vbe = VBEInfo::load(0x10000); // Put in fixed address in stage2
    let fb_addr: *mut u8 = 0xffff800040000000u64 as *mut u8; // Mapped
    let width: u64 = vbe.x_resolution.into();
    let height: u64 = vbe.y_resolution.into();
    let bpp: u64 = (vbe.bits_per_pixel / 8).into();
    let pitch: u64 = vbe.bytes_per_scan_line.into();

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
        }; 128],
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

#[cfg(target_os = "uefi")]
fn get_memory_map() -> MemoryMap {
    // Get the uefi memory map first
    let memory_map_uefi = unsafe { &*(0x10100 as *const MemoryMapOwned) };

    // And convert it to our MemoryMap struct
    let mut memory_map = MemoryMap {
        count: 0,
        entries: [MemoryEntry {
            base_addr: 0,
            length: 0,
            mem_type: MemoryType::Reserved,
        }; 128],
    };
    memory_map.clone()
}

#[cfg(target_os = "uefi")]
fn get_framebuffer() -> Framebuffer {
    // Load framebuffer info from the standard location
    let fb_info = unsafe { &*(0x10000 as *const Framebuffer) };
    fb_info.clone()
}
