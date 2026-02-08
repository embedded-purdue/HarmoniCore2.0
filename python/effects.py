import librosa
import numpy as np
import soundfile as sf

def load_audio(path, sr=44100):
    y, sr = librosa.load(path, sr=sr, mono=True)
    return y, sr

def save_audio(path, y, sr):
    if np.max(np.abs(y)) > 0:
        y = y / np.max(np.abs(y))
    
    sf.write(path, y, sr)

# Ring Modulation - Original
def ring_mod(y, sr, freq=10):
    t = np.arange(len(y)) / sr
    osc = np.sin(2 * np.pi * freq * t)
    return y * osc

def ring_mod_hw(frames, sr, freq=10):
    frame_length = frames.shape[0]
    num_frames = frames.shape[1]
    y_out = np.zeros(frame_length * num_frames)

    # Phase Accumulator
    phase = 0.0
    phase_inc = 2 * np.pi * freq / sr

    out_idx = 0
    for k in range(num_frames):
        f = frames[:, k]
        y_frame = np.zeros_like(f)

        for i in range(frame_length):
            osc = np.sin(phase)
            phase += phase_inc
            if phase >= 2 * np.pi:
                phase -= 2 * np.pi

            y_frame[i] = f[i] * osc

        y_out[out_idx:out_idx + frame_length] = y_frame
        out_idx += frame_length

    return y_out

phase = 0.0
phase_inc = 13.65625 # 10 Hz at 44100 Hz sample rate
def ring_mod_pure_hardware(sample):
    osc = np.sin(phase)
    phase += phase_inc
    if phase >= 2**16:
        phase -= 2**16
    
    sample_out = sample * osc
    return sample_out

def vibrato_hw_frames(frames, sr, rate_hz=7.0, depth_ms=1.0, base_delay_ms=2.0, lut_size=256):
    """
    Hardware-optimized vibrato effect for frames.
    
    - Uses sine lookup table for LFO
    - Circular buffer for delay line
    - Linear interpolation for fractional delays
    - All multiplications are by fixed constants (pre-computed)
    - No slow operations like sin() or complex divisions
    
    Args:
        frames: array of shape (frame_length, num_frames)
        sr: sample rate
        rate_hz: LFO frequency in Hz
        depth_ms: depth of vibrato in milliseconds
        base_delay_ms: base delay in milliseconds
        lut_size: size of sine lookup table
    
    Returns:
        y_out: vibrato-affected signal
        delay_amounts: delay values for each sample (for debugging)
    """
    # frame_length = frames.shape[0]
    # num_frames = frames.shape[1]
    # total_samples = frame_length * num_frames
    
    # y_out = np.zeros(total_samples)
    # delay_amounts = np.zeros(total_samples)
    
    # # Pre-computed constants (done once, not per-sample)
    # sin_lut = create_sin_lut(lut_size)
    # max_delay_samples = int((base_delay_ms + depth_ms) * sr / 1000)
    # base_delay_samples = base_delay_ms * sr / 1000
    # depth_samples = depth_ms * sr / 1000
    
    # # Phase increment for NCO (Numerically Controlled Oscillator)
    # phase_inc = (rate_hz / sr) * lut_size
    # phase = 0
    
    # # Circular delay buffer
    # delay_buf = np.zeros(max_delay_samples + 2)
    # buf_len = len(delay_buf)
    # wr_ptr = 0
    
    # out_idx = 0
    
    # for k in range(num_frames):
    #     f = frames[:, k]
        
    #     for i in range(frame_length):
    #         # Write current sample to delay buffer
    #         delay_buf[wr_ptr] = f[i]
            
    #         # Get LFO value from sine lookup table
    #         phase_idx = int(phase) % lut_size
    #         lfo = sin_lut[phase_idx]
    #         phase += phase_inc
    #         if phase >= lut_size:
    #             phase -= lut_size
            
    #         # Calculate delay (base + depth * lfo)
    #         # This is one multiplication with pre-computed depth_samples
    #         delay = base_delay_samples + depth_samples * lfo
            
    #         # Calculate read pointer (circular)
    #         rd_ptr = wr_ptr - delay
    #         while rd_ptr < 0:
    #             rd_ptr += buf_len
            
    #         # Linear interpolation for fractional delay
    #         i0 = int(np.floor(rd_ptr))
    #         i1 = (i0 + 1) % buf_len
    #         frac = rd_ptr - i0
    #         y_out[out_idx] = (1 - frac) * delay_buf[i0] + frac * delay_buf[i1]
    #         delay_amounts[out_idx] = delay
            
    #         # Advance write pointer (circular)
    #         wr_ptr = (wr_ptr + 1) % buf_len
    #         out_idx += 1
    
    # return y_out, delay_amounts

# Vibrato - Original
def vibrato(x, sr, depth=0.001, rate=7.0):
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

# DEPRECATED: Use vibrato_hw_frames instead
# def vibrato_framed was removed - use vibrato_hw_frames for frame-based processing
    
def vibrato_hw(x, sr, rate_hz=7.0, depth_ms=1.0,base_delay_ms=2.0):
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
    y, sr = load_audio("wav/original/nothingonyou.wav")

    # split up into frames to mirror hardware (1024 samples per frame)
    frame_length = 128
    frames = librosa.util.frame(y, frame_length=frame_length, hop_length=frame_length)

    # Test hardware-optimized ring modulation
    print("Processing ring modulation (hardware-optimized)...")
    y_ring_hw = ring_mod_hw(frames, sr, freq=10)
    save_audio("ring_mod_hw.wav", y_ring_hw, sr)
    
    # # Test hardware-optimized vibrato
    # print("Processing vibrato (hardware-optimized)...")
    # y_vibrato_hw, delays = vibrato_hw_frames(frames, sr, rate_hz=7.0, depth_ms=1.0, base_delay_ms=2.0)
    # save_audio("vibrato_hw.wav", y_vibrato_hw, sr)
    
    print("Output files saved!")
    print(f"Ring mod: ring_mod_hw.wav")
    # print(f"Vibrato: vibrato_hw.wav")