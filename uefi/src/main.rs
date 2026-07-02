//! This file is the main loader for UEFI firmware.
#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(self::test_runner)]
#![reexport_test_harness_main = "test_main"]

extern crate alloc;
use alloc::{borrow::Cow::Borrowed, vec};
mod version;
use hadris_iso::{IsoImage, Read, Seek};
use version::VERSION;
use proka_bootloader::header::Header;
use proka_bootloader::output::Framebuffer;
use uefi::{
    boot::{get_handle_for_protocol, open_protocol_exclusive}, mem::memory_map::MemoryMapOwned, prelude::*, println, proto::{
        console::gop::{GraphicsOutput, PixelFormat},
        media::{block::BlockIO, file::{File, FileAttribute, FileInfo, FileMode}},
    }, system::with_config_table, table::cfg::ConfigTableEntry
};

// PAT constants
const IA32_PAT: u32 = 0x277;
const PAT_UC: u64 = 0x00;
const PAT_WC: u64 = 0x01;
const PAT_WT: u64 = 0x04;
const PAT_WP: u64 = 0x05;
const PAT_WB: u64 = 0x06;
const PAT_UC_MINUS: u64 = 0x07;

/// A struct which implemented [`BlockIo`] trait.
struct Reader {
    pos: u64,
    blksize: u32,
    lastblk: u64,
}

impl Reader {
    // Create a new Reader instance.
    fn new() -> Self {
        let block_io = get_handle_for_protocol::<BlockIO>().unwrap();
        let block_io = open_protocol_exclusive::<BlockIO>(block_io).expect("Failed to open BlockIO protocol");
        Self {
            pos: 0,
            blksize: block_io.media().block_size(),
            lastblk: block_io.media().last_block(),
        }
    }
}

impl Read for Reader {
    fn read(&mut self, buf: &mut [u8]) -> hadris_iso::IoResult<usize> {
        // Get block IO
        let mut total_read = 0;
        let mut buf_offset = 0;

        while total_read < buf.len() {
            let block_num = self.pos / self.blksize as u64;
            if block_num > self.lastblk {
                break; // No more blocks to read
            }

            let block_lba = self.pos / self.blksize as u64;
            let block_offset = (self.pos % self.blksize as u64) as usize;
            let bytes_to_read = core::cmp::min(self.blksize as usize - block_offset, buf.len() - total_read);

            // Read the block into a temporary buffer
            let mut temp_buf = vec![0u8; self.blksize as usize];
            let read_result: Result<(), hadris_iso::Error> = {
                let block_io = get_handle_for_protocol::<BlockIO>().unwrap();
                let block_io = open_protocol_exclusive::<BlockIO>(block_io).unwrap();
                block_io.read_blocks(block_io.media().media_id(), block_lba, &mut temp_buf).map_err(|_| hadris_iso::Error::from(hadris_iso::ErrorKind::Other))?;
                Ok(())
            };

            if read_result.is_err() {
                return Err(hadris_iso::Error::from(read_result.err().unwrap()));
            }

            // Copy the relevant portion of the temporary buffer to the output buffer
            buf[buf_offset..buf_offset + bytes_to_read].copy_from_slice(&temp_buf[block_offset..block_offset + bytes_to_read]);

            // Update positions and counters
            self.pos += bytes_to_read as u64;
            total_read += bytes_to_read;
            buf_offset += bytes_to_read;
        }

        Ok(total_read)
    }
}

impl Seek for Reader {
    fn seek(&mut self,pos: hadris_iso::SeekFrom) -> hadris_iso::IoResult<u64> {
        match pos {
            hadris_iso::SeekFrom::Start(offset) => {
                self.pos = offset;
            }
            hadris_iso::SeekFrom::End(offset) => {
                let end_pos = (self.lastblk + 1) * self.blksize as u64;
                self.pos = (end_pos as i64 + offset) as u64;
            }
            hadris_iso::SeekFrom::Current(offset) => {
                self.pos = (self.pos as i64 + offset) as u64;
            }
        }
        Ok(self.pos)
    }
}

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();

    // This is the main code now..
    println!("Welcome to Proka Bootloader!");
    println!("Currently you are in stage0, and booting Proka OS now :/");

    // Set up PAT
    println!("[INFO] Setting up PAT...");
    unsafe {
        let pat_value: u64 = (PAT_WB) // PAT0: Write Back
            | (PAT_WC << 8)     // PAT1: Write through
            | (PAT_UC_MINUS << 16) // PAT2: UC- 
            | (PAT_UC << 24)    // PAT3: Uncachable
            | (PAT_WB << 32)    // PAT4: Write Back
            | (PAT_WT << 40)    // PAT5: Write Combined
            | (PAT_WP << 48)    // PAT6: Write Protect
            | (0 << 56); // Reserved
        x86_64::registers::model_specific::Msr::new(IA32_PAT).write(pat_value);
    }
    println!("[INFO] Successfully set up PAT, now reading kernel...");

    // Get current image handle
    let handle = boot::image_handle();

    // Read file
    reader(handle);

    // Verificate kernel
    let hdr = unsafe { &*(0x200000 as *const Header) };
    if hdr.magic != 0x504b4e4c {
        panic!("The kernel that was read is invalid")
    }

    let kernel_ver: [u16; 3] = unsafe {
        let hdr_ptr = 0x200000 as *const u8;
        let ptr = hdr_ptr.add(4) as *const [u16; 3];
        ptr.read_unaligned()
    };

    if kernel_ver != VERSION {
        panic!(
            "The version is mismatched.\n\
            Expected version {}.{}.{}, \
            but {}.{}.{} was found.
            ",
            VERSION[0], VERSION[1], VERSION[2], kernel_ver[0], kernel_ver[1], kernel_ver[2],
        );
    }

    // And get ACPI...
    //
    // If ACPI2 not found, then use ACPI1.
    println!("[INFO] Getting ACPI table...");
    with_config_table(|slice| {
        let rsdp = slice
            .iter()
            .find(|e| e.guid == ConfigTableEntry::ACPI2_GUID)
            .or_else(|| slice.iter().find(|e| e.guid == ConfigTableEntry::ACPI_GUID));

        if let Some(entry) = rsdp {
            unsafe {
                println!("ACPI addr: {}", entry.address as u64);
                *(0x10100 as *mut u64) = entry.address as u64;
            }
        }
    });

    // And get GOP protocol
    println!("[INFO] Getting GOP...");
    let gop_handle = boot::get_handle_for_protocol::<GraphicsOutput>().unwrap();
    let mut gop = boot::open_protocol_exclusive::<GraphicsOutput>(gop_handle).unwrap();

    // Get the essential information
    let address = gop.frame_buffer().as_mut_ptr() as u64;
    let width: u64 = gop.current_mode_info().resolution().0 as u64;
    let height: u64 = gop.current_mode_info().resolution().1 as u64;
    let pitch: u64 = (gop.current_mode_info().stride() * 4) as u64;
    let bpp: u64 = match gop.current_mode_info().pixel_format() {
        PixelFormat::Rgb => 4,     // 32 / 8
        PixelFormat::Bgr => 4,     // 32 / 8
        PixelFormat::Bitmask => 4, // 32 / 8
        _ => 0,                    // No framebuffer
    };

    // Clear screen
    unsafe {
        let addr = address as *mut u8;
        for y in 0..height {
            for x in 0..width {
                let offset = y * pitch + x * bpp;
                addr.add(offset as usize).cast::<u32>().write(0x00000000);
            }
        }
    }

    // Merge them as a Framebuffer struct and put to a fixed address
    let fb = Framebuffer::new(address as u64, width, height, bpp, pitch);
    unsafe {
        let ptr = 0x10000 as *mut Framebuffer;
        *ptr = fb;
    }

    // Fine, then quit the uefi boot services and do some preparations.
    let memory_map = unsafe {
        core::arch::asm!("cli"); // Disable interrupts before exiting boot services
        boot::exit_boot_services(None)
    };

    // Since then, the UEFI boot services will be disabled.
    // Copy the memory map to 0x10200
    unsafe {
        let ptr = 0x10200 as *mut MemoryMapOwned;
        *ptr = memory_map;
    }

    // Jump to stage1
    pkbl_uefi::stage1_entry();
}

fn reader(handle: Handle) {
    // Read the file by using raw method
    let read_raw = || {
        // Init
        let reader = Reader::new();
        let image = IsoImage::open(reader).expect("Failed to open ISO image");

        // Get root directory
        for entry in image.root_dir().iter(&image).entries() {
            let entry = entry.expect("Something wrong while getting entry...");
            match entry.display_name() {
                Borrowed("PROKA-KERNEL;1") => {
                    println!("[INFO] Found kernel file, reading...");
                    let content = image.read_file(&entry).expect("Failed to read file...");
                    let buf = unsafe { core::slice::from_raw_parts_mut(0x200000 as *mut u8, content.len()) };
                    buf.copy_from_slice(&content);
                }

                Borrowed("INITPRT.IMG;1") => {
                    println!("[INFO] Found initprt file, reading...");
                    let content = image.read_file(&entry).expect("Failed to read file...");
                    let buf = unsafe { core::slice::from_raw_parts_mut(0x3200000 as *mut u8, content.len()) };
                    buf.copy_from_slice(&content);
                }

                _ => continue,
            }
        }
    };

    // Read the kernel from FAT32 partition, and put it to 0x200000
    let kernel_path = cstr16!("\\proka-kernel");
    let initprt_path = cstr16!("\\initprt.img");
    let mut fs = boot::get_image_file_system(handle).unwrap();
    let mut root = fs.open_volume().unwrap();
    let kernel = root.open(kernel_path, FileMode::Read, FileAttribute::empty());
    let initprt = root.open(initprt_path, FileMode::Read, FileAttribute::empty());

    // Check: Is all exists...
    if kernel.is_err() || initprt.is_err() {
        drop(fs);
        read_raw();
        return;
    }

    // Re-init the kernel and initprt 
    let mut kernel = kernel.unwrap();
    let mut initprt = initprt.unwrap();

    // And get the kernel size
    let infobuf: &mut [u8; 1024] = &mut [0; 1024]; // 1024 bytes for file info
    let info = kernel.get_info::<FileInfo>(infobuf).unwrap();
    let size = info.file_size() as usize;

    // Copy to the target address
    let mut buf = unsafe {
        core::slice::from_raw_parts_mut(0x200000 as *mut u8, size) // 64MB for kernel
    };
    kernel.into_regular_file().unwrap().read(&mut buf).unwrap();
    println!("[INFO] Successfully loaded kernel into 0x200000 (phys) / 0xffff800000000000 (virt).");

    // Read the initprt from FAT32 partition, and put it to 0x2200000
    // And get the initprt size
    let infobuf: &mut [u8; 1024] = &mut [0; 1024]; // 1024 bytes for file info
    let info = initprt.get_info::<FileInfo>(infobuf).unwrap();
    let size = info.file_size() as usize; // Copy to the target address
    let mut buf = unsafe { core::slice::from_raw_parts_mut(0x3200000 as *mut u8, size) };
    initprt.into_regular_file().unwrap().read(&mut buf).unwrap();
    println!(
        "[INFO] Successfully loaded initprt into 0x3200000 (phys) / 0xffff800002000000 (virt)."
    );
}

#[cfg(test)]
fn test_runner(tests: &[&dyn Fn()]) {
    for test in tests {
        test();
    }
}
