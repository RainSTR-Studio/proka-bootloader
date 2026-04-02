//! This file is the main loader for UEFI firmware.
#![no_std]
#![no_main]

use uefi::{mem::memory_map::MemoryMapOwned, prelude::*, proto::console::gop::GraphicsOutput};

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();

    // TODO: Add main code here..
    // Get current handle
    let handle = boot::image_handle();

    // And get some protocol
    let mut gop = boot::open_protocol_exclusive::<GraphicsOutput>(handle).unwrap();

    // Get the essential information
    let address = gop.frame_buffer().as_mut_ptr();
    let width: u64 = gop.current_mode_info().resolution().0 as u64;
    let height: u64 = gop.current_mode_info().resolution().1 as u64;
    let pitch: u64 = gop.current_mode_info().stride() as u64;
    let bpp: u64 = gop.frame_buffer().size() as u64;

    Status::SUCCESS
}
