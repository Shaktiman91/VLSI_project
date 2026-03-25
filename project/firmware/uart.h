/*##########################################################################
###
### RISC-V PicoSoC C Library: UART driver
###
###     TU Delft ET4351
###     April 2023, C. Gao
###
##########################################################################*/
#ifndef UART_H
#define UART_H

#include <stdint.h>
#include <stdbool.h>

#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data (*(volatile uint32_t*)0x02000008)

void init_uart(void);
void print_char(char c);
void print_str(const char *p);
void print_hex(uint32_t v, int digits);
void print_dec(int v);
void print_dec_array(int array[], int n);

#endif