import librosa
import numpy as np
from scipy.signal import butter, lfilter, fftconvolve
from scipy.signal import hilbert
import soundfile as sf
from scipy.signal import fftconvolve
import csv

def load_audio(path, sr=44100):
    y, sr = librosa.load(path, sr=sr, mono=True)
    return y, sr

def save_audio(path, y, sr):
    if np.max(np.abs(y)) > 0:
        y = y / np.max(np.abs(y))
    
    sf.write(path, y, sr)

#Distortion / Overdrive
def distortion(y, amount=100):
    return np.tanh(amount * y)

# Vocoder (robot voice)
def vocoder_robot(y, sr, carrier_freq=500):
    t = np.arange(len(y)) / sr
    carrier = np.sin(2 * np.pi * carrier_freq * t)

    analytic = hilbert(y)
    amplitude_envelope = np.abs(analytic)

    return amplitude_envelope * carrier

# Shimmer Reverb (Reverb + Octave Up)
def shimmer_reverb(y, sr, decay=0.5):
    ir_len = int(sr * 0.3)
    ir = decay * np.exp(-np.linspace(0, 3, ir_len))
    base_rev = fftconvolve(y, ir, mode='full')[:len(y)]
    shimmer = librosa.effects.pitch_shift(y=base_rev, sr=sr, n_steps=12)
    shimmer = shimmer[:len(y)]
    return 0.6 * y + 0.4 * shimmer

# Telephone / Radio Voice
def telephone_voice(y, sr):
    low = 500 / (sr / 2)
    high = 3000 / (sr / 2)
    b, a = butter(4, [low, high], btype='band')
    return lfilter(b, a, y)

#Chorus (multi-voice detuned delay)
def chorus(y, sr, depth_ms=15, rate=0.3):
    depth = int(sr * depth_ms / 1000)
    t = np.arange(len(y))
    lfo = depth * (1 + np.sin(2 * np.pi * rate * t / sr))  # 0 → 2*depth

    y_out = np.zeros_like(y)

    for i in range(len(y)):
        d = int(lfo[i])
        idx = i - d
        if idx < 0:
            y_out[i] = y[i]
        else:
            y_out[i] = (y[i] + y[idx]) * 0.5

    return y_out

# Ring Modulation (robot/alien tremolo)
def ring_mod(y, sr, freq=30):
    t = np.arange(len(y)) / sr
    osc = np.sin(2 * np.pi * freq * t)
    return y * osc

def echo(y, sr, delay_ms=300, feedback=0.4, mix=0.5):  #Mess with params
    delay = int(sr * delay_ms / 1000)
    out = np.copy(y).astype(float)

    for i in range(delay, len(y)):
        out[i] += feedback * out[i - delay]

    return (1 - mix) * y + mix * out

def reverb(y, sr, decay=0.5, room_size=2, mix=0.4):
    ir_len = int(sr * room_size)
    ir = decay * np.exp(-np.linspace(0, 4, ir_len))

    rev = fftconvolve(y, ir, mode="full")[:len(y)]
    return (1 - mix) * y + mix * rev

def harmonic_chorus(y, sr, depth_ms=12, rate=0.25, harmonics_amount=0.3):
    depth = int(sr * depth_ms / 1000)
    t = np.arange(len(y))
    lfo = depth * (1 + np.sin(2 * np.pi * rate * t / sr))

    out = np.zeros_like(y)
    for i in range(len(y)):
        d = int(lfo[i])
        idx = i - d
        out[i] = (y[i] + (y[idx] if idx >= 0 else y[i])) * 0.5

    harm = np.tanh(2 * out) - 0.5 * np.tanh(out)

    return (1 - harmonics_amount) * out + harmonics_amount * harm

def vibrato(x, sr, depth=0.0003, rate=5.0): #Mess with params

    n = len(x)
    t = np.arange(n) / sr
    delay = depth * np.sin(2 * np.pi * rate * t)
    delay_samples = delay * sr
    y = np.zeros_like(x)

    for i in range(n):
        idx = i - delay_samples[i]
        if idx < 0:
            y[i] = x[0]
            continue
        i0 = int(np.floor(idx))
        i1 = min(i0 + 1, n - 1)

        frac = idx - i0
        y[i] = (1 - frac) * x[i0] + frac * x[i1]

    return y, delay

def vibrato_hw(x, sr, rate_hz=5.0, depth_ms=5.0,base_delay_ms=5.0):
    n = len(x)

    # constants
    max_delay = int((base_delay_ms + depth_ms) * sr / 1000) # 441 maximum number of past samples we need | delay = base_delay +- depth
    base_delay = base_delay_ms * sr / 1000 # 0.005
    depth = depth_ms * sr / 1000 # 220.5

    # Delay buffer (RAM-based FIFO buffer))
    delay_buf = np.zeros(max_delay + 2) # 443
    buf_len = len(delay_buf) # 443
    wr_ptr = 0

    # Phase accumulator (NCO) (constant)
    phase = 0.0
    phase_inc = 2 * np.pi * rate_hz / sr # 0.0007124

    y = np.zeros_like(x)
    temp_delay = np.zeros_like(x)

    # random access into past samples to create vibrato effect
    for i in range(n):
        delay_buf[wr_ptr] = x[i]

        # LFO
        lfo = np.sin(phase)
        phase += phase_inc
        if phase > 2 * np.pi:
            phase -= 2 * np.pi

        # Time-varying delay
        delay = base_delay + depth * lfo # 220.505 const coeff * lfo

        # Read pointer
        rd_ptr = wr_ptr - delay # jumps all over the place
        while rd_ptr < 0:
            rd_ptr += buf_len

        # Linear interpolation if rd_ptr is fractional
        i0 = int(np.floor(rd_ptr))
        i1 = (i0 + 1) % buf_len
        frac = rd_ptr - i0
        y[i] = (1 - frac) * delay_buf[i0] + frac * delay_buf[i1]
        # y[i] = 0.5 * delay_buf[i0] + 0.5 * delay_buf[i1]

        # Increment write pointer
        wr_ptr = (wr_ptr + 1) % buf_len # this one always moves forward then wraps for new sample

        # add delay amount to array
        temp_delay[i] = delay

    return y, temp_delay

# ----------------------------------------------------
# Example pipeline
# ----------------------------------------------------
if __name__ == '__main__':
    #y, sr = load_audio("wav/original/nothingonyou.wav")
    y, sr = load_audio("wav/original/teenagefever.wav")

    y_out, delay_ref = vibrato(y, sr, depth=0.0004, rate=3.0)
    y_out2, delay_hw = vibrato_hw(y, sr, rate_hz=3.0, depth_ms=4.0, base_delay_ms=4.0)

    filename = "compare_vibrato.csv"
    with open(filename, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["sample", "delay_ref_samples", "delay_hw_samples", "difference"])

        for i in range(len(delay_ref)):
            writer.writerow([
                i,
                delay_ref[i],
                delay_hw[i],
                delay_hw[i] - delay_ref[i]
            ])


    # save_audio("vibrato2.wav", y_out, sr)
    # save_audio("vibrato_hw2.wav", y_out2, sr)
    # print("Saved audio to all effects files")