
import csv
import numpy as np
import soundfile as sf
import sounddevice as sd
from scipy.signal import resample_poly
from fractions import Fraction
from pathlib import Path

# Constants
SR            = 48000   # hardware sample rate (Hz)
DW            = 24      # audio bit depth
RATE_HZ       = 7       # how fast the pitch wobbles
DEPTH_MS      = 1.0     # how wide the wobble is
BASE_DELAY_MS = 2.0     # starting wobble = 2.0ms +/- 1.0ms range

# Sine LUT — identical to ring_mod but tells us how much delay to add at each LFO step
LUT_SIZE  = 64
SIN_BITS  = 18
SIN_MAX   = (1 << (SIN_BITS - 1)) - 1   # 131_071
SIN_SHIFT = SIN_BITS - 1                # 17 fractional bits

SIN_LUT = np.round(
    np.sin(2.0 * np.pi * np.arange(LUT_SIZE) / (LUT_SIZE * 4)) * SIN_MAX
).astype(np.int32)

LFO_INC = int(2**32 * RATE_HZ / SR) # = 625,491 for 7 Hz @ 48 kHz

# Delay buffer
DEPTH_SAMP      = int(round(DEPTH_MS * SR / 1000))      # 48
BASE_DELAY_SAMP = int(round(BASE_DELAY_MS * SR / 1000)) # 96
MAX_DELAY       = BASE_DELAY_SAMP + DEPTH_SAMP          # 144
BUF_LEN         = 256                                   # power of 2; addr wrap = & 0xFF in SV

MAX_VAL = (1 << (DW - 1)) - 1   # +8_388_607
MIN_VAL = -(1 << (DW - 1))      # -8_388_608

# Paths
ROOT    = Path(__file__).resolve().parent.parent
WAV_IN  = ROOT / "wav" / "original"
WAV_OUT = ROOT / "wav" / "vibrato"
CSV_DIR = ROOT / "wav" / "csv"

# Vibrato Algo
def apply_vibrato(samples):
    """
    Algorithm:
      1. Write sample into delay buffer at wr_ptr.
      2. increment LFO phase accumulator & get sine LUT value
      3. Compute fixed-point delay to apply:
              delay_fixed = BASE_DELAY_SAMP * 2^17 + DEPTH_SAMP * lfo
      4. Read two adjacent past samples from the circular buffer:
              rd0 = (wr_ptr - delay_int)     % BUF_LEN
              rd1 = (wr_ptr - delay_int + 1) % BUF_LEN
      5. Linear interpolation:
              y = (s0 * (2^17 - delay_frac) + s1 * delay_frac) >> 17
      6. Advance wr_ptr; saturate output to 24-bit signed range.
    """
    n     = len(samples)
    y     = np.zeros(n, dtype=np.int32)
    buf   = np.zeros(BUF_LEN, dtype=np.int64)
    phase = 0  # 32-bit
    wr    = 0

    for i in range(n):
        # Step 1
        buf[wr] = int(samples[i])

        # Step 2
        p8       = (phase >> 24) & 0xFF # get top 8 bits for LUT indexing
        quadrant = p8 >> 6              # top 2
        offset   = p8 & 63              # bottom 6
        mirror   = bool(quadrant & 1)   # Q1,Q3: read LUT backwards
        negate   = bool(quadrant >> 1)  # Q2,Q3: flip sign
        addr     = (63 - offset) if mirror else offset
        lfo_raw  = int(SIN_LUT[addr])
        lfo      = -lfo_raw if negate else lfo_raw    # ∈ [-131071, +131071]

        # Step 3
        delay_fixed = BASE_DELAY_SAMP * (1 << SIN_SHIFT) + DEPTH_SAMP * lfo
        delay_int   = delay_fixed >> SIN_SHIFT
        delay_frac  = delay_fixed & ((1 << SIN_SHIFT) - 1)

        # Step 4
        rd0 = (wr - delay_int) % BUF_LEN
        rd1 = (rd0 + 1)        % BUF_LEN

        # Step 5
        s0  = buf[rd0]
        s1  = buf[rd1]
        out = (s0 * ((1 << SIN_SHIFT) - delay_frac) + s1 * delay_frac) >> SIN_SHIFT

        y[i] = int(np.clip(out, MIN_VAL, MAX_VAL))

        # Step 6
        wr    = (wr + 1) % BUF_LEN
        phase = (phase + LFO_INC) & 0xFFFFFFFF

    return y

# Helper Functions
def load_mono_48k(path):
    """Read a wav, downmix to mono, resample to 48 kHz, return int32 array."""
    data, sr = sf.read(path, always_2d=True)
    mono = data.mean(axis=1) if data.shape[1] > 1 else data[:, 0]
    if sr != SR:
        ratio = Fraction(SR, sr).limit_denominator(1000)
        mono  = resample_poly(mono, ratio.numerator, ratio.denominator)
    return np.round(np.clip(mono, -1.0, 1.0) * MAX_VAL).astype(np.int32)

def write_csv(samples, path):
    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        for s in samples:
            writer.writerow([int(s)])

def process(wav_path):
    name = wav_path.stem
    print(f"\n── {wav_path.name} ──")

    input_samples  = load_mono_48k(str(wav_path))
    output_samples = apply_vibrato(input_samples)

    print(f"  samples     : {len(input_samples):,}  ({len(input_samples)/SR:.1f} s)")
    print(f"  LFO         : {RATE_HZ} Hz   phase_inc = {LFO_INC}")
    print(f"  delay range : {BASE_DELAY_SAMP - DEPTH_SAMP}..{BASE_DELAY_SAMP + DEPTH_SAMP} samples  "
          f"({BASE_DELAY_MS - DEPTH_MS:.1f}..{BASE_DELAY_MS + DEPTH_MS:.1f} ms)")

    WAV_OUT.mkdir(parents=True, exist_ok=True)
    CSV_DIR.mkdir(parents=True, exist_ok=True)

    write_csv(input_samples,  CSV_DIR / f"{name}_vibrato_input.csv")
    write_csv(output_samples, CSV_DIR / f"{name}_vibrato_output.csv")
    print(f"  CSVs        : wav/csv/{name}_vibrato_input.csv  +  _vibrato_output.csv")

    out_wav = WAV_OUT / f"{name}_vibrato.wav"
    sf.write(str(out_wav), output_samples.astype(np.float32) / MAX_VAL, SR, subtype="PCM_24")
    print(f"  WAV out     : wav/vibrato/{name}_vibrato.wav")

    print("  Playing... (Ctrl-C to skip)")
    try:
        sd.play(output_samples.astype(np.float32) / MAX_VAL, SR, blocking=True)
    except KeyboardInterrupt:
        sd.stop()

if __name__ == "__main__":
    print(f"Vibrato config:  LFO={RATE_HZ} Hz  depth=±{DEPTH_MS} ms  "
          f"base={BASE_DELAY_MS} ms  buf={BUF_LEN} samples")
    wavs = sorted(WAV_IN.glob("*.wav"))
    if not wavs:
        print(f"No .wav files found in {WAV_IN}")
    else:
        for wav in wavs:
            process(wav)
        print("\nDone. CSVs written to wav/csv/ for vibrato_tb.sv.")
