//! This file is the main loader for UEFI firmware.
#![no_std]
#![no_main]

use proka_bootloader::output::Framebuffer;
use uefi::{
    boot::MemoryType,
    mem::memory_map::MemoryMapOwned,
    prelude::*,
    println,
    proto::{
        console::gop::{GraphicsOutput, PixelFormat},
        media::file::{File, FileAttribute, FileInfo, FileMode},
    },
};

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();

    // TODO: Add main code here..
    println!("Welcome to Proka Bootloader!");
    println!("Currently you are in stage0, and getting framebuffer now :/");

    // Get current handle
    let handle = boot::image_handle();

    // And get some protocol
    let mut gop = boot::open_protocol_exclusive::<GraphicsOutput>(handle).unwrap();

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

    // Merge them as a Framebuffer struct and put to a fixed address
    let fb = Framebuffer::new(address, width, height, bpp, pitch);
    unsafe {
        let ptr = 0x10000 as *mut Framebuffer;
        *ptr = fb;
    }
    println!("Got framebuffer info and put it to 0x10000");

    // Read the kernel from FAT32 partition, and put it to 0x200000
    println!("Reading kernel from FAT32...");
    let kernel_path = cstr16!("\\proka-kernel");
    let mut fs = boot::get_image_file_system(handle).unwrap();
    let mut root = fs.open_volume().unwrap();
    let mut kernel = root.open(kernel_path, FileMode::Read, FileAttribute::empty()).unwrap();
    
    // Copy to the target address
    let buf = unsafe {
        let infobuf: &mut [u8] = &mut [0]; // 64MB for kernel
        let info = kernel.get_info::<FileInfo>(infobuf).unwrap();
        let size = info.file_size() as usize;
        core::slice::from_raw_parts_mut(0x200000 as *mut u8, size + 1) // 64MB for kernel
    };
    println!("Read kernel completed");

    // Fine, then quit the uefi boot services and do some preparations.
    println!("Exit boot services, goodbye UEFI :) !");
    let memtype = Some(MemoryType::CONVENTIONAL);
    let memory_map = unsafe {
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

    Status::SUCCESS
}
