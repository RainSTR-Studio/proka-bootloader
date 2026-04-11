//! This file is the main loader for UEFI firmware.
#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(self::test_runner)]
#![reexport_test_harness_main = "test_main"]

use proka_bootloader::output::Framebuffer;
use uefi::{
    mem::memory_map::MemoryMapOwned,
    prelude::*,
    println,
    boot::{AllocateType, MemoryType},
    proto::{
        console::gop::{GraphicsOutput, PixelFormat},
        media::file::{File, FileAttribute, FileInfo, FileMode},
    },
};

// PAT constants
const IA32_PAT: u32 = 0x277; 
const PAT_UC: u64 = 0x00;
const PAT_WC: u64 = 0x01;
const PAT_WT: u64 = 0x04;
const PAT_WP: u64 = 0x05;
const PAT_WB: u64 = 0x06;
const PAT_UC_MINUS: u64 = 0x07;

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();

    // This is the main code now..
    println!("Welcome to Proka Bootloader!");
    println!("Currently you are in stage0, and booting Proka OS now :/");

    // Set up PAT
    println!("[INFO] Setting up PAT...");
    unsafe {
        let pat_value: u64 = (PAT_WB) // PAT0: Write Back
            | (PAT_WT << 8)     // PAT1: Write through
            | (PAT_UC_MINUS << 16) // PAT2: UC- 
            | (PAT_UC << 24)    // PAT3: Uncachable
            | (PAT_WB << 32)    // PAT4: Write Back
            | (PAT_WC << 40)    // PAT5: Write Combined
            | (PAT_WP << 48)    // PAT6: Write Protect
            | (0 << 56);        // Reserved
        x86_64::registers::model_specific::Msr::new(IA32_PAT).write(pat_value);
    }
    println!("[INFO] Successfully set up PAT, now reading kernel...");

    // Get current image handle
    let handle = boot::image_handle();

    // Read the kernel from FAT32 partition, and put it to 0x200000
    let kernel_path = cstr16!("\\proka-kernel");
    let mut fs = boot::get_image_file_system(handle).unwrap();
    let mut root = fs.open_volume().unwrap();
    let mut kernel = root
        .open(kernel_path, FileMode::Read, FileAttribute::empty())
        .unwrap();

    // And get the kernel size
    let infobuf: &mut [u8; 1024] = &mut [0; 1024]; // 1024 bytes for file info
    let info = kernel.get_info::<FileInfo>(infobuf).unwrap();
    let size = info.file_size() as usize;

    // Copy to the target address
    let mut buf = unsafe {
        core::slice::from_raw_parts_mut(0x200000 as *mut u8, size) // 64MB for kernel
    };
    kernel.into_regular_file().unwrap().read(&mut buf).unwrap();
    println!("[INFO] Successfully loaded kernel into 0x200000 (phys) / 0xffff800000000000 (virt).");

    // Now allocate 0x100000~0x1fffff
    boot::allocate_pages(AllocateType::Address(0x100000), MemoryType::LOADER_DATA, 256).unwrap();

    // And get GOP protocol
    println!("[INFO] Getting GOP...");
    let gop_handle = boot::get_handle_for_protocol::<GraphicsOutput>().unwrap();
    let mut gop = boot::open_protocol_exclusive::<GraphicsOutput>(gop_handle).unwrap();

    // Get the essential information
    let address = gop.frame_buffer().as_mut_ptr() as u64;
    let width: u64 = gop.current_mode_info().resolution().0 as u64;
    let height: u64 = gop.current_mode_info().resolution().1 as u64;
    let pitch: u64 = (gop.current_mode_info().stride() * 4) as u64;
    let bpp: u64 = match gop.current_mode_info().pixel_format() {
        PixelFormat::Rgb => 4,     // 32 / 8
        PixelFormat::Bgr => 4,     // 32 / 8
        PixelFormat::Bitmask => 4, // 32 / 8
        _ => 0,                    // No framebuffer
    };

    // Clear screen
    unsafe {
        let addr = address as *mut u8;
        for y in 0..height {
            for x in 0..width {
                let offset = y * pitch + x * bpp;
                addr.add(offset as usize).cast::<u32>().write(0x00000000);
            }
        }
    }

    // Merge them as a Framebuffer struct and put to a fixed address
    let fb = Framebuffer::new(address as u64, width, height, bpp, pitch);
    unsafe {
        let ptr = 0x110000 as *mut Framebuffer;
        *ptr = fb;
    }

    // Fine, then quit the uefi boot services and do some preparations.
    let memory_map = unsafe {
        core::arch::asm!("cli"); // Disable interrupts before exiting boot services
        boot::exit_boot_services(None)
    };

    // Since then, the UEFI boot services will be disabled.
    // Copy the memory map to 0x110100
    unsafe {
        let ptr = 0x110100 as *mut MemoryMapOwned;
        *ptr = memory_map;
    }

    // Jump to stage1
    pkbl_uefi::stage1_entry();
}

#[cfg(test)]
fn test_runner(tests: &[&dyn Fn()]) {
    for test in tests {
        test();
    }
}
