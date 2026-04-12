# Ring Modulator Verification

This directory contains Python scripts for verifying the ring modulator hardware implementation.

## Files

- `verify_ring_mod.py` - Main verification script that compares hardware output to Python reference
- `test_coverage_summary.py` - Documentation of test coverage and methodology
- `effects.py` - Python reference implementation of audio effects including ring_mod

## Usage

### Step 1: Run the SystemVerilog testbench

From the `sv/` directory, run the simulation to generate output CSV:

```bash
cd sv
make ring_mod_tb  # or your simulation command
```

This will create `ring_mod_output.csv` in the sv directory.

### Step 2: Run Python verification

From the project root:

```bash
python python/verify_ring_mod.py sv/ring_mod_output.csv
```

Or if the CSV is in the current directory:

```bash
python python/verify_ring_mod.py
```

### Step 3: View test coverage summary

```bash
python python/test_coverage_summary.py
```

## Expected Output

The verification script will:

1. Read the simulation output CSV
2. Calculate expected values using Python reference implementation
3. Compare hardware vs. expected for each sample
4. Report:
   - Maximum absolute error
   - RMS error
   - Per-sample comparison table
   - Overall PASS/FAIL status

Example output:

```
======================================================================
Ring Modulator Verification
======================================================================

Total samples: 114
Oscillator frequency (normalized): 0.106934
Oscillator period: 9.37 samples

Maximum absolute error: 1 LSBs
RMS error: 0.234 LSBs

Sample-by-Sample Comparison:
----------------------------------------------------------------------
  #    Input   HW Osc   Expected     Actual  Error Status
----------------------------------------------------------------------
  0        0        0          0          0      0   PASS
  1        0      450          0          0      0   PASS
  2        0      899          0          0      0   PASS
...

✓ ALL TESTS PASSED (within ±2 LSB tolerance)
```

## Test Coverage

The testbench runs 114 samples across 11 test sets:

1. **Zero input** (10 samples) - Verify zero output
2. **Small positive** (10 samples) - 1/8 scale amplitude
3. **Medium positive** (10 samples) - 1/2 scale amplitude
4. **Large positive** (10 samples) - 3/4 scale amplitude
5. **Maximum positive** (10 samples) - Full scale
6. **Small negative** (10 samples) - -1/8 scale amplitude
7. **Medium negative** (10 samples) - -1/2 scale amplitude
8. **Large negative** (10 samples) - -3/4 scale amplitude
9. **Maximum negative** (10 samples) - Full negative scale
10. **Alternating** (10 samples) - Rapid polarity changes
11. **Edge cases** (4 samples) - Boundary values

Each 10-sample set covers more than one full oscillator period (~9.38 samples),
ensuring all oscillator phases are tested with each amplitude level.

## Reference Implementation

The Python reference (`effects.py`) implements:

```python
def ring_mod(y, sr, freq=30):
    t = np.arange(len(y)) / sr
    osc = np.sin(2 * np.pi * freq * t)
    return y * osc
```

The hardware implements the same formula where:
- `freq / sr` = accumulator_increment / 2^18 = 27968 / 262144 ≈ 0.1069
- Oscillator is generated using phase accumulator + quarter-phase LUT + symmetry
- Multiplication is 18-bit × 18-bit = 36-bit, extracting bits [28:11]

## Tolerance

The verification allows ±2 LSB error to account for:
- Quantization in the 64-entry sine LUT (Q11 format)
- Bit truncation in multiply output
- Rounding differences between hardware and software
