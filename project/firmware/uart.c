/*##########################################################################
###
### RISC-V PicoSoC C Library: UART driver
###
###     TU Delft ET4351
###     April 2023, C. Gao
###
##########################################################################*/
#include "uart.h"

void init_uart(void)
{
	// set up UART
	reg_uart_clkdiv = 104; 
}

void print_char(char c)
{
	reg_uart_data = c;
}

void print_str(const char *p)
{
	while (*p)
		print_char(*(p++));
}

void print_hex(uint32_t v, int digits)
{
	for (int i = 7; i >= 0; i--) {
		char c = "0123456789abcdef"[(v >> (4*i)) & 15];
		if (c == '0' && i >= digits) continue;
		print_char(c);
		digits = i;
	}
}

void print_dec(int v)
{
    if (v < 0) {
        print_char('-');
        v = -v;
    }

    char digits[10];
    int i = 0;
    do {
        digits[i++] = (v % 10) + '0';
        v /= 10;
    } while (v != 0);

    while (i > 0) {
        print_char(digits[--i]);
    }
}

void print_dec_array(int array[], int n) {
    print_str("[\n");
    for (int i = 0; i < n; i++) {
        print_str("  ");
        print_dec(array[i]);

        if (i == n -1)
            print_str("\n]");
        else
            print_str(",\n");
    }
}
