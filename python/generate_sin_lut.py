import numpy as np

# Parameters
N = 64  # Number of LUT entries for quarter phase (0 to π/2)
Q_FORMAT = 11  # Q11 format (12-bit signed: 1 sign bit + 11 fractional bits)

# Generate quarter phase sine lookup table (0 to π/2)
addresses = np.arange(N)
theta_values = addresses * (np.pi / 2) / (N - 1)  # Map 0..63 to 0..π/2
sin_values = np.sin(theta_values)

# Convert to Q11 fixed-point (12-bit signed)
scale = 2 ** Q_FORMAT
sin_fixed = np.round(sin_values * scale).astype(np.int32)

# Clip to 12-bit signed range: -2^11 to 2^11-1
sin_fixed = np.clip(sin_fixed, -2**11, 2**11 - 1)

# Convert to unsigned 12-bit representation for COE file
# (Xilinx uses unsigned representation in COE files)
sin_unsigned = np.where(sin_fixed < 0, sin_fixed + 2**12, sin_fixed)

# Write COE file
with open('../source/sin_lut.coe', 'w', encoding='utf-8') as f:
    f.write("; Sine Quarter Phase Lookup Table\n")
    f.write("; 64 entries, 12-bit values, Q11 format\n")
    f.write("; Maps input 0 to 63 -> sin(0) to sin(pi/2)\n")
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    
    for i, val in enumerate(sin_unsigned):
        if i < len(sin_unsigned) - 1:
            f.write(f"{val:03X},\n")
        else:
            f.write(f"{val:03X};\n")  # Last entry ends with semicolon

print(f"Generated sin_lut.coe with {N} entries")
print(f"Sample values:")
print(f"  sin(0°) = {sin_values[0]:.6f} -> {sin_fixed[0]} (0x{sin_unsigned[0]:03X})")
print(f"  sin(30°) = {sin_values[21]:.6f} -> {sin_fixed[21]} (0x{sin_unsigned[21]:03X})")
print(f"  sin(45°) = {sin_values[32]:.6f} -> {sin_fixed[32]} (0x{sin_unsigned[32]:03X})")
print(f"  sin(60°) = {sin_values[42]:.6f} -> {sin_fixed[42]} (0x{sin_unsigned[42]:03X})")
print(f"  sin(90°) = {sin_values[63]:.6f} -> {sin_fixed[63]} (0x{sin_unsigned[63]:03X})")
