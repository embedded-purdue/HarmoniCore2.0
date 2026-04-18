from pathlib import Path

import numpy as np


N = 64
Q_FORMAT = 23
WIDTH = 24
OUT_DIR = Path(__file__).resolve().parents[1] / "source"


addresses = np.arange(N)
theta_values = addresses * (np.pi / 2) / (N - 1)
sin_values = np.sin(theta_values)

scale = 2**Q_FORMAT
sin_fixed = np.round(sin_values * scale).astype(np.int64)
sin_fixed = np.clip(sin_fixed, -(2**Q_FORMAT), 2**Q_FORMAT - 1)
sin_unsigned = np.where(sin_fixed < 0, sin_fixed + 2**WIDTH, sin_fixed)

OUT_DIR.mkdir(parents=True, exist_ok=True)

with (OUT_DIR / "sin_lut.coe").open("w", encoding="utf-8") as f:
    f.write("; Sine Quarter Phase Lookup Table\n")
    f.write("; 64 entries, 24-bit values, Q1.23 format\n")
    f.write("; Maps input 0 to 63 -> sin(0) to sin(pi/2)\n")
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")

    for i, val in enumerate(sin_unsigned):
        terminator = "," if i < len(sin_unsigned) - 1 else ";"
        f.write(f"{val:06X}{terminator}\n")

with (OUT_DIR / "sin_lut.mem").open("w", encoding="utf-8") as f:
    for val in sin_unsigned:
        f.write(f"{val:06X}\n")

print(f"Generated sin_lut.coe and sin_lut.mem with {N} entries")
print("Sample values:")
print(f"  sin(0 deg) = {sin_values[0]:.6f} -> {sin_fixed[0]} (0x{sin_unsigned[0]:06X})")
print(f"  sin(30 deg) = {sin_values[21]:.6f} -> {sin_fixed[21]} (0x{sin_unsigned[21]:06X})")
print(f"  sin(45 deg) = {sin_values[32]:.6f} -> {sin_fixed[32]} (0x{sin_unsigned[32]:06X})")
print(f"  sin(60 deg) = {sin_values[42]:.6f} -> {sin_fixed[42]} (0x{sin_unsigned[42]:06X})")
print(f"  sin(90 deg) = {sin_values[63]:.6f} -> {sin_fixed[63]} (0x{sin_unsigned[63]:06X})")
