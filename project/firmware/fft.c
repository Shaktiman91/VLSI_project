#include "fft.h"
#include "uart.h"

static Complex complex_mult(Complex a, Complex b)
{
    Complex result;

    result.real = ( (a.real * b.real) - (a.imag * b.imag) ) >> SCALE; 
    result.imag = ( (a.real * b.imag) + (a.imag * b.real) ) >> SCALE;

    return result;
}

static Complex complex_add(Complex a, Complex b)
{
    Complex result;

    result.real = a.real + b.real;
    result.imag = a.imag + b.imag;

    return result;
}

static Complex complex_sub(Complex a, Complex b)
{
    return complex_add(a, (Complex){.real = -b.real, .imag = -b.imag});
}

int flog2(int x)
{
    int r = 0;

    while (x > 1) {
        x = x >> 1;
        r++;
    }

    return r;
}

int bit_reverse(int x, int bits)
{
    int rev = 0;

    for (int j = 0; j < bits; j++) {
        rev = (rev << 1) | (x & 1);
        x = x >> 1;
    }

    return rev;
}

void bit_reverse_array(int input[], Complex output[], int n, int bits)
{
    for (int i = 0; i < n; i++) {
        int rev = bit_reverse(i, bits);
        output[rev] = (Complex){.real = input[i], .imag = 0};
    }
}

void fft(Complex x[], Complex twiddles[], int n, int bits) {
    for (int stage = 1; stage < bits + 1; stage++) {
        int m = 1 << stage;
        int half = m / 2;

        Complex w_m = twiddles[stage - 1];

        for (int base = 0; base < n; base += m) {
            Complex w = (Complex){.real = 1 << SCALE, .imag = 0};

            for (int k = 0; k < half; k++) {
                Complex t = complex_mult(w, x[base + k + half]);
                Complex u = x[base + k];

                x[base + k] = complex_add(u, t);
                x[base + k + half] = complex_sub(u, t);

                w = complex_mult(w, w_m);
            }
        }
    }
}
