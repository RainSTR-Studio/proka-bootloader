//! The UEFI public library.
#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(self::test_runner)]
#![reexport_test_harness_main = "test_main"]

/// The stage1 entry
pub fn stage1_entry() -> ! {
    // Once you entered the stage
    loop {}
}

#[cfg(test)]
fn test_runner(tests: &[&dyn Fn()]) {
    for test in tests {
        test();
    }
}