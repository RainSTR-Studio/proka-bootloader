//! This crate provides the struct, enums about the proka
//! bootloader, including the boot information, and so on.
//!
//! # About proka bootloader
//! Well, this bootloader is for Proka Kernel, which will obey
//! its standard. For more information, see <url>.

#![no_std]
#![no_main]
pub mod boot;
pub mod io;

/// The public loader main function.
#[cfg(feature = "loader_main")]
#[unsafe(no_mangle)]
pub extern "C" fn loader_main() {
    println!("Hello world!")
}
