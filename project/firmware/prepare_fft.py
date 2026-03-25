import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'sw'))
from sound_util import generate_sound, downsample_to_32_samples, write_accel_io
from scipy.io import wavfile
import numpy as np
ARGS = " ".join(sys.argv[1:])
if len(ARGS) == 1 and ARGS.isdigit():
    n_blocks = int(ARGS)
else:
    n_blocks = -1

# Nokia Theme Sequence (Index in BASE_FREQS, Multiplier)
original_sequence = [
    (11, 1),
    (10, 1),
    (5, 2),
    (6, 2),
    (9, 1),
    (8, 1),
    (3, 2),
    (4, 2),
    (8, 1),
    (7, 1),
    (2, 2),
    (4, 2),
    (7, 4),
    (-1, 2),
]

# Updated unpacking to receive expanded_sequence, clean_sound, and full_sound
expanded_sequence, clean_sound, full_sound = generate_sound(original_sequence)

# Pass the expanded sequence indices to the downsampler
sim_transmitted_blocks = downsample_to_32_samples(expanded_sequence)

# Normalize the high-amplitude noisy signal to avoid integer overflow
max_val = np.max(np.abs(full_sound))
if max_val > 0:
    full_sound_normalized = full_sound / max_val
else:
    full_sound_normalized = full_sound

# Write normalized audio to wav files
wavfile.write('full_sound.wav', 44100, np.int16(full_sound_normalized * 32767))
wavfile.write('clean_sound.wav', 44100, np.int16(clean_sound * 32767))
if n_blocks > 0:
    sim_transmitted_blocks = sim_transmitted_blocks[:n_blocks]

write_accel_io(sim_transmitted_blocks)
