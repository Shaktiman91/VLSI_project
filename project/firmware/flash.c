#include "flash.h"

int read_dec_entry_from_flash(int index) {
    uint32_t flash_index = FLASH_END-MAX_SEQUENCE_LENGTH*ENTRY_BYTES+1+index*4;

    // Make sure flash address is >= 0. Better to use assert()
    // for this, but it is not supported by this compile chain
    if (index < 0) {
        print_str("[!] Tried to write from negative flash address");
        return 0;
    }

    if (flash_index > FLASH_END) {
        print_str("[!] Tried to read from address outside of the external flash");
        return 0;
    }

    return (*(volatile int*)(flash_index));
}
