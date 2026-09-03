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
    """A pass of the blade through grass (G12.10).

    The old version was one lowpassed noise burst — a flat "shhh" that read as
    static, not as grass. Real cut sound is three things layered: a bright
    band-passed hiss (leaves shearing), a scatter of tiny transients (individual
    stems letting go, which is what makes it sound organic rather than
    synthetic), and a short low thump of air moving under the deck.
    """
    n = seconds(0.34)
    out = []
    # Its own generator: drawing from the shared rng would shift every sound
    # written after it, so a change here would rewrite unrelated files.
    crng = random.Random(20261010)
    # Band-pass hiss: one lowpass to tame the fizz, minus a slower lowpass to
    # strip the rumble, leaves energy around 2-6 kHz where shearing lives.
    lp_a, lp_b, lp_slow = 0.0, 0.0, 0.0
    # Stem pops, scattered unevenly so no rhythm emerges from the repetition.
    pops = sorted(crng.uniform(0.02, 0.92) for _ in range(crng.randint(7, 11)))
    pop_gain = [crng.uniform(0.35, 1.0) for _ in pops]
    pop_freq = [crng.uniform(1400, 4200) for _ in pops]
    for i in range(n):
        t = i / n
        white = crng.random() - 0.5
        # Two poles, not one: a single pole rolls off only 6 dB/octave, which
        # left enough top end that the result still read as white noise. Measured
        # band split at these coefficients: 3%% below 500 Hz, 32%% mid, 45%% in
        # the 2-6 kHz shearing band, 20%% above — brightest where grass is.
        lp_a += (white - lp_a) * 0.75
        lp_b += (lp_a - lp_b) * 0.75
        lp_slow += (lp_b - lp_slow) * 0.12
        hiss = (lp_b - lp_slow) * 3.2
        # Swells in, cuts off quickly: the blade meets the grass and is past it.
        amp = math.sin(math.pi * min(1.0, t * 1.35)) ** 1.6
        v = hiss * amp
        # Deck thump — felt more than heard, keeps it from sounding thin.
        v += math.sin(TAU * 88 * (i / SR)) * 0.22 * math.exp(-26 * (i / SR))
        for k, at in enumerate(pops):
            if t >= at:
                dt = (t - at) * n / SR
                if dt < 0.03:
                    v += (math.sin(TAU * pop_freq[k] * dt) * pop_gain[k]
                          * 0.18 * math.exp(-190 * dt))
        out.append(v)
    return out


# ---- G13 plant cuts: the east road grows three things that do not sound like
# grass, and the ear tells plants apart faster than the eye does.


def cut_reed():
    """Reeds: a hiss, not a shear.

    A reed is thin, hollow and wet at the base. There is almost no thump —
    nothing heavy is moving — and the pops are soft and numerous rather than
    sharp, because a bed of them gives way a dozen stems at a time. Longer than
    grass and brighter, with a faint whistle from air over the cut tubes.
    """
    n = seconds(0.42)
    out = []
    crng = random.Random(20261101)
    lp_a = lp_b = lp_slow = 0.0
    pops = sorted(crng.uniform(0.02, 0.95) for _ in range(crng.randint(14, 20)))
    pop_gain = [crng.uniform(0.20, 0.55) for _ in pops]
    pop_freq = [crng.uniform(2600, 6200) for _ in pops]
    whistle = crng.uniform(1750, 2100)
    for i in range(n):
        t = i / n
        white = crng.random() - 0.5
        # Brighter split than grass: one fewer pole of lowpass, so more of the
        # 4-8 kHz air stays in and the result reads as rustle rather than shear.
        lp_a += (white - lp_a) * 0.86
        lp_b += (lp_a - lp_b) * 0.86
        lp_slow += (lp_b - lp_slow) * 0.07
        hiss = (lp_b - lp_slow) * 3.6
        amp = math.sin(math.pi * min(1.0, t * 1.05)) ** 1.15
        v = hiss * amp
        # Air over the cut tubes, quiet and detuned so it never reads as a note.
        v += math.sin(TAU * whistle * (i / SR)) * 0.05 * amp * (0.6 + 0.4 * t)
        for k, at in enumerate(pops):
            if t >= at:
                dt = (t - at) * n / SR
                if dt < 0.02:
                    v += (math.sin(TAU * pop_freq[k] * dt) * pop_gain[k]
                          * 0.10 * math.exp(-260 * dt))
        out.append(v)
    return out


def cut_corn():
    """Corn: a crack.

    A stalk is thick, dry and hollow, and it fails all at once. So this is the
    inverse of the reed — few transients but big ones, low and woody, with a
    real thump under them and only a short tail of hiss from the leaves. The
    first crack lands immediately rather than swelling in: the blade does not
    ease into a stalk, it breaks it.
    """
    n = seconds(0.38)
    out = []
    crng = random.Random(20261102)
    lp_a = lp_b = lp_slow = 0.0
    cracks = sorted(crng.uniform(0.0, 0.55) for _ in range(crng.randint(3, 5)))
    cracks[0] = 0.0
    crack_gain = [crng.uniform(0.75, 1.0) for _ in cracks]
    crack_freq = [crng.uniform(190, 420) for _ in cracks]
    for i in range(n):
        t = i / n
        white = crng.random() - 0.5
        lp_a += (white - lp_a) * 0.55
        lp_b += (lp_a - lp_b) * 0.55
        lp_slow += (lp_b - lp_slow) * 0.18
        hiss = (lp_b - lp_slow) * 2.0
        # Leaves only, and they are gone quickly: the stalk is the event.
        v = hiss * math.exp(-7.0 * t) * 0.55
        v += math.sin(TAU * 62 * (i / SR)) * 0.30 * math.exp(-19 * (i / SR))
        for k, at in enumerate(cracks):
            if t >= at:
                dt = (t - at) * n / SR
                if dt < 0.09:
                    # A snapped fibre bundle: a low body with a bright edge on
                    # it, both decaying fast. One sine alone read as a drum.
                    body = math.sin(TAU * crack_freq[k] * dt) * math.exp(-52 * dt)
                    edge = ((crng.random() - 0.5) * 2.0) * math.exp(-330 * dt)
                    v += (body * 0.5 + edge * 0.42) * crack_gain[k]
        out.append(v)
    return out


def cut_sunflower():
    """Sunflowers: one snap, then the petals.

    A stem thicker than a reed and softer than corn, so the transient is
    mid-weight and wet rather than dry. What makes it a SUNFLOWER is the tail:
    the head falls, and its petals flutter — a scatter of tiny papery ticks
    after the cut, which corn does not have.
    """
    n = seconds(0.46)
    out = []
    crng = random.Random(20261103)
    lp_a = lp_b = lp_slow = 0.0
    stem = crng.uniform(150, 260)
    flutter = sorted(crng.uniform(0.30, 0.98) for _ in range(crng.randint(9, 14)))
    flutter_freq = [crng.uniform(3200, 7000) for _ in flutter]
    for i in range(n):
        t = i / n
        white = crng.random() - 0.5
        lp_a += (white - lp_a) * 0.70
        lp_b += (lp_a - lp_b) * 0.70
        lp_slow += (lp_b - lp_slow) * 0.11
        hiss = (lp_b - lp_slow) * 2.6
        v = hiss * math.sin(math.pi * min(1.0, t * 2.2)) ** 1.4 * 0.6
        # The stem: one wet snap, no bright edge — that is what makes it read
        # as green rather than as dry.
        st = i / SR
        v += math.sin(TAU * stem * st) * 0.55 * math.exp(-34 * st)
        v += math.sin(TAU * 74 * st) * 0.20 * math.exp(-22 * st)
        for k, at in enumerate(flutter):
            if t >= at:
                dt = (t - at) * n / SR
                if dt < 0.012:
                    v += (math.sin(TAU * flutter_freq[k] * dt) * 0.09
                          * math.exp(-420 * dt))
        out.append(v)
    return out


# ---- G13 signal pair: B14's radio, in two layers that cross-fade as the ground
# opens. Both loop, so both are built on an exact number of cycles.


def signal_static():
    """Untuned static: band-limited noise with a slow, shallow wander.

    Deliberately dull. This layer exists to be TAKEN AWAY, and anything with a
    feature in it would be missed when it goes.
    """
    n = seconds(2.0)
    out = []
    crng = random.Random(20261104)
    lp_a = lp_b = hp = 0.0
    for i in range(n):
        white = crng.random() - 0.5
        lp_a += (white - lp_a) * 0.62
        lp_b += (lp_a - lp_b) * 0.62
        hp += (lp_b - hp) * 0.05
        v = (lp_b - hp) * 2.4
        # One slow cycle across the whole loop, so the seam is silent.
        v *= 0.82 + 0.18 * math.sin(TAU * (i / n))
        out.append(v)
    # Cross-fade the last 60 ms into the first, so the loop point cannot tick.
    tail = seconds(0.06)
    for k in range(tail):
        a = k / tail
        out[k] = out[k] * a + out[n - tail + k] * (1.0 - a)
    return out[:n - tail]


def signal_clear():
    """The signal underneath: a carrier with one word repeating on it.

    Not literal morse — a repeated three-pulse figure, spaced so the ear reads
    it as the SAME thing over and over. That is the whole content of the
    beacon, and the player hears it arrive out of the static as they cut.
    """
    n = seconds(2.0)
    out = []
    carrier = 620.0
    # Three pulses and a rest, exactly twice across the loop.
    figure = [(0.00, 0.10), (0.14, 0.10), (0.28, 0.16)]
    for i in range(n):
        st = i / SR
        t = i / n
        v = 0.0
        for cycle in range(2):
            base = cycle * 1.0
            for at, dur in figure:
                start = (base + at) / 2.0
                stop = (base + at + dur) / 2.0
                if start <= t < stop:
                    local = (t - start) * 2.0
                    # Soft edges: a square gate on a tone clicks.
                    gate = min(1.0, local / 0.012, (dur - local) / 0.012)
                    v += math.sin(TAU * carrier * st) * 0.55 * max(0.0, gate)
                    v += math.sin(TAU * carrier * 2.0 * st) * 0.12 * max(0.0, gate)
        # A quiet bed of carrier so the layer is present even between pulses.
        v += math.sin(TAU * carrier * 0.5 * st) * 0.05
        out.append(v)
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



# ============================================================ G16.1 additions
# The world got rain, night, a walk mode, animals and a prologue lamp and none
# of them made a sound. Same rules as everything above: synthesized OFFLINE
# into files, deterministic, replaced by any .ogg of the same base name.

def _noise(n, seed_offset=0):
    r = random.Random(20260824 + seed_offset)
    return [r.random() * 2.0 - 1.0 for _ in range(n)]


def _lowpass(samples, alpha):
    out = []
    y = 0.0
    for v in samples:
        y += alpha * (v - y)
        out.append(y)
    return out


def _highpass(samples, alpha):
    low = _lowpass(samples, alpha)
    return [v - l for v, l in zip(samples, low)]


def _loop_fade(samples, edge=0.04):
    """Cross-fades the tail into the head so a loop point is inaudible."""
    n = len(samples)
    k = int(n * edge)
    out = list(samples)
    for i in range(k):
        t = i / k
        out[i] = samples[i] * t + samples[n - k + i] * (1.0 - t)
    return out[: n - k]


# ---- rain: broadband hiss with a slow swell, plus sparse heavier drops.
def rain_loop():
    n = seconds(6.0)
    hiss = _lowpass(_noise(n, 1), 0.35)
    hiss = _highpass(hiss, 0.02)
    out = []
    drops = random.Random(77)
    drop_at = set(drops.randrange(n) for _ in range(140))
    tick = 0.0
    for i in range(n):
        t = i / SR
        swell = 0.75 + 0.25 * math.sin(TAU * 0.21 * t)
        if i in drop_at:
            tick = 1.0
        tick *= 0.9992
        v = hiss[i] * swell * 0.55 + (drops.random() - 0.5) * tick * 0.5
        out.append(v)
    return _loop_fade(out)


# ---- night: crickets. Trains of 4.2 kHz chirps, several insects out of phase,
# with a slow breathing swell so it is a field and not a machine.
def crickets_loop():
    n = seconds(8.0)
    out = [0.0] * n
    bugs = [(4100.0, 0.0, 17.0), (4500.0, 0.37, 15.5), (3900.0, 0.71, 19.0)]
    for freq, phase, rate in bugs:
        for i in range(n):
            t = i / SR
            gate = 0.5 + 0.5 * math.sin(TAU * rate * t + phase * TAU)
            gate = gate ** 6
            train = 0.5 + 0.5 * math.sin(TAU * 1.9 * t + phase * 4.0)
            train = 1.0 if train > 0.35 else 0.0
            out[i] += math.sin(TAU * freq * t) * gate * train * 0.12
    return _loop_fade(out)


# ---- a gust crossing the field: a noise swell, 2.6 s, one shot.
def wind_gust():
    n = seconds(2.6)
    raw = _lowpass(_noise(n, 3), 0.08)
    out = []
    for i in range(n):
        t = i / n
        env = math.sin(math.pi * t) ** 1.6
        out.append(raw[i] * env)
    return out


# ---- footsteps: a soft broadband thud with a grassy swish on top.
def footstep(grass=True, seed=5):
    n = seconds(0.22)
    raw = _noise(n, seed)
    out = []
    for i in range(n):
        t = i / SR
        thud = math.sin(TAU * 62 * t) * math.exp(-42 * t)
        swish = raw[i] * math.exp(-18 * t) * (0.55 if grass else 0.25)
        crunch = raw[i] * math.exp(-90 * t) * (0.0 if grass else 0.6)
        out.append(thud * 0.6 + swish + crunch)
    return out


# ---- the lamp on the gate: a faint mains hum with a flicker in it.
def lamp_hum():
    n = seconds(3.0)
    out = []
    for i in range(n):
        t = i / SR
        flick = 1.0 + 0.08 * math.sin(TAU * 7.3 * t) * math.sin(TAU * 0.9 * t)
        v = (math.sin(TAU * 60 * t) * 0.6 + math.sin(TAU * 120 * t) * 0.3
             + math.sin(TAU * 180 * t) * 0.1) * flick
        out.append(v)
    return _loop_fade(out)


# ---- the dog, once, when it has something: a short low huff, not a bark.
def dog_huff():
    n = seconds(0.28)
    raw = _lowpass(_noise(n, 8), 0.12)
    out = []
    for i in range(n):
        t = i / SR
        env = math.sin(math.pi * min(1.0, t / 0.28)) ** 0.7
        out.append(raw[i] * env * 0.9 + math.sin(TAU * 140 * t) * env * 0.25)
    return out


# ---- a rabbit going through grass: a quick rustle, rising then gone.
def rabbit_rustle():
    n = seconds(0.55)
    raw = _highpass(_noise(n, 11), 0.15)
    out = []
    for i in range(n):
        t = i / 0.55 / SR * SR
        u = i / n
        env = (u * 3.0 if u < 0.33 else 1.0) * math.exp(-4.5 * u)
        out.append(raw[i] * env)
    return out


# ---- a small bird taking off: five quick wing flaps.
def bird_takeoff():
    n = seconds(0.6)
    raw = _lowpass(_noise(n, 13), 0.5)
    out = []
    for i in range(n):
        t = i / SR
        flap = 0.5 + 0.5 * math.sin(TAU * 11.0 * t - math.pi / 2)
        flap = flap ** 3
        env = math.exp(-3.2 * t)
        out.append(raw[i] * flap * env)
    return out


# ---- somebody at the edge of town: two soft notes, a fifth apart.
def settler_card():
    a = bell(392.0, 0.9, 0.8)
    b = bell(587.3, 1.1, 0.9)
    n = max(len(a), len(b)) + seconds(0.25)
    out = [0.0] * n
    for i, v in enumerate(a):
        out[i] += v
    off = seconds(0.25)
    for i, v in enumerate(b):
        out[i + off] += v
    return out


# ---- a crate of food picked up: a soft wooden pluck, lower than scrap.
def food_pickup():
    n = seconds(0.3)
    out = []
    for i in range(n):
        t = i / SR
        v = math.sin(TAU * 196 * t) * 0.7 + math.sin(TAU * 392 * t) * 0.2
        v += (rng.random() - 0.5) * 0.4 * math.exp(-200 * t)
        out.append(v * math.exp(-14 * t))
    return out


# ---- two music beds for the yard: the hub theme's language, slower, and
# without its melody line so it can sit under mowing for four minutes.
def _bed(seed, scale, bar, bars, base_gain, decay, minor=False):
    mel = random.Random(seed)
    n = seconds(bar * bars)
    out = [0.0] * n
    for k in range(bars * 2):
        f = scale[mel.randrange(len(scale))]
        start = seconds(k * bar / 2 + mel.random() * 0.4)
        ln = seconds(bar * 0.9)
        for i in range(ln):
            t = i / SR
            v = math.sin(TAU * f * t) * 0.6 + math.sin(TAU * f * 2 * t) * 0.12
            v += math.sin(TAU * f * 0.5 * t) * 0.25
            j = start + i
            if j < n:
                out[j] += v * math.exp(-decay * t) * base_gain
    # a held root underneath, very quiet
    root = scale[0] * 0.5
    for i in range(n):
        t = i / SR
        out[i] += math.sin(TAU * root * t) * 0.05 * (0.6 + 0.4 * math.sin(TAU * 0.05 * t))
    return _loop_fade(out, 0.06)


def bed_day():
    # G major pentatonic, open and unhurried.
    return _bed(4001, [196.0, 220.0, 246.9, 293.7, 329.6, 392.0], 2.4, 16, 0.16, 0.9)


def bed_evening():
    # E minor, slower, lower, with the fifth doing most of the work.
    return _bed(4002, [164.8, 196.0, 220.0, 246.9, 293.7, 329.6], 3.0, 16, 0.14, 0.7)


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
write("cut_reed", cut_reed(), 0.72)
write("cut_corn", cut_corn(), 0.86)
write("cut_sunflower", cut_sunflower(), 0.78)
write("signal_static_loop", signal_static(), 0.5)
write("signal_clear_loop", signal_clear(), 0.55)
write("rain_loop", rain_loop(), 0.6)
write("crickets_loop", crickets_loop(), 0.5)
write("wind_gust", wind_gust(), 0.55)
write("footstep_grass_a", footstep(True, 5), 0.55)
write("footstep_grass_b", footstep(True, 6), 0.55)
write("footstep_dirt", footstep(False, 7), 0.55)
write("lamp_hum_loop", lamp_hum(), 0.35)
write("dog_huff", dog_huff(), 0.6)
write("rabbit_rustle", rabbit_rustle(), 0.6)
write("bird_takeoff", bird_takeoff(), 0.6)
write("settler_card", settler_card(), 0.8)
write("food_pickup", food_pickup(), 0.8)
write("bed_day", bed_day(), 0.8)
write("bed_evening", bed_evening(), 0.8)
print("[gen_audio] bitti")
