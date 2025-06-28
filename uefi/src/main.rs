#![no_main]
#![no_std]

#[macro_use]
extern crate uefi;
use uefi::prelude::*;

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();
    println!("Welcome to use Proka Bootloader!");
    Status::SUCCESS
}
