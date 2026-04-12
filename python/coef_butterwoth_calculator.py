from scipy.signal import butter
import numpy as np

fs = 44100

# Design filter
sos = butter(2, [500, 3000], btype='band', fs=fs, output='sos')

scale = 2**16

def to_fixed(x):
    return int(np.round(x * scale))

def to_bin(x):
    # Convert to signed 18-bit binary string
    if x < 0:
        x = (1 << 18) + x  # two's complement
    return format(x, '018b')

print("=== Verilog Coefficients ===\n")

for i, section in enumerate(sos):
    b0, b1, b2, a0, a1, a2 = section

    print(f"// Biquad {i+1}")
    
    coeffs = {
        "b0": to_fixed(b0),
        "b1": to_fixed(b1),
        "b2": to_fixed(b2),
        "a1": to_fixed(a1),
        "a2": to_fixed(a2),
    }

    for name, val in coeffs.items():
        print(f"localparam signed [17:0] {name}_{i+1} = 18'sd{val}; // {to_bin(val)}")

    print()