import numpy as np

# Parameters
N = 128  # Number of LUT entries (reduced from 1024 for smaller memory footprint)
XMAX = 4.0  # Maximum input value (corresponds to address 127)
Q_FORMAT = 11  # Q11 format (12-bit signed: 1 sign bit + 11 fractional bits)

# Generate lookup table
addresses = np.arange(N)
x_values = addresses * (XMAX / (N - 1))  # Map 0..1023 to 0..4
tanh_values = np.tanh(x_values)

# Convert to Q17 fixed-point (18-bit signed)
scale = 2 ** Q_FORMAT
tanh_fixed = np.round(tanh_values * scale).astype(np.int32)

# Clip to 12-bit signed range: -2^11 to 2^11-1
tanh_fixed = np.clip(tanh_fixed, -2**11, 2**11 - 1)

# Convert to unsigned 12-bit representation for COE file
# (Xilinx uses unsigned representation in COE files)
tanh_unsigned = np.where(tanh_fixed < 0, tanh_fixed + 2**12, tanh_fixed)

# Write COE file
with open('../source/tanh_lut.coe', 'w') as f:
    f.write("; Tanh Lookup Table for Distortion Effect\n")
    f.write("; 128 entries, 12-bit values, Q11 format\n")
    f.write("; Maps input 0 to 4.0 -> tanh(x)\n")
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    
    for i, val in enumerate(tanh_unsigned):
        if i < len(tanh_unsigned) - 1:
            f.write(f"{val:03X},\n")
        else:
            f.write(f"{val:03X};\n")  # Last entry ends with semicolon

print(f"Generated tanh_lut.coe with {N} entries")
print(f"Sample values:")
print(f"  tanh(0.0) = {tanh_values[0]:.6f} -> {tanh_fixed[0]}")
print(f"  tanh(1.0) = {tanh_values[32]:.6f} -> {tanh_fixed[32]}")
print(f"  tanh(2.0) = {tanh_values[64]:.6f} -> {tanh_fixed[64]}")
print(f"  tanh(4.0) = {tanh_values[127]:.6f} -> {tanh_fixed[127]}")
