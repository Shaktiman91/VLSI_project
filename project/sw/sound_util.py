from typing import List
import sys
import os
_sw_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _sw_dir)
sys.path.insert(0, os.path.join(_sw_dir, '..', 'firmware'))

import numpy as np
from scipy.fft import fftfreq

from fft import inv_dft

# --- Configuration ---
AUDIO_FS = 44100
SIM_FS = 32
NOTE_DURATION_SEC = 0.25  # Slightly longer to make the 32-sample chunk feel natural
SAMPLES_PER_CHUNK = 32  # Exactly 32 samples per time step

# E Major Scale + Dissonant Noise Frequencies
BASE_FREQS = [
    329.63,
    369.99,
    415.30,
    440.00,
    493.88,
    554.37,
    622.25,
    659.25,
    739.99,
    830.61,
    880.00,
    987.77,
    1108.73,
    1244.51,
    1318.51,
    1479.98,
    1661.22,
    1760.00,
]

# High-frequency noise components for the "Unbearable" HQ version
HQ_NOISE_FREQS = BASE_FREQS[12:18]
SIM_NOISE_FREQS = [14, 15]

def generate_sound(sequence):
    # --- 1. Preparation: Expand the Sequence ---
    expanded_sequence = []
    for idx, mult in sequence:
        for _ in range(int(mult)):
            expanded_sequence.append(idx)

    # --- 2. Create HQ Corrupted Signal (The "Hard to Listen" Version) ---
    hq_chunks = []
    clean_chunks = []  # Store clean audio chunks
    
    for idx in expanded_sequence:
        t = np.linspace(0, NOTE_DURATION_SEC, int(AUDIO_FS * NOTE_DURATION_SEC), False)
        melody = np.sin(2 * np.pi * BASE_FREQS[idx] * t) if idx != -1 else np.zeros_like(t)
        
        clean_chunks.append(melody) # Save clean melody

        # Heavy additive noise using multiple high-freq sines
        noise = sum(np.sin(2 * np.pi * f * t) for f in HQ_NOISE_FREQS) * 3.0
        hq_chunks.append(melody + noise)

    hq_signal = np.concatenate(hq_chunks)
    clean_signal = np.concatenate(clean_chunks) # Concatenate clean signal
    
    return expanded_sequence, clean_signal, hq_signal # Return all three
# --- 3. Discrete 32-Sample Simulation ---
# We simulate a "Transmission" where each note is 32 discrete samples
def downsample_to_32_samples(original_sequence):
    sim_transmitted_blocks = []
    t_sim = np.arange(SAMPLES_PER_CHUNK) / SIM_FS

    for idx in original_sequence:
        # Map melody index to 1-12Hz
        sig_freq = (idx + 1) if idx != -1 else 0
        signal_block = (
            np.sin(2 * np.pi * sig_freq * t_sim)
            if sig_freq > 0
            else np.zeros(SAMPLES_PER_CHUNK)
        )

        # Add the 14/15Hz noise to the discrete 32-sample block
        noise_block = (
            np.sin(2 * np.pi * SIM_NOISE_FREQS[0] * t_sim)
            + np.sin(2 * np.pi * SIM_NOISE_FREQS[1] * t_sim)
        ) * 5.0

        sim_transmitted_blocks.append(signal_block + noise_block)
    return sim_transmitted_blocks


# --- 4. Process Each 32-Sample Block (Noise Removal & Recovery) ---
def process_audio(spectrum): 
    recovered_audio_chunks = []
    original_indices = []
    recovered_indices = []

    for i, block in enumerate(spectrum):
        # Get the "Ground Truth" for this block
        true_idx = i
        original_indices.append(true_idx)

        # A. Remove Noise via FFT
        freq_bins = fftfreq(SAMPLES_PER_CHUNK, 1 / SIM_FS)

        # Notch out 14Hz and 15Hz bins
        block[np.abs(np.abs(freq_bins) - 14) < 0.1] = 0
        block[np.abs(np.abs(freq_bins) - 15) < 0.1] = 0

        clean_block = np.real(np.array(inv_dft(block.tolist())))

        # B. Decode back to melody index
        # Note: Using np.fft.fft here for the decoding step for speed/accuracy
        # but still using your clean_block from your custom inv_dft
        clean_spectrum = np.fft.fft(clean_block)
        mag = np.abs(clean_spectrum)[: SAMPLES_PER_CHUNK // 2]
        peak_idx = np.argmax(mag)

        if mag[peak_idx] < 0.5:
            current_recovered_idx = -1
        else:
            current_recovered_idx = peak_idx - 1

        recovered_indices.append(current_recovered_idx)

        # C. Resynthesize for Audio Output
        target_freq = (
            BASE_FREQS[current_recovered_idx] if current_recovered_idx != -1 else 0
        )
        t_out = np.linspace(0, NOTE_DURATION_SEC, int(AUDIO_FS * NOTE_DURATION_SEC), False)

        if target_freq == 0:
            recovered_audio_chunks.append(np.zeros_like(t_out))
        else:
            env = np.ones_like(t_out)
            env[:500], env[-500:] = np.linspace(0, 1, 500), np.linspace(1, 0, 500)
            recovered_audio_chunks.append(np.sin(2 * np.pi * target_freq * t_out) * env)

    final_recovered = np.concatenate(recovered_audio_chunks)
    return original_indices, recovered_indices, final_recovered

# --- 5. Frequency Comparison Visualization ---
def plot(original_indices, recovered_indices):
    import matplotlib.pyplot as plt
    plt.figure(figsize=(12, 6))
    plt.step(
        range(len(original_indices)),
        original_indices,
        label="Original Index (Ground Truth)",
        where="post",
    linewidth=2,
    alpha=0.7,
    )
    plt.step(
        range(len(recovered_indices)),
        recovered_indices,
        label="Recovered Index (After FFT Filtering)",
        where="post",
        linestyle="--",
        color="red",
    )
    plt.title("Frequency Index Comparison: Original vs. Recovered")
    plt.xlabel("Time Step (32-sample block)")
    plt.ylabel("Scale Index (E Major)")
    plt.yticks(
        range(-1, 12),
        [
            "Silence",
            "E4",
            "F#4",
            "G#4",
            "A4",
            "B4",
            "C#5",
            "D#5",
            "E5",
            "F#5",
            "G#5",
            "A5",
            "B5",
        ],
    )
    plt.grid(True, which="both", linestyle="--", alpha=0.5)
    plt.legend()
    plt.show()


# --- 6. Write hex data to load into flash memory as well as the expected accelerator output ---
def write_accel_io(y: List[List[float]]):
    from fft import SCALE, MAX_N_PER_FFT, TWIDDLES, fft

    BYTES_PER_VAL = 4
    START_ADDRESS = 0x004F0000

    def int_to_twos_complement(value: int, num_bits: int) -> str:
        if value < 0:
            value = (1 << num_bits) + value

        return format(value, f'0{num_bits}b')


    def chunk_list(lst, n):
        for i in range(0, len(lst), n):
            yield lst[i:i + n]

    chunks = len(y)
    y = np.concatenate(y)

    quant_y = [round(v * (1 << SCALE)) for v in y]

    bits_per_value = BYTES_PER_VAL*8

    assert all(-2**(bits_per_value-1) <= v < 2**(bits_per_value-1) for v in quant_y), "Quantized values exceed the representable range"

    values = [MAX_N_PER_FFT * chunks, chunks]

    for twiddle in TWIDDLES:
        values.append(int(twiddle.real))
        values.append(int(twiddle.imag))

    for q in quant_y:
        values.append(q)

    # Convert the integers to two's complement binary strings
    twos_compl_values = [int_to_twos_complement(value, bits_per_value) for value in values]
    # Reverse the chunked list to make sure that the numbers are converted to Little Endian
    byte_blocks = [reversed(list(chunk_list(value, 8))) for value in twos_compl_values]
    hex_values = [" ".join([format(int(block, 2), '02X') for block in value]) for value in byte_blocks]

    with open("fft_data.hex", "w") as file:
        file.write("@" + format(START_ADDRESS, '08X') + "\n")

        for v in hex_values:
            file.write(v + " \n")

    ground_truth = []

    for quant_y_chunk in chunk_list(quant_y, MAX_N_PER_FFT):
        fft_result = fft(quant_y_chunk)
        ground_truth.extend(fft_result)

    with open("expected_output.txt", "w") as file:
        for v in ground_truth:
            file.write(str(v) + "\n")

# --- 7. Playback ---
def play_sound(original_indices, recovered_indices, final_recovered):
    try:
        import sounddevice as sd
        print(
            f"Accuracy: {np.mean(np.array(original_indices) == np.array(recovered_indices)) * 100:.2f}%"
        )
        sd.play(final_recovered * 0.2, AUDIO_FS)
        sd.wait()
    except ImportError:
        print("sounddevice module not available. Skipping audio playback.")
