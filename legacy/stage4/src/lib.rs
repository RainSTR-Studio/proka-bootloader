//! Proka Bootloader - The bootloader for Proka OS
//! Copyright (C) RainSTR Studio 2026, All Rights Reserved.
//!
//! This file is the transition of stage4, which will let 
//! you transition to the generic bootloader entry.

#![no_std]
#![no_main]

use proka_bootloader::loader_main::loader_main;
use proka_bootloader::BootMode;

// Panic handler
use core::panic::PanicInfo;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}

#[unsafe(no_mangle)]
pub fn stage4_entry() -> ! {
    // From here, you are in Rust code.
    //
    // The loader_main needs an arg, which shows the 
    // boot mode, see also proka_bootloader::BootMode.
    loader_main(BootMode::Legacy)
}
