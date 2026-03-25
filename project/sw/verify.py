import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sound_util import process_audio
import numpy as np
from scipy.io import wavfile


AUDIO_PATH = 'recovered_audio.wav'


ARGS = sys.argv[1:]
if len(ARGS) == 1:
    output_dir = ARGS[0]
else:
    raise ValueError("Expected exactly one argument specifying the output directory (sim_behav, sim_struct or sim_phys).")

output_file = f'../{output_dir}/outputs.txt'
expected_out_file = '../firmware/expected_output.txt'

if os.path.exists(AUDIO_PATH):
    os.remove(AUDIO_PATH)

with open(output_file, 'r') as f:
    out_text = f.read()

out = out_text.split("Frequency domain output:")[1].strip().splitlines()[1:-1]
out = [line.strip() for line in out]

# Parse complex numbers, removing "Chunk" prefix if present
out_cplx = []
for out_val in out:
    # Remove "Chunk" prefix if it exists
    cleaned = out_val.replace("Chunk", "").strip()
    
    # Skip empty lines
    if not cleaned or cleaned == ',':
        continue
    
    # Remove spaces, commas, and clean up the format
    cleaned = cleaned.replace(" ", "").replace(",", "")
    # Handle various formats
    cleaned = cleaned.replace("(", "").replace(")", "")
    # Fix +- to just -
    cleaned = cleaned.replace("+-", "-")
    # Ensure 'j' is present
    if 'i' in cleaned:
        cleaned = cleaned.replace('i', 'j')
    
    try:
        out_cplx.append(complex(cleaned))
    except ValueError as e:
        print(f"Failed to parse: '{out_val}' -> '{cleaned}'")
        raise e

with open(expected_out_file, 'r') as f:
    expected_text = f.read()

expected = expected_text.strip().replace("(", "").replace(")", "").splitlines()
expected_cplx = [complex(exp_val) for exp_val in expected]

assert len(out_cplx) == len(expected_cplx), f"Output length does not match expected length: {len(out_cplx)} != {len(expected_cplx)}"

for i in range(len(out_cplx)):
    assert out_cplx[i] == expected_cplx[i], f"Output value at index {i} does not match expected value"

out_cplx_chunked = []
for i in range(0, len(out_cplx), 32):
    out_cplx_chunked.append(np.array(out_cplx[i:i+32]))

_, _, recovered_audio = process_audio(np.array(out_cplx_chunked))

# Save to .wav using numpy
wavfile.write(AUDIO_PATH, 44100, np.int16(recovered_audio * 32767))

print("Test Passed ^_^ Outputs and Gold are identical!!!")
sys.exit(0)
