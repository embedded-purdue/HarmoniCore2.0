from pathlib import Path

import numpy as np


N = 128
XMAX = 4.0
Q_FORMAT = 23
WIDTH = 24
OUT_DIR = Path(__file__).resolve().parents[1] / "source"


addresses = np.arange(N)
x_values = addresses * (XMAX / (N - 1))
tanh_values = np.tanh(x_values)

scale = 2**Q_FORMAT
tanh_fixed = np.round(tanh_values * scale).astype(np.int64)
tanh_fixed = np.clip(tanh_fixed, -(2**Q_FORMAT), 2**Q_FORMAT - 1)
tanh_unsigned = np.where(tanh_fixed < 0, tanh_fixed + 2**WIDTH, tanh_fixed)

OUT_DIR.mkdir(parents=True, exist_ok=True)

with (OUT_DIR / "tanh_lut.coe").open("w", encoding="utf-8") as f:
    f.write("; Tanh Lookup Table for Distortion Effect\n")
    f.write("; 128 entries, 24-bit values, Q1.23 format\n")
    f.write("; Maps input 0 to 4.0 -> tanh(x)\n")
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")

    for i, val in enumerate(tanh_unsigned):
        terminator = "," if i < len(tanh_unsigned) - 1 else ";"
        f.write(f"{val:06X}{terminator}\n")

with (OUT_DIR / "tanh_lut.mem").open("w", encoding="utf-8") as f:
    for val in tanh_unsigned:
        f.write(f"{val:06X}\n")

print(f"Generated tanh_lut.coe and tanh_lut.mem with {N} entries")
print("Sample values:")
print(f"  tanh(0.0) = {tanh_values[0]:.6f} -> {tanh_fixed[0]}")
print(f"  tanh(1.0) = {tanh_values[32]:.6f} -> {tanh_fixed[32]}")
print(f"  tanh(2.0) = {tanh_values[64]:.6f} -> {tanh_fixed[64]}")
print(f"  tanh(4.0) = {tanh_values[127]:.6f} -> {tanh_fixed[127]}")
