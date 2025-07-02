//! This module is for screen's input and output.

use crate::boot::*;
use uefi::helpers::_print as uefi_print;

#[macro_export]
macro_rules! print {
    ($($arg:tt)*) => ($crate::_print(core::format_args!($($arg)*)));
}

#[macro_export]
macro_rules! println {
    () => ($crate::print!("\n"));
    ($($arg:tt)*) => ($crate::io::_print(core::format_args!("{}{}", core::format_args!($($arg)*), "\n")));
}

pub fn _print(args: core::fmt::Arguments) {
    // Load the boot information struct
    let boot_info = unsafe { BootInfo::load(0x1000) };
    if *boot_info.boot_mode() == BootMode::Uefi {
        uefi_print(args)
    }
}
