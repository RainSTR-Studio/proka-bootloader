//! This file is the main loader for UEFI firmware.
#![no_std]
#![no_main]

use proka_bootloader::boot::BootInfo;
use uefi::prelude::*;

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();

    // TODO: Add main code here..

    Status::SUCCESS
}
