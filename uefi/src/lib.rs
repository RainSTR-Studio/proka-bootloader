//! The UEFI public library.
#![no_std]
#![no_main]

use core::panic::PanicInfo;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}

/// The stage1 entry
pub fn stage1_entry() -> ! {
    // Once you entered the stage
    loop {}
}