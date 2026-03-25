#include "uart.h"
#include "flash.h"
#include "fft.h"

// Define accelerator registers
#define REG_CONFIG_AND_STATUS  (*(volatile uint32_t*)0x03000000)
#define REG_NUMBER_OF_ENTRIES  (*(volatile uint32_t*)0x03000004)
#define REG_NUMBER_OF_BITS     (*(volatile uint32_t*)0x03000008)
#define ACCEL_SRAM_START_ADDR                        0x03000010

// Define accelerator control/status (CSR) bits
#define MASK_CSR_RESET 1 << 0
#define MASK_CSR_ENABLE 1 << 1
#define MASK_CSR_DONE  1 << 2


static int read_dec_entry_from_accelerator_sram(int index) {
	// i * 4 because each entry (signed 32-bit integer) is 4 bytes
	uint32_t sram_address = ACCEL_SRAM_START_ADDR + index*4;

	return (*(volatile int*)(sram_address));
}

static void accelerated_fft(int n, int chunks, int bits) { 
	// Initialize accelerator
	REG_CONFIG_AND_STATUS = 0;
	REG_NUMBER_OF_ENTRIES = 0;

	// Reset accelerator (this additional reset is necessary when processing multiple chunks)
	REG_CONFIG_AND_STATUS = REG_CONFIG_AND_STATUS | MASK_CSR_RESET;  // Set reset bit
	REG_CONFIG_AND_STATUS &= ~MASK_CSR_RESET; // Clear reset bit

	int entries_per_chunk = n / chunks;

	// Set number of entries
	REG_NUMBER_OF_ENTRIES = entries_per_chunk;

    // Set number of bits
    REG_NUMBER_OF_BITS = bits;

	// Due to the number of values stored at index 0 and the number
	// of chunks stored at index 1, the twiddles start at index 2
    int flash_offset = 2; 

	// Write twiddles to SRAM of accelerator
	for (int i = 0; i < 2 * bits; i++) {
		// i * 4 because each entry (signed 32-bit integer) is 4 bytes
		uint32_t sram_address = ACCEL_SRAM_START_ADDR + i*4;

		(*(volatile int*)(sram_address)) = read_dec_entry_from_flash(flash_offset + i);
	}

    // We read starting from i + 2 + 2 * bits, because those 2 * bits entries were the twiddles
    flash_offset += 2 * bits;

	for (int chunk = 0; chunk < chunks; chunk++) {
		// Reset accelerator
		REG_CONFIG_AND_STATUS = REG_CONFIG_AND_STATUS | MASK_CSR_RESET;  // Set reset bit
		REG_CONFIG_AND_STATUS &= ~MASK_CSR_RESET; // Clear reset bit

		// Write input array to SRAM of accelerator
		for (int i = 0; i < entries_per_chunk; i++) {
			// The inputs are composed of a real part only: Write the real part.
			// i * 4 because each entry (signed 32-bit integer) is 4 bytes
			uint32_t sram_address = ACCEL_SRAM_START_ADDR + (2 * bits + 2 * i) * 4;

			int bit_reverse_i = bit_reverse(i, bits);
			(*(volatile int*)(sram_address)) = read_dec_entry_from_flash(flash_offset + bit_reverse_i);
			
			// As the algorithm is in-place, we set the imaginary part to 0.
			sram_address += 4;
			(*(volatile int*)(sram_address)) = 0;
		}

		// Start accelerator
		REG_CONFIG_AND_STATUS |= MASK_CSR_ENABLE;

		// Wait for accelerator to finish
		while (!(REG_CONFIG_AND_STATUS & MASK_CSR_DONE));

		// Disable accelerator
		REG_CONFIG_AND_STATUS &= ~MASK_CSR_ENABLE;

		flash_offset += entries_per_chunk;

		// In the accelerator SRAM, the the #values to FFT and #chunks are not stored
		int sram_offset = 2 * bits;

		for (int i = 0; i < entries_per_chunk; i++) {
			int real = read_dec_entry_from_accelerator_sram(sram_offset + 2 * i);
			// int imag = 0;
			int imag = read_dec_entry_from_accelerator_sram(sram_offset + 2 * i + 1);

			print_str("  ");
			print_dec(real);
			print_str(" + ");
			print_dec(imag);
			print_str("j,\n");
		}
	}
}

static void init_picosoc() {
	#define SRAM_ADDR_HEAD 0x00000000
	#define SRAM_ADDR_END  0x000003FF

    // Initialize SRAM (Otherwise the post-synthesis/layout simulation will fail, finished within 17192 cycles)
    volatile uint32_t* sram_addr = 0x00000000;
    for (sram_addr = 0; sram_addr <= (volatile uint32_t*) SRAM_ADDR_END; sram_addr += 4) {
        *sram_addr = 0;
    }

    // Initialize UART
    init_uart();
}

void main(void)
{
	// Initialize PicoSoC
	init_picosoc();

    int n = read_dec_entry_from_flash(0);
	int chunks = read_dec_entry_from_flash(1);
    int bits = flog2(n / chunks);

	print_str("\nFrequency domain output: \n[\n");

	// We do not need to pass the array and its size to the accelerated_fft function
	// as this information is read from the flash memory by the function itself
	accelerated_fft(n, chunks, bits);

	print_str("]\n");

    // End of Program
    print_char(-1);
}

/*
 * Define the entry point of the program.
 */
__attribute__((section(".text.start")))
void _start(void)
{
	main();
}
