import os
import numpy as np
import soundfile as sf

def distortion(y, amount=100.0):
    return np.tanh(amount * y)


here = os.path.dirname(os.path.abspath(__file__))
in_path = os.path.normpath(os.path.join(here, '..', 'wav', 'nothingonyou.wav'))
out_path = os.path.normpath(os.path.join(here, '..', 'wav', 'distortion_v2.wav'))

print("Input:", in_path)
print("Output:", out_path)

try:
    y, sr = sf.read(in_path)
    if y.ndim > 1:
        y = np.mean(y, axis=1)
except Exception as e:
    print("Failed to load input:", e)
    raise

# Apply distortion
y_out = distortion(y, amount=50.0)

# Normalize and save
if np.max(np.abs(y_out)) > 0:
    y_out = y_out / np.max(np.abs(y_out))

sf.write(out_path, y_out, sr)
print("Saved:", out_path)
