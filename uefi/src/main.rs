#![no_main]
#![no_std]

#[macro_use]
extern crate uefi;
use library::boot::*;
use uefi::prelude::*;

#[used]
// Initialize the boot info struct
static mut BOOT_INFO: Option<BootInfo> = None;

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();
    println!("Welcome to use Proka Bootloader!");
    let boot_info = BootInfo::new(BootMode::Uefi);
    unsafe {
        BOOT_INFO = Some(boot_info);
        BOOT_INFO.unwrap().put_addr(0x1000);
    }
    Status::SUCCESS
}
