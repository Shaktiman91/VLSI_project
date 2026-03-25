import cmath
import math
from typing import List


SCALE = 12
MAX_N_PER_FFT = 32
TWIDDLES = []


for m in range(1, round(math.log2(MAX_N_PER_FFT)) + 1):
    stage = 1 << m  # m = 2, 4, 8, ..., n
    W = cmath.exp(-2j * cmath.pi / stage)
    W_scaled = complex(round(W.real * (1<<SCALE)), round(W.imag * (1<<SCALE)))
    TWIDDLES.append(W_scaled)


def complex_mult(in1: complex, in2: complex) -> complex:
    a = int(in1.real)
    b = int(in1.imag)
    c = int(in2.real)
    d = int(in2.imag)

    return complex((a * c - b * d) >> SCALE, (a * d + b * c) >> SCALE)


def flog2(x: int) -> int:
    r = 0

    while x > 1:
        r += 1
        x = x >> 1

    return r


def bit_reverse(i: int, bits: int) -> int:
    r: int = 0
    for _ in range(bits):
        r = (r << 1) | (i & 1)
        i >>= 1
    return r


def fft(x: List[complex]) -> List[complex]:
    n = len(x)
    bits = flog2(n)

    # Step 1: bit-reversal permutation
    X = [0j] * n

    for i in range(n):
        X[bit_reverse(i, bits)] = x[i]

    # Step 2: iterative FFT stages
    for stage in range(1, bits + 1):
        m = 1 << stage  # m = 2, 4, 8, ..., n

        half = m // 2
        w_m = TWIDDLES[stage-1]

        for base in range(0, n, m):
            w = complex(1 << SCALE, 0)

            for k in range(half):
                t = complex_mult(w, X[base + k + half])

                u = X[base + k]
                X[base + k] = u + t
                X[base + k + half] = u - t

                w = complex_mult(w, w_m)

    return X


def inv_dft(x: List[complex]) -> List[complex]:
    n = len(x)
    X = [0j] * n

    for k in range(n):
        sum_val = 0j
        for t in range(n):
            angle = 2j * cmath.pi * t * k / n
            sum_val += x[t] * cmath.exp(angle)
        X[k] = sum_val / n

    return X
