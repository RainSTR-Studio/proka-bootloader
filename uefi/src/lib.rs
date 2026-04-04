//! The UEFI public library.
#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(self::test_runner)]
#![reexport_test_harness_main = "test_main"]

const PML4_ADDR: u64 = 0x20000;
const PDPT_LOW_ADDR: u64 = 0x21000;
const PDT_LOW_ADDR: u64 = 0x22000;
const PDPT_HIGH_ADDR: u64 = 0x23000;
const PDT_HIGH_ADDR: u64 = 0x24000;
const PDT_FB_ADDR: u64 = 0x27000;

use proka_bootloader::output::Framebuffer;
use x86_64::{
    PhysAddr, registers::control::{Cr3, Cr3Flags}, structures::paging::{PageTable, PageTableFlags, PhysFrame}
};

/// The stage1 entry
pub fn stage1_entry() -> ! {
    // Once you entered this function, you are in stage1.
    // This will do mapping of memory.
    // So, create a new page table, and map the physical memory to
    // the virtual memory with identity mapping. (0x0 ~ 0x1FFFFF)
    let framebuffer: Framebuffer = *unsafe { &*(0x10000 as *const Framebuffer) };

    // So, first, initialize the page tables.
    let pml4 = unsafe { &mut *(PML4_ADDR as *mut PageTable) };
    let pdpt_low = unsafe { &mut *(PDPT_LOW_ADDR as *mut PageTable) };
    let pdt_low = unsafe { &mut *(PDT_LOW_ADDR as *mut PageTable) };
    let pdpt_high = unsafe { &mut *(PDPT_HIGH_ADDR as *mut PageTable) };
    let pdt_high = unsafe { &mut *(PDT_HIGH_ADDR as *mut PageTable) };
    let pdt_fb = unsafe { &mut *(PDT_FB_ADDR as *mut PageTable) };

    // Fill all entries
    // Identity mapping for 0x0 ~ 0x1FFFFF
    // First, map the PDT page
    let pdt_flags = PageTableFlags::PRESENT | PageTableFlags::WRITABLE | PageTableFlags::HUGE_PAGE;

    // Map 1GB to support UEFI runtime services, and also for the future use
    for i in 0..512 {
        pdt_low[i as usize].set_addr(PhysAddr::new(i * 0x200000), pdt_flags);
    }

    // Map 128MB
    for i in 0..64 {
        let offset = 0x200000 * i;
        pdt_high[i as usize].set_addr(PhysAddr::new(offset + 0x200000), pdt_flags);
    }

    // Map 16MB
    for i in 0..8 {
        let addr = framebuffer.address() as u64;
        let offset = addr + i * 0x200000;
        pdt_fb[i as usize].set_addr(PhysAddr::new(addr + offset), pdt_flags);
    }

    // Then map the PDPT page
    let pdpt_flags = PageTableFlags::PRESENT | PageTableFlags::WRITABLE;
    pdpt_low[0].set_addr(PhysAddr::new(PDT_LOW_ADDR), pdpt_flags);
    pdpt_high[0].set_addr(PhysAddr::new(PDT_HIGH_ADDR), pdpt_flags);
    pdpt_high[1].set_addr(PhysAddr::new(PDT_FB_ADDR), pdpt_flags);

    // Finally, map the PML4 page
    let pml4_flags = PageTableFlags::PRESENT | PageTableFlags::WRITABLE;
    pml4[0].set_addr(PhysAddr::new(PDPT_LOW_ADDR), pml4_flags);
    pml4[256].set_addr(PhysAddr::new(PDPT_HIGH_ADDR), pml4_flags);

    // Load the new page table
    unsafe {
        let pml4_addr = PhysAddr::new(PML4_ADDR);
        let pml4_frame = PhysFrame::containing_address(pml4_addr);
        Cr3::write(pml4_frame, Cr3Flags::empty());
    }

    loop {}
}

#[cfg(test)]
fn test_runner(tests: &[&dyn Fn()]) {
    for test in tests {
        test();
    }
}
