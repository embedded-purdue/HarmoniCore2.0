
import csv
import numpy as np
import soundfile as sf
import sounddevice as sd
from scipy.signal import resample_poly
from fractions import Fraction
from pathlib import Path

# Constants
SR           = 48000           # hardware sample rate (Hz)
DW           = 24              # audio bit depth
CARRIER_FREQ = 256             # ring mod carrier (Hz)
LUT_SIZE     = 64              # quarter-wave sine table entries (2^6)
SIN_BITS     = 18             # sine LUT bit width -- matches DSP48 B-input (25x18)
SIN_MAX      = (1 << (SIN_BITS - 1)) - 1  # +131_071  (18-bit signed max)
SIN_SHIFT    = SIN_BITS - 1               # 17  (right-shift to undo LUT scaling)
MAX_VAL      = (1 << 23) - 1  # +8_388_607  (24-bit signed max)
MIN_VAL      = -(1 << 23)     # -8_388_608  (24-bit signed min)
PHASE_INC = int(2**32 * CARRIER_FREQ / SR)  # = 22,906,492 for 256 Hz @ 48 kHz
SIN_LUT = np.round(
    np.sin(2.0 * np.pi * np.arange(LUT_SIZE) / (LUT_SIZE * 4)) * SIN_MAX
).astype(np.int32)

# Paths
ROOT    = Path(__file__).resolve().parent.parent
WAV_IN  = ROOT / "wav" / "original"
WAV_OUT = ROOT / "wav" / "ring_mod"
CSV_DIR = ROOT / "wav" / "csv"

# Functions
def load_mono_48k(path):
    """Read a wav file, downmix to mono (from stereo), resample to 48 kHz, return int32 array."""
    data, sr = sf.read(path, always_2d=True)
    mono = data.mean(axis=1) if data.shape[1] > 1 else data[:, 0]
    if sr != SR:
        ratio = Fraction(SR, sr).limit_denominator(1000)
        mono  = resample_poly(mono, ratio.numerator, ratio.denominator)
    return np.round(np.clip(mono, -1.0, 1.0) * MAX_VAL).astype(np.int32)

def apply_ring_mod(samples):
    """
    Multiply each sample by a 256 Hz sine value using a quarter-wave LUT.

    Algorithm:
      1. Phase accumulator: phase[i] = (i * PHASE_INC) mod 2^32
      2. Top 8 bits of phase split into:
             quadrant [7:6]  -- which 90° sector (0-3)
             offset   [5:0]  -- position within that sector (0-63)
      3. Quarter-wave reconstruction:
             mirror  = quadrant bit 0  --> read LUT backwards when set
             negate  = quadrant bit 1  --> flip sign when set
             addr    = mirror ? (63 - offset) : offset
             carrier = negate ? -LUT[addr] : +LUT[addr]
      4. Multiply + scale: (sample * carrier) >> 15
      5. Saturate to 24-bit signed range
    """
    n = len(samples)
    phase = (np.arange(n, dtype=np.uint64) * np.uint64(PHASE_INC)) & np.uint64(0xFFFFFFFF)

    # Split top 8 bits into quadrant (2 bits) and offset within quadrant (6 bits)
    phase8   = (phase >> np.uint64(24)).astype(np.uint32)   # 0-255
    quadrant = phase8 >> 6                                  # 0-3
    offset   = phase8 & 63                                  # 0-63

    mirror = (quadrant & 1).astype(bool)   # quadrant bit 0 → read LUT backwards
    negate = (quadrant >> 1).astype(bool)  # quadrant bit 1 → flip sign

    addr    = np.where(mirror, 63 - offset, offset).astype(np.intp)
    carrier = SIN_LUT[addr].astype(np.int64)
    carrier = np.where(negate, -carrier, carrier)

    product = samples.astype(np.int64) * carrier
    result  = product >> SIN_SHIFT     # undo the x131071 LUT scaling

    return np.clip(result, MIN_VAL, MAX_VAL).astype(np.int32)

def write_csv(samples, path):
    """Write one integer sample per line."""
    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        for s in samples:
            writer.writerow([int(s)])

def process(wav_path):
    """Load one wav, apply ring mod, save outputs, play back."""
    name = wav_path.stem
    print(f"\n── {wav_path.name} ──")

    input_samples  = load_mono_48k(str(wav_path))
    output_samples = apply_ring_mod(input_samples)

    print(f"  samples : {len(input_samples):,}  ({len(input_samples)/SR:.1f}s)")
    print(f"  carrier : {CARRIER_FREQ} Hz   phase_inc = {PHASE_INC}")

    # Save CSVs for the SV testbench
    WAV_OUT.mkdir(parents=True, exist_ok=True)
    CSV_DIR.mkdir(parents=True, exist_ok=True)

    write_csv(input_samples,  CSV_DIR / f"{name}_input.csv")
    write_csv(output_samples, CSV_DIR / f"{name}_output.csv")
    print(f"  CSVs    : wav/csv/{name}_input.csv  +  _output.csv")

    # Save processed wav
    out_wav = WAV_OUT / f"{name}_ring_mod.wav"
    sf.write(str(out_wav), output_samples.astype(np.float32) / MAX_VAL, SR, subtype="PCM_24")
    print(f"  WAV out : wav/ring_mod/{name}_ring_mod.wav")

    # Play
    print("  Playing... (Ctrl-C to skip)")
    try:
        sd.play(output_samples.astype(np.float32) / MAX_VAL, SR, blocking=True)
    except KeyboardInterrupt:
        sd.stop()

if __name__ == "__main__":
    wavs = sorted(WAV_IN.glob("*.wav"))
    if not wavs:
        print(f"No .wav files found in {WAV_IN}")
    else:
        for wav in wavs:
            process(wav)
        print("\nDone. CSVs written to wav/csv/ for ring_mod_tb.sv.")
