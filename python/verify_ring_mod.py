import sys

import numpy as np


AUDIO_W = 24
FRAC_W = 23
PHASE_W = 18
PHASE_INCREMENT = 27968


def read_simulation_output(filename):
    """
    Read CSV output from SystemVerilog testbench.
    Expected format: sample_num,sample_in,phase,osc,output
    """
    data = np.loadtxt(filename, delimiter=",", skiprows=1, dtype=np.int64)
    return {
        "sample_num": data[:, 0],
        "sample_in": data[:, 1],
        "phase": data[:, 2],
        "osc": data[:, 3],
        "output": data[:, 4],
    }


def signed_nbit(val, width):
    """Convert an unsigned n-bit value to signed; leave signed CSV values intact."""
    val = int(val)
    if val < 0:
        return val
    sign_bit = 1 << (width - 1)
    full_scale = 1 << width
    if val >= sign_bit:
        return val - full_scale
    return val


def q23_sine_from_phase(phase):
    quadrant = (phase >> 16) & 0x3
    lut_index = (phase >> 10) & 0x3F

    if quadrant & 0x1:
        lut_index = 0x3F - lut_index

    theta = lut_index * (np.pi / 2) / 63
    osc = int(np.round(np.sin(theta) * (1 << FRAC_W)))
    osc = min(max(osc, -(1 << FRAC_W)), (1 << FRAC_W) - 1)

    if quadrant & 0x2:
        osc = -osc
    return osc


def verify_ring_mod(csv_file):
    """
    Verify hardware ring modulator output against a Q1.23 Python reference.
    """
    print("=" * 70)
    print("Ring Modulator Verification")
    print("=" * 70)

    try:
        sim_data = read_simulation_output(csv_file)
    except FileNotFoundError:
        print(f"ERROR: Could not find {csv_file}")
        print("Run the simulation first to generate output CSV")
        return False

    sample_in_signed = np.array(
        [signed_nbit(x, AUDIO_W) for x in sim_data["sample_in"]], dtype=np.int64
    )
    osc_signed = np.array(
        [signed_nbit(x, AUDIO_W) for x in sim_data["osc"]], dtype=np.int64
    )
    output_signed = np.array(
        [signed_nbit(x, AUDIO_W) for x in sim_data["output"]], dtype=np.int64
    )

    phase = np.array(sim_data["phase"], dtype=np.int64) & ((1 << PHASE_W) - 1)
    osc_expected = np.array([q23_sine_from_phase(x) for x in phase], dtype=np.int64)

    expected_full = sample_in_signed * osc_expected
    expected_output = expected_full >> FRAC_W
    expected_output = np.clip(expected_output, -(1 << FRAC_W), (1 << FRAC_W) - 1)

    freq_normalized = PHASE_INCREMENT / (2**PHASE_W)
    print(f"\nTotal samples: {len(sample_in_signed)}")
    print(f"Oscillator frequency (normalized): {freq_normalized:.6f}")
    print(f"Oscillator period: {(2**PHASE_W) / PHASE_INCREMENT:.2f} samples")
    print()

    errors = output_signed - expected_output
    max_error = np.max(np.abs(errors))
    rms_error = np.sqrt(np.mean(errors**2))

    print(f"Maximum absolute error: {max_error} LSBs")
    print(f"RMS error: {rms_error:.3f} LSBs")
    print()

    print("Sample-by-Sample Comparison:")
    print("-" * 78)
    print(
        f"{'#':>3} {'Input':>10} {'HW Osc':>10} {'Exp Osc':>10} "
        f"{'Expected':>10} {'Actual':>10} {'Error':>6} {'Status':>6}"
    )
    print("-" * 78)

    all_pass = True
    tolerance = 2

    for i in range(len(sample_in_signed)):
        error = errors[i]
        status = "PASS" if abs(error) <= tolerance else "FAIL"
        if abs(error) > tolerance:
            all_pass = False

        print(
            f"{i:3d} {sample_in_signed[i]:10d} {osc_signed[i]:10d} "
            f"{osc_expected[i]:10d} {expected_output[i]:10d} "
            f"{output_signed[i]:10d} {error:6d} {status:>6}"
        )

    print("-" * 78)

    if all_pass:
        print(f"\nALL TESTS PASSED (within +/-{tolerance} LSB tolerance)")
        return True

    print(f"\nSOME TESTS FAILED (errors exceed +/-{tolerance} LSB)")
    return False


if __name__ == "__main__":
    csv_file = "ring_mod_output.csv"
    if len(sys.argv) > 1:
        csv_file = sys.argv[1]

    success = verify_ring_mod(csv_file)
    sys.exit(0 if success else 1)
