#ifndef FLASH_H
#define FLASH_H

#include <stdint.h>
#include "uart.h"

#define FLASH_END 0x004FFFFF
#define MAX_SEQUENCE_LENGTH 16384 // 16*1024
#define ENTRY_BYTES 4

int read_dec_entry_from_flash(int index);

#endif
