#define SCALE 12

typedef struct Complex Complex;

struct Complex {
  int real;
  int imag;
};

static Complex complex_mult(Complex a, Complex b);

static Complex complex_add(Complex a, Complex b);

static Complex complex_sub(Complex a, Complex b);

int flog2(int x);

int bit_reverse(int x, int bits);

void bit_reverse_array(int input[], Complex output[], int n, int bits);

void fft(Complex array[], Complex twiddles[], int n, int bits);
