import os
import numpy as np
import soundfile as sf


def ring_mod(y, sr, freq=30):
    t = np.arange(len(y)) / sr
    osc = np.sin(2 * np.pi * freq * t)
    return y * osc


here = os.path.dirname(os.path.abspath(__file__))
in_path = os.path.normpath(os.path.join(here, '..', 'wav', 'nothingonyou.wav'))
out_path = os.path.normpath(os.path.join(here, '..', 'wav', 'out_ring_mod.wav'))

print("Input:", in_path)
print("Output:", out_path)

try:
    y, sr = sf.read(in_path)
    if y.ndim > 1:
        y = np.mean(y, axis=1)
except Exception as e:
    print("Failed to load input:", e)
    raise

y_out = ring_mod(y, sr, freq=30)

if np.max(np.abs(y_out)) > 0:
    y_out = y_out / np.max(np.abs(y_out))

sf.write(out_path, y_out, sr)
print("Saved:", out_path)
