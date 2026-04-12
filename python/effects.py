import librosa
import numpy as np
from scipy.signal import butter, lfilter, fftconvolve
from scipy.signal import hilbert
import soundfile as sf
from scipy.signal import fftconvolve

def load_audio(path, sr=44100):
    y, sr = librosa.load(path, sr=sr, mono=True)
    return y, sr


def save_audio(path, y, sr):
    if np.max(np.abs(y)) > 0:
        y = y / np.max(np.abs(y))
    
    sf.write(path, y, sr)


#Distortion / Overdrive
def distortion(y, amount=64):
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

    return y



# ----------------------------------------------------
# Example pipeline
# ----------------------------------------------------
if __name__ == '__main__':
    y, sr = load_audio("./wav/nothingonyou.wav")

    y_out = harmonic_chorus(y, sr)
    y_out = echo(y_out, sr)
    y_out = reverb(y_out, sr)
    y_out = vibrato(y, sr)

    save_audio("out.wav", y_out, sr)
