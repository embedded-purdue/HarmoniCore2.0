
import csv
import numpy as np
import soundfile as sf
import sounddevice as sd
from scipy.signal import resample_poly
from fractions import Fraction
from pathlib import Path

# Constants
SR = 48000  # hardware sample rate (Hz)
DW = 24     # audio bit depth

# Tweak these to change the echo character
DELAY_MS       = 300    # ms between echoes  (300 ms → 14,400 samples @ 48 kHz)
FEEDBACK_SHIFT = 1      # each echo = previous / 2^FEEDBACK_SHIFT
                        #   1 → 50% (lush, can clip on sustained loud signals)
                        #   2 → 25% (safe default, ~3 audible echoes)
                        #   3 → 12.5% (subtle slapback feel)

# ── Derived ──────────────────────────────────────────────────────────────────
DELAY_SAMP = int(round(DELAY_MS * SR / 1000))   # 14,400 at defaults
MAX_VAL    = (1 << (DW - 1)) - 1                # +8,388,607
MIN_VAL    = -(1 << (DW - 1))                   # -8,388,608

# ── Paths ────────────────────────────────────────────────────────────────────
ROOT    = Path(__file__).resolve().parent.parent
WAV_IN  = ROOT / "wav" / "original"
WAV_OUT = ROOT / "wav" / "echo"
CSV_DIR = ROOT / "wav" / "csv"

# Algorithm
def apply_echo(samples):
    """
    Streaming feedback echo, designed to mirror BRAM-based SV hardware.

    Algorithm (one sample at a time):
      1. Circular buffer length == DELAY_SAMP.
         Position wr always holds the sample written exactly DELAY_SAMP steps
         ago, so no separate read pointer is needed.
      2. Read past output: past = buf[wr]
      3. Compute: out = input + (past >> FEEDBACK_SHIFT)   (integer bit-shift)
      4. Saturate out to 24-bit signed range.
      5. Write out back to buf[wr]  (feedback: echoes of echoes)
      6. Advance wr = (wr + 1) % DELAY_SAMP

    SV mapping:
      - buf   → single-port BRAM, depth = DELAY_SAMP, width = DW
      - wr    → address register, wraps at DELAY_SAMP
      - step 2/5 → read-first BRAM port (read old value, then write new)
      - step 3 → one adder + arithmetic right-shift (no multiplier needed)
      - step 4 → signed saturation logic
    """
    n   = len(samples)
    y   = np.zeros(n, dtype=np.int64)
    buf = np.zeros(DELAY_SAMP, dtype=np.int64)
    wr  = 0

    for i in range(n):
        past = buf[wr]                                        # step 2
        raw  = int(samples[i]) + (past >> FEEDBACK_SHIFT)    # step 3
        out  = int(np.clip(raw, MIN_VAL, MAX_VAL))           # step 4
        y[i] = out
        buf[wr] = out                                         # step 5
        wr = (wr + 1) % DELAY_SAMP                           # step 6

    return y.astype(np.int32)

# ── Helpers ──────────────────────────────────────────────────────────────────
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
    output_samples = apply_echo(input_samples)

    print(f"  samples        : {len(input_samples):,}  ({len(input_samples)/SR:.1f} s)")
    print(f"  delay          : {DELAY_MS} ms  ({DELAY_SAMP} samples)")
    print(f"  feedback       : 1/{2**FEEDBACK_SHIFT}  (>> {FEEDBACK_SHIFT})")

    WAV_OUT.mkdir(parents=True, exist_ok=True)
    CSV_DIR.mkdir(parents=True, exist_ok=True)

    write_csv(input_samples,  CSV_DIR / f"{name}_echo_input.csv")
    write_csv(output_samples, CSV_DIR / f"{name}_echo_output.csv")
    print(f"  CSVs           : wav/csv/{name}_echo_input.csv  +  _echo_output.csv")

    out_wav = WAV_OUT / f"{name}_echo.wav"
    sf.write(str(out_wav), output_samples.astype(np.float32) / MAX_VAL, SR, subtype="PCM_24")
    print(f"  WAV out        : wav/echo/{name}_echo.wav")

    print("  Playing... (Ctrl-C to skip)")
    try:
        sd.play(output_samples.astype(np.float32) / MAX_VAL, SR, blocking=True)
    except KeyboardInterrupt:
        sd.stop()

if __name__ == "__main__":
    print(f"Echo config:  delay={DELAY_MS} ms ({DELAY_SAMP} samples)  "
          f"feedback=1/{2**FEEDBACK_SHIFT} (shift {FEEDBACK_SHIFT})")
    wavs = sorted(WAV_IN.glob("*.wav"))
    if not wavs:
        print(f"No .wav files found in {WAV_IN}")
    else:
        for wav in wavs:
            process(wav)
        print("\nDone. CSVs written to wav/csv/ for echo_tb.sv.")
