//! The UEFI public library.
#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(self::test_runner)]
#![reexport_test_harness_main = "test_main"]

const PML4_ADDR: u64 = 0x20000;
const PDPT_HIGH_ADDR: u64 = 0x21000;
const PDT_HIGH_ADDR: u64 = 0x22000;
const PDT_FB_ADDR: u64 = 0x23000;

use proka_bootloader::loader_main::loader_main;
use proka_bootloader::{BootMode, output::Framebuffer};
use x86_64::{
    PhysAddr,
    registers::control::{Cr3, Cr3Flags},
    structures::paging::{PageTable, PageTableFlags, PhysFrame},
};

/// The stage1 entry
pub fn stage1_entry() -> ! {
    // Once you entered this function, you are in stage1.
    // This will do mapping of memory.
    // First, copy the UEFI PML4 table to 0x100000.
    unsafe {
        let (cr3, _) = Cr3::read();
        let src = cr3.start_address().as_u64();
        let dst = PML4_ADDR;
        core::ptr::copy(src as *const u8, dst as *mut u8, 4096);
    }

    // So, create a new page table, and map the physical memory to
    // the virtual memory with identity mapping. (0x0 ~ 0x1FFFFF)
    let framebuffer: Framebuffer = *unsafe { &*(0x10000 as *const Framebuffer) };

    // So, first, initialize the page tables.
    let pml4 = unsafe { &mut *(PML4_ADDR as *mut PageTable) };
    let pdpt_high = unsafe { &mut *(PDPT_HIGH_ADDR as *mut PageTable) };
    let pdt_high = unsafe { &mut *(PDT_HIGH_ADDR as *mut PageTable) };
    let pdt_fb = unsafe { &mut *(PDT_FB_ADDR as *mut PageTable) };

    // Fill all entries
    // Identity mapping for 0x0 ~ 0x1FFFFF
    // First, map the PDT page
    let pdt_flags = PageTableFlags::PRESENT | PageTableFlags::WRITABLE | PageTableFlags::HUGE_PAGE;

    // Map 128MB
    for i in 0..64 {
        let offset = 0x200000 * i;
        pdt_high[i as usize].set_addr(PhysAddr::new(offset + 0x200000), pdt_flags);
    }

    // Map 16MB framebuffer
    let addr = framebuffer.address();
    let fb_flags = PageTableFlags::PRESENT 
        | PageTableFlags::WRITABLE
        | PageTableFlags::HUGE_PAGE
        | PageTableFlags::NO_CACHE
        | PageTableFlags::WRITE_THROUGH;
    for i in 0..8 {
        let offset = i * 0x200000;
        pdt_fb[i as usize].set_addr(PhysAddr::new(addr + offset), fb_flags);
    }

    // Then map the PDPT page
    let pdpt_flags = PageTableFlags::PRESENT | PageTableFlags::WRITABLE;
    pdpt_high[0].set_addr(PhysAddr::new(PDT_HIGH_ADDR), pdpt_flags);
    pdpt_high[1].set_addr(PhysAddr::new(PDT_FB_ADDR), pdpt_flags);

    // Finally, map the PML4 page
    let pml4_flags = PageTableFlags::PRESENT | PageTableFlags::WRITABLE;
    pml4[256].set_addr(PhysAddr::new(PDPT_HIGH_ADDR), pml4_flags);

    // Load the new page table
    unsafe {
        let pml4_addr = PhysAddr::new(PML4_ADDR);
        let pml4_frame = PhysFrame::containing_address(pml4_addr);
        Cr3::write(pml4_frame, Cr3Flags::empty());
    }

    // Go to stage2 to officially start the kernel
    loader_main(BootMode::Uefi)
}

#[cfg(test)]
fn test_runner(tests: &[&dyn Fn()]) {
    for test in tests {
        test();
    }
}
