//! This module is the loader entry, which is used for
//! Proka Bootloader only
//!
//! So if you are using this crate by kernel, do not
//! enable this feature and trying importing this module.

mod gdt;
#[cfg(target_os = "none")]
mod memory;
#[cfg(target_os = "none")]
mod output;


use self::gdt::GdtPtr;
use crate::memory::{MemoryEntry, MemoryMap, MemoryType};
use crate::output::Framebuffer;
use crate::{BootInfo, BootMode};
use core::arch::asm;

// OS specific imports
#[cfg(target_os = "none")]
use {self::memory::E820Map, self::output::VBEInfo};

#[cfg(target_os = "uefi")]
use {
    uefi::boot::MemoryType as UefiMemoryType,
    uefi::mem::memory_map::{MemoryMap as UefiMemoryMap, MemoryMapOwned},
};

/// The GDT structures.
#[used]
static GDT: [u64; 3] = [
    // Empty entry
    0,
    // The code segment
    (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53) | (0 << 22),
    // The data segment
    (1 << 44) | (1 << 47) | (1 << 41) | (1 << 53) | (1 << 55),
];

/// The GDT pointer.
#[used]
static mut GDT_PTR: GdtPtr = GdtPtr {
    limit: 25,
    base: 0, // Will change in runtime
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

    // Jump to kernel (BIOS boot only)
    #[cfg(target_os = "none")]
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
            in("ecx") &boot_info
        );
        asm!(
            "push ecx",
            "push 0xffff8000",
            "push {entry:e}",
            entry = in(reg) kernel_start
        );
        asm!("ljmp $0x8, $2f", "2:", options(att_syntax));
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

    #[cfg(target_os = "uefi")]
    unsafe {
        // Because the UEFI is 64-bit, so we can directly jump to kernel without setting up GDT and segment registers.
        // Just jump to the kernel entry point, and pass the boot info as argument in rax
        asm!(
            "mov rax, 0xffff800000000000",
            "add rax, rsi",
            in("rdi") &boot_info,
            in("rsi") kernel_start,
            options(nomem, nostack)
        );
        asm!("jmp rax");
    }

    loop {}
}

#[cfg(target_os = "none")]
fn get_framebuffer() -> Framebuffer {
    // Init the VBE info
    let vbe = VBEInfo::load(0x10000); // Put in fixed address in stage2
    let fb_addr: u64 = 0xffff800040000000u64; // Mapped
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

    // Init basic struct
    let mut memory_map = MemoryMap {
        count: 0,
        entries: [MemoryEntry {
            base_addr: 0,
            length: 0,
            mem_type: MemoryType::Reserved,
        }; 128],
    };

    // And convert it to our MemoryMap struct
    let entries = memory_map_uefi.entries();
    for entry in entries {
        // Convert uefi memory type to our memory type (will more implement later)
        let mem_type = match entry.ty {
            UefiMemoryType::CONVENTIONAL |
            UefiMemoryType::LOADER_CODE  | 
            UefiMemoryType::LOADER_DATA => MemoryType::FreeRAM,
            UefiMemoryType::RESERVED => MemoryType::Reserved,
            UefiMemoryType::MMIO => MemoryType::Reserved,
            UefiMemoryType::ACPI_RECLAIM => MemoryType::AcpiReclaim,
            UefiMemoryType::ACPI_NON_VOLATILE => MemoryType::AcpiNvs,
            UefiMemoryType::BOOT_SERVICES_CODE | 
            UefiMemoryType::BOOT_SERVICES_DATA => MemoryType::FreeRAM,  // UEFI crate said it's free RAM in OS
            _ => MemoryType::BadMemory, // Treat other types as bad memory
        };

        if memory_map.count < 128 {
            memory_map.entries[memory_map.count as usize] = MemoryEntry {
                base_addr: entry.phys_start,
                length: entry.page_count * 4096,
                mem_type,
            };
            if !matches!(mem_type, MemoryType::BadMemory) {
                memory_map.count += 1;
            }
        }
    }

    memory_map.clone()
}

#[cfg(target_os = "uefi")]
fn get_framebuffer() -> Framebuffer {
    // Load framebuffer info from the standard location
    let fb_info = unsafe { &*(0x10000 as *const Framebuffer) };

    // Rebuild the framebuffer struct
    let addr = 0xffff800040000000u64; // Mapped
    let width = fb_info.width();
    let height = fb_info.height();
    let bpp = fb_info.bpp();
    let pitch = fb_info.pitch();
    
    let fb = Framebuffer::new(addr, width, height, bpp, pitch);
    fb
}
