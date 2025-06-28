#![no_main]
#![no_std]

#[macro_use]
extern crate uefi;
use uefi::prelude::*;

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();
    for i in 0..100000 {
        print!("{i} ");
    }
    Status::SUCCESS
}
