//! This file is the main loader for UEFI firmware.
#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(self::test_runner)]
#![reexport_test_harness_main = "test_main"]

use proka_bootloader::output::Framebuffer;
use uefi::{
    boot::{AllocateType, MemoryType},
    mem::memory_map::MemoryMapOwned,
    prelude::*,
    println,
    proto::{
        console::gop::{GraphicsOutput, PixelFormat},
        media::file::{File, FileAttribute, FileInfo, FileMode},
    },
};

const DATA_START_ADDR: u64 = 0x10000;
const DATA_PAGE: usize = 144; // 0x10000 ~ 0x90000

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();

    // TODO: Add main code here..
    println!("Welcome to Proka Bootloader!");
    println!("Currently you are in stage0, and booting Proka OS now :/");

    // Get current image handle
    let handle = boot::image_handle();

    // And get some protocol
    let gop_handle = boot::get_handle_for_protocol::<GraphicsOutput>().unwrap();
    let mut gop = boot::open_protocol_exclusive::<GraphicsOutput>(gop_handle).unwrap();

    // Get the essential information
    let address = gop.frame_buffer().as_mut_ptr();
    let width: u64 = gop.current_mode_info().resolution().0 as u64;
    let height: u64 = gop.current_mode_info().resolution().1 as u64;
    let pitch: u64 = gop.current_mode_info().stride() as u64;
    let bpp: u64 = match gop.current_mode_info().pixel_format() {
        PixelFormat::Rgb => 32,
        PixelFormat::Bgr => 32,
        PixelFormat::Bitmask => 32,
        _ => 0, // No framebuffer
    };

    // Clear screen
    unsafe {
        for y in 0..height {
            for x in 0..width {
                let offset = y * pitch + x;
                address.add(offset as usize).cast::<u32>().write_volatile(0x00000000);
            }
        }
    }

    // Allocate the page for the data address
    boot::allocate_pages(
        AllocateType::Address(DATA_START_ADDR),
        MemoryType::LOADER_DATA,
        DATA_PAGE,
    )
    .unwrap();

    // Merge them as a Framebuffer struct and put to a fixed address
    let fb = Framebuffer::new(address, width, height, bpp, pitch);
    unsafe {
        let ptr = 0x10000 as *mut Framebuffer;
        *ptr = fb;
    }

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

    // Allocate the page for the kernel
    boot::allocate_pages(
        AllocateType::Address(0x200000),
        MemoryType::LOADER_DATA,
        size / 4096, // size pages
    )
    .unwrap();

    // Copy to the target address
    let mut buf = unsafe {
        core::slice::from_raw_parts_mut(0x200000 as *mut u8, size) // 64MB for kernel
    };
    kernel.into_regular_file().unwrap().read(&mut buf).unwrap();

    // Fine, then quit the uefi boot services and do some preparations.
    let memtype = Some(MemoryType::CONVENTIONAL);
    let memory_map = unsafe {
        core::arch::asm!("cli"); // Disable interrupts before exiting boot services
        boot::exit_boot_services(memtype)
    };

    // Since then, the UEFI boot services will be disabled.
    // Copy the memory map to 0x10100
    unsafe {
        let ptr = 0x10100 as *mut MemoryMapOwned;
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