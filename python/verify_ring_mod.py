import numpy as np
import sys

def ring_mod_python(y, freq_normalized):
    """
    Python reference implementation of ring modulator.
    
    Args:
        y: Input samples (array of signed 18-bit values)
        freq_normalized: Oscillator frequency as fraction of sample rate
                        (phase_increment / 2^18)
    
    Returns:
        Output samples (array of signed 18-bit values)
    """
    n_samples = len(y)
    t = np.arange(n_samples)
    
    # Generate oscillator using same phase accumulation as hardware
    osc = np.sin(2 * np.pi * freq_normalized * t)
    
    # Multiply input by oscillator
    return y * osc

def read_simulation_output(filename):
    """
    Read CSV output from SystemVerilog testbench.
    Expected format: sample_num,sample_in,phase,osc,output
    """
    data = np.loadtxt(filename, delimiter=',', skiprows=1, dtype=int)
    return {
        'sample_num': data[:, 0],
        'sample_in': data[:, 1],
        'phase': data[:, 2],
        'osc': data[:, 3],
        'output': data[:, 4]
    }

def signed_18bit(val):
    """Convert unsigned 18-bit value to signed."""
    if val >= 2**17:
        return val - 2**18
    return val

def verify_ring_mod(csv_file):
    """
    Verify hardware ring modulator output against Python reference.
    """
    print("="*70)
    print("Ring Modulator Verification")
    print("="*70)
    
    # Read simulation data
    try:
        sim_data = read_simulation_output(csv_file)
    except FileNotFoundError:
        print(f"ERROR: Could not find {csv_file}")
        print("Run the simulation first to generate output CSV")
        return False
    
    # Convert to signed values
    sample_in_signed = np.array([signed_18bit(x) for x in sim_data['sample_in']])
    osc_signed = np.array([signed_18bit(x) for x in sim_data['osc']])
    output_signed = np.array([signed_18bit(x) for x in sim_data['output']])
    
    # Calculate expected output using Python implementation
    # The hardware uses phase increment of 27968
    phase_increment = 27968
    freq_normalized = phase_increment / (2**18)
    
    # Generate reference oscillator
    n_samples = len(sample_in_signed)
    
    # For each sample, calculate what oscillator value should be
    # The oscillator is a sine wave with the accumulated phase
    phase_accum = np.cumsum(np.ones(n_samples) * phase_increment) % (2**18)
    
    # Convert phase to sine (matching hardware quarter-phase symmetry)
    # Hardware uses upper 6 bits for LUT address (64 entries for quarter phase)
    # and reconstructs full sine wave using symmetry
    osc_expected_float = np.sin(2 * np.pi * phase_accum / (2**18))
    
    # Scale to 18-bit range (Q17 format for oscillator)
    # The hardware oscillator is actually 12-bit (Q11) from LUT, 
    # then sign-extended to 18-bit
    osc_expected_scaled = osc_expected_float * (2**11)  # Q11 scale from LUT
    
    # Calculate expected output: input * oscillator
    # Hardware does 18-bit * 18-bit = 36-bit, then takes bits [28:11]
    expected_output_float = sample_in_signed * osc_expected_float
    
    # Simulate hardware multiplication and bit extraction
    expected_output_full = (sample_in_signed.astype(np.int64) * 
                           (osc_expected_scaled.astype(np.int64)))
    expected_output = (expected_output_full >> 11).astype(np.int32)
    expected_output = np.clip(expected_output, -2**17, 2**17-1)
    
    # Compare results
    print(f"\nTotal samples: {n_samples}")
    print(f"Oscillator frequency (normalized): {freq_normalized:.6f}")
    print(f"Oscillator period: {(2**18) / phase_increment:.2f} samples")
    print()
    
    # Calculate errors
    errors = output_signed - expected_output
    max_error = np.max(np.abs(errors))
    rms_error = np.sqrt(np.mean(errors**2))
    
    print(f"Maximum absolute error: {max_error} LSBs")
    print(f"RMS error: {rms_error:.3f} LSBs")
    print()
    
    # Detailed comparison for each sample
    print("Sample-by-Sample Comparison:")
    print("-" * 70)
    print(f"{'#':>3} {'Input':>8} {'HW Osc':>8} {'Expected':>10} {'Actual':>10} {'Error':>6} {'Status':>6}")
    print("-" * 70)
    
    all_pass = True
    tolerance = 2  # Allow ±2 LSB error due to rounding/truncation
    
    for i in range(n_samples):
        error = errors[i]
        status = "PASS" if abs(error) <= tolerance else "FAIL"
        if abs(error) > tolerance:
            all_pass = False
        
        print(f"{i:3d} {sample_in_signed[i]:8d} {osc_signed[i]:8d} "
              f"{expected_output[i]:10d} {output_signed[i]:10d} "
              f"{error:6d} {status:>6}")
    
    print("-" * 70)
    
    if all_pass:
        print("\n✓ ALL TESTS PASSED (within ±{} LSB tolerance)".format(tolerance))
        return True
    else:
        print(f"\n✗ SOME TESTS FAILED (errors exceed ±{tolerance} LSB)")
        return False

if __name__ == "__main__":
    csv_file = "ring_mod_output.csv"
    if len(sys.argv) > 1:
        csv_file = sys.argv[1]
    
    success = verify_ring_mod(csv_file)
    sys.exit(0 if success else 1)
