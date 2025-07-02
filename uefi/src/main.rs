#![no_main]
#![no_std]

use proka_bootloader::boot::*;
use uefi::prelude::*;
use uefi::println as uefi_println;  // Separate with the library's println

#[used]
// Initialize the boot info struct
static mut BOOT_INFO: Option<BootInfo> = None;

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();
    uefi_println!("Welcome to use Proka Bootloader!");
    let boot_info = BootInfo::new(BootMode::Uefi);
    unsafe {
        // Put to an address
        BOOT_INFO = Some(boot_info);
        BOOT_INFO.unwrap().put_addr(0x1000);
    }
    proka_bootloader::loader_main();
    Status::SUCCESS
}
