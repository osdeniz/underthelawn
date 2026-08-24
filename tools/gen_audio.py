#!/usr/bin/env python3
"""Placeholder audio generator (G9.2). Writes every file the game looks for into
audio/ as 22050 Hz mono 16-bit WAV, synthesized offline — the G1 rule forbids
RUNTIME synthesis, not generated assets; a real .ogg recording dropped in later
silently replaces any of these because AudioDirector tries .ogg first.

Deterministic (seeded), so re-running produces identical files.
Run: /opt/homebrew/bin/python3 tools/gen_audio.py
"""
import math, random, struct, wave, os

SR = 22050
rng = random.Random(20260824)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")


def write(name, samples, gain=1.0):
    peak = max(1e-9, max(abs(s) for s in samples))
    norm = gain / peak
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * norm)) * 32000))
                    for s in samples)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("  %-24s %5.1f sn  %4d KB" % (name, len(samples) / SR,
                                        os.path.getsize(path) // 1024))


def seconds(t):
    return int(t * SR)


def env_exp(n, decay):
    return [math.exp(-decay * i / SR) for i in range(n)]


# ---- mower engine loop: harmonic stack + firing-rate throb, exact-cycle loop.
def engine():
    f0 = 55.0
    cycles = round(2.0 * f0)              # whole cycles -> seamless loop
    n = int(cycles / f0 * SR)
    out = []
    for i in range(n):
        t = i / SR
        v = (math.sin(TAU * f0 * t) * 0.5 + math.sin(TAU * f0 * 2 * t) * 0.3
             + math.sin(TAU * f0 * 3 * t) * 0.14 + math.sin(TAU * f0 * 4.02 * t) * 0.07)
        throb = 0.78 + 0.22 * math.sin(TAU * 27.5 * t)   # f0/2: shares the period
        out.append(v * throb + (rng.random() - 0.5) * 0.10)
    return out


# ---- one grass-cut swish: shaped noise through a crude lowpass.
def cut():
    n = seconds(0.30)
    out, lp = [], 0.0
    for i in range(n):
        t = i / n
        amp = math.sin(math.pi * min(1.0, t * 1.25)) ** 2
        lp += ((rng.random() - 0.5) - lp) * 0.28
        out.append(lp * amp)
    return out


# ---- discovery: two soft bell notes.
def bell(freq, dur, strike=1.0):
    n = seconds(dur)
    out = []
    for i in range(n):
        t = i / SR
        v = (math.sin(TAU * freq * t) * 0.6
             + math.sin(TAU * freq * 2.76 * t) * 0.25 * math.exp(-6 * t)
             + math.sin(TAU * freq * 5.40 * t) * 0.12 * math.exp(-10 * t))
        out.append(v * math.exp(-3.2 * t) * strike)
    return out


def discovery():
    a = bell(659.25, 1.2)
    b = bell(880.0, 1.4, 0.9)
    n = seconds(1.7)
    out = [0.0] * n
    for i, v in enumerate(a):
        out[i] += v
    for i, v in enumerate(b):
        j = i + seconds(0.28)
        if j < n:
            out[j] += v
    return out


# ---- money pickup: two-tone cash blip (E6 -> B6), the arcade coin grammar.
def pickup():
    n = seconds(0.30)
    out = [0.0] * n
    for start, freq in ((0.0, 1318.5), (0.07, 1975.5)):
        for i in range(seconds(0.20)):
            t = i / SR
            j = seconds(start) + i
            if j >= n:
                break
            v = math.sin(TAU * freq * t) * 0.7 + math.sin(TAU * freq * 2 * t) * 0.2
            out[j] += v * math.exp(-16 * t)
    return out


# ---- blade vs stone: inharmonic clank.
def clank():
    n = seconds(0.38)
    out = []
    for i in range(n):
        t = i / SR
        v = (math.sin(TAU * 812 * t) * 0.5 + math.sin(TAU * 1347 * t) * 0.32
             + math.sin(TAU * 2115 * t) * 0.18)
        v += (rng.random() - 0.5) * 0.5 * math.exp(-120 * t)
        out.append(v * math.exp(-14 * t))
    return out


# ---- a single bird chirp: two swept syllables with vibrato.
def chirp(base=2900.0):
    out = []
    for start, dur, up in ((0.0, 0.16, 500), (0.24, 0.20, -350)):
        n = seconds(dur)
        phase = 0.0
        for i in range(n):
            t = i / SR
            f = base + up * (t / dur) + 60 * math.sin(TAU * 38 * t)
            phase += TAU * f / SR
            out_i = int((start) * SR) + i
            while len(out) <= out_i:
                out.append(0.0)
            out[out_i] += math.sin(phase) * math.sin(math.pi * t / dur) ** 1.5
    out.extend([0.0] * seconds(0.15))
    return out


# ---- ambient: soft wind bed + sparse chirps, loop-safe.
def ambient():
    n = seconds(14.0)
    out, lp = [], 0.0
    for i in range(n):
        t = i / SR
        lp += ((rng.random() - 0.5) - lp) * 0.045
        sway = 0.55 + 0.45 * math.sin(TAU * t / 14.0)   # whole cycle -> loops
        out.append(lp * 0.8 * sway)
    for start, pitch in ((2.2, 2900), (6.1, 3400), (10.4, 2600)):
        c = chirp(pitch)
        for i, v in enumerate(c):
            j = seconds(start) + i
            if j < n:
                out[j] += v * 0.16
    return out


# ---- car pass: swell + doppler-ish pitch drop.
def car():
    n = seconds(2.4)
    out, lp, phase = [], 0.0, 0.0
    for i in range(n):
        t = i / SR
        x = t / 2.4
        f = 95.0 * (1.18 - 0.36 * x)
        phase += TAU * f / SR
        lp += ((rng.random() - 0.5) - lp) * 0.2
        amp = math.sin(math.pi * x) ** 1.6
        out.append((math.sin(phase) * 0.5 + math.sin(phase * 2) * 0.2 + lp * 0.6) * amp)
    return out


# ---- blade spin: airy whoosh loop.
def spin():
    n = seconds(1.5)
    out, lp = [], 0.0
    for i in range(n):
        t = i / SR
        lp += ((rng.random() - 0.5) - lp) * 0.35
        mod = 0.6 + 0.4 * math.sin(TAU * 6.0 * t)       # 9 cycles -> loops
        out.append((lp + math.sin(TAU * 178 * t) * 0.18) * mod)
    return out


# ---- town theme: Am F C G pad + sparse plucked pentatonic line. 8 bars, loops.
def theme():
    bpm = 66.0
    bar = 60.0 / bpm * 4.0
    total = bar * 8
    n = seconds(total)
    out = [0.0] * n
    chords = [(220.0, 261.63, 329.63), (174.61, 220.0, 261.63),
              (130.81, 164.81, 196.0, 261.63), (196.0, 246.94, 293.66)]
    # Pad: two detuned voices per note, slow bar-length swell.
    for b in range(8):
        chord = chords[b % 4]
        start = seconds(b * bar)
        ln = seconds(bar)
        for f in chord:
            ph1 = rng.random() * TAU
            ph2 = rng.random() * TAU
            for i in range(ln):
                t = i / SR
                e = math.sin(math.pi * i / ln) ** 0.7
                v = (math.sin(TAU * f * 1.001 * t + ph1)
                     + math.sin(TAU * f * 0.998 * t + ph2)) * 0.5
                v += math.sin(TAU * f * 0.5 * t) * 0.25
                j = start + i
                if j < n:
                    out[j] += v * e * 0.045
    # Melody: A-minor pentatonic, one soft pluck every two beats, seeded.
    scale = [440.0, 523.25, 587.33, 659.25, 783.99]
    mel = random.Random(7)
    for k in range(16):
        if mel.random() < 0.30:
            continue
        f = scale[mel.randrange(len(scale))]
        start = seconds(k * bar / 2 + 0.12)
        ln = seconds(1.6)
        for i in range(ln):
            t = i / SR
            v = math.sin(TAU * f * t) * 0.7 + math.sin(TAU * f * 2 * t) * 0.15
            j = start + i
            if j < n:
                out[j] += v * math.exp(-2.6 * t) * 0.16
    return out


TAU = math.tau
# ---- corkboard pin: a short woody thunk.
def pin():
    n = seconds(0.16)
    out = []
    for i in range(n):
        t = i / SR
        v = math.sin(TAU * 240 * t) * 0.7 + math.sin(TAU * 470 * t) * 0.25
        v += (rng.random() - 0.5) * 0.7 * math.exp(-300 * t)
        out.append(v * math.exp(-34 * t))
    return out


print("[gen_audio] yaziliyor:")
write("mower_engine_loop", engine(), 0.9)
write("grass_cut", cut(), 0.8)
write("discovery_chime", discovery(), 0.85)
write("scrap_pickup", pickup(), 0.8)
write("blade_hit", clank(), 0.85)
write("bird_single", chirp(), 0.7)
write("ambient_birds_loop", ambient(), 0.55)
write("car_pass", car(), 0.75)
write("blade_spin", spin(), 0.6)
write("theme_town", theme(), 0.9)
write("pin", pin(), 0.8)
print("[gen_audio] bitti")
