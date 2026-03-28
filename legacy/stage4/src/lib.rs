//! Proka Bootloader - The bootloader for Proka OS
//! Copyright (C) RainSTR Studio 2026, All Rights Reserved.
//!
//! This file is the transition of stage4, which will let 
//! you transition to the generic bootloader entry.

#![no_std]
#![no_main]

use proka_bootloader::loader_main::loader_main;

#[unsafe(no_mangle)]
pub fn stage4_entry() -> ! {
    // From here, you are in Rust code.
    //
    // The loader_main needs an arg, which shows the 
    // boot mode, 0 = Legacy, 1 = UEFI
    loader_main(0)
}
