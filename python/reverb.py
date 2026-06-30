
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

# Tweak these
# Comb_delays: Reflection density — larger = more spacious/sparse
# Comb_gain: Main reverb time — raise toward 1.0 for cathedral, lower for tight room
# ap_gain: Diffusion — lower = more discrete echo-y, raise = more smeared/ambient
# Wet_mix: How much reverb you hear

COMB_DELAYS = [1901, 2011, 1723, 1451]   # samples — all prime, ~30–42 ms
AP_DELAYS   = [251, 127]                  # samples — ~5 ms, ~2.6 ms

# Float equivalents shown for reference: COMB≈0.9, AP≈0.80, WET=0.75 exactly.
GAIN_SHIFT       = 10                  # denominator = 1024
COMB_GAIN_NUM    = 922                 # 922/1024 = 0.90039 ≈ 0.90
AP_GAIN_NUM      = 819                 # 819/1024 = 0.79980 ≈ 0.80
WET_NUM          = 768                 # 768/1024 = 0.75 (exact)
DRY_NUM          = 256                 # 256/1024 = 0.25 (exact)

# ── Derived ───────────────────────────────────────────────────────────────────
MAX_VAL = (1 << (DW - 1)) - 1   # +8_388_607
MIN_VAL = -(1 << (DW - 1))      # -8_388_608

# Paths
ROOT    = Path(__file__).resolve().parent.parent
WAV_IN  = ROOT / "wav" / "original"
WAV_OUT = ROOT / "wav" / "reverb"
CSV_DIR = ROOT / "wav" / "csv"

# Algorithm
def apply_reverb(samples):
    """
    Schroeder reverb — integer fixed-point, sample-by-sample streaming.
    Matches SV hardware exactly (same coefficients, same saturation points).

    Signal flow:
      x[n] ──┬──> comb_0 ──┐
             ├──> comb_1 ──┤
             ├──> comb_2 ──┼──> sum >> 2 ──> allpass_0 ──> allpass_1 ──> wet
             └──> comb_3 ──┘
      output = (DRY_NUM*x + WET_NUM*wet) >> GAIN_SHIFT

    Comb filter j  (feedback delay loop):
      past     = comb_buf[j][wr]
      out      = clip(x + (past * COMB_GAIN_NUM) >> GAIN_SHIFT)
      comb_buf = out          ← write saturated value back (feedback)
      wr       = (wr + 1) % COMB_DELAYS[j]

    Allpass filter k  (diffuser):
      buf_out = ap_buf[k][wr]
      v       = clip(wet + (buf_out * AP_GAIN_NUM) >> GAIN_SHIFT)
      ap_out  = clip(buf_out - (v * AP_GAIN_NUM) >> GAIN_SHIFT)
      ap_buf  = v
      wr      = (wr + 1) % AP_DELAYS[k]
    """
    n = len(samples)
    y = np.zeros(n, dtype=np.int64)

    # Comb filter state — int64, values always saturated to 24-bit range
    n_combs  = len(COMB_DELAYS)
    comb_buf = [np.zeros(d, dtype=np.int64) for d in COMB_DELAYS]
    comb_wr  = [0] * n_combs

    # Allpass filter state
    n_aps  = len(AP_DELAYS)
    ap_buf = [np.zeros(d, dtype=np.int64) for d in AP_DELAYS]
    ap_wr  = [0] * n_aps

    for i in range(n):
        x = int(samples[i])

        # ── 4 parallel comb filters ───────────────────────────────────────────
        comb_sum = 0
        for j in range(n_combs):
            past = int(comb_buf[j][comb_wr[j]])
            raw  = x + ((past * COMB_GAIN_NUM) >> GAIN_SHIFT)
            out  = max(MIN_VAL, min(MAX_VAL, raw))
            comb_buf[j][comb_wr[j]] = out
            comb_wr[j]  = (comb_wr[j] + 1) % COMB_DELAYS[j]
            comb_sum   += out

        # sum >> 2  (divide by 4) with saturation
        wet = max(MIN_VAL, min(MAX_VAL, comb_sum >> 2))

        # ── 2 series allpass filters ──────────────────────────────────────────
        for k in range(n_aps):
            buf_out = int(ap_buf[k][ap_wr[k]])
            v       = max(MIN_VAL, min(MAX_VAL, wet + ((buf_out * AP_GAIN_NUM) >> GAIN_SHIFT)))
            ap_out  = max(MIN_VAL, min(MAX_VAL, buf_out - ((v * AP_GAIN_NUM) >> GAIN_SHIFT)))
            ap_buf[k][ap_wr[k]] = v
            ap_wr[k] = (ap_wr[k] + 1) % AP_DELAYS[k]
            wet      = ap_out

        # ── Dry/wet mix ───────────────────────────────────────────────────────
        mixed = (DRY_NUM * x + WET_NUM * wet) >> GAIN_SHIFT
        y[i]  = max(MIN_VAL, min(MAX_VAL, mixed))

    return y.astype(np.int32)

# ── Helpers ───────────────────────────────────────────────────────────────────
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
    output_samples = apply_reverb(input_samples)

    denom       = 1 << GAIN_SHIFT
    comb_gain_f = COMB_GAIN_NUM / denom
    ap_gain_f   = AP_GAIN_NUM   / denom
    rt60_ms     = [-3.0 * d / (SR * np.log10(comb_gain_f)) * 1000 for d in COMB_DELAYS]
    print(f"  samples      : {len(input_samples):,}  ({len(input_samples)/SR:.1f} s)")
    print(f"  comb delays  : {COMB_DELAYS}  ({[f'{d/SR*1000:.1f}' for d in COMB_DELAYS]} ms)")
    print(f"  comb gain    : {COMB_GAIN_NUM}/{denom} ≈ {comb_gain_f:.4f}  (RT60 ≈ {np.mean(rt60_ms):.0f} ms avg)")
    print(f"  allpass      : delays={AP_DELAYS}  gain={AP_GAIN_NUM}/{denom} ≈ {ap_gain_f:.4f}")
    print(f"  wet mix      : {WET_NUM}/{denom} = {WET_NUM/denom:.0%}")

    WAV_OUT.mkdir(parents=True, exist_ok=True)
    CSV_DIR.mkdir(parents=True, exist_ok=True)

    write_csv(input_samples,  CSV_DIR / f"{name}_reverb_input.csv")
    write_csv(output_samples, CSV_DIR / f"{name}_reverb_output.csv")
    print(f"  CSVs         : wav/csv/{name}_reverb_input.csv  +  _reverb_output.csv")

    out_wav = WAV_OUT / f"{name}_reverb.wav"
    sf.write(str(out_wav), output_samples.astype(np.float32) / MAX_VAL, SR, subtype="PCM_24")
    print(f"  WAV out      : wav/reverb/{name}_reverb.wav")

    print("  Playing... (Ctrl-C to skip)")
    try:
        sd.play(output_samples.astype(np.float32) / MAX_VAL, SR, blocking=True)
    except KeyboardInterrupt:
        sd.stop()

if __name__ == "__main__":
    denom = 1 << GAIN_SHIFT
    print(f"Reverb config:  {len(COMB_DELAYS)} combs  gain={COMB_GAIN_NUM}/{denom}≈{COMB_GAIN_NUM/denom:.4f}  "
          f"{len(AP_DELAYS)} allpass  wet={WET_NUM/denom:.0%}")
    wavs = sorted(WAV_IN.glob("*.wav"))
    if not wavs:
        print(f"No .wav files found in {WAV_IN}")
    else:
        for wav in wavs:
            process(wav)
        print("\nDone. CSVs written to wav/csv/ for reverb_tb.sv.")
