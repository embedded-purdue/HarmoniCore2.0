import os
from effects import load_audio, save_audio, harmonic_chorus

here = os.path.dirname(os.path.abspath(__file__))
in_path = os.path.normpath(os.path.join(here, '..', 'wav', 'nothingonyou.wav'))
out_path = os.path.normpath(os.path.join(here, '..', 'wav', 'out_harmonic_chorus.wav'))

print("Input:", in_path)
print("Output:", out_path)

try:
    y, sr = load_audio(in_path, sr=44100)
except Exception as e:
    print("Failed to load input:", e)
    raise

y_out = harmonic_chorus(y, sr)
save_audio(out_path, y_out, sr)
print("Saved:", out_path)
