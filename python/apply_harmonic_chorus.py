import os
import numpy as np
import soundfile as sf

# Local vibrato implementation to avoid importing the full effects module (and librosa/numba)
def vibrato(x, sr, depth=0.0003, rate=5.0):
    n = len(x)
    t = np.arange(n) / sr
    delay = depth * np.sin(2 * np.pi * rate * t)
    delay_samples = delay * sr
    y = np.zeros_like(x)

    for i in range(n):
        idx = i - delay_samples[i]
        if idx < 0:
            y[i] = x[0]
            continue
        i0 = int(np.floor(idx))
        i1 = min(i0 + 1, n - 1)

        frac = idx - i0
        y[i] = (1 - frac) * x[i0] + frac * x[i1]

    return y


here = os.path.dirname(os.path.abspath(__file__))
in_path = os.path.normpath(os.path.join(here, '..', 'wav', 'nothingonyou.wav'))
out_path = os.path.normpath(os.path.join(here, '..', 'wav', 'out_vibrato.wav'))

print("Input:", in_path)
print("Output:", out_path)

try:
    y, sr = sf.read(in_path)
    # Convert to mono if needed
    if y.ndim > 1:
        y = np.mean(y, axis=1)
except Exception as e:
    print("Failed to load input:", e)
    raise

y_out = vibrato(y, sr)

# Normalize and save
if np.max(np.abs(y_out)) > 0:
    y_out = y_out / np.max(np.abs(y_out))

sf.write(out_path, y_out, sr)
print("Saved:", out_path)
