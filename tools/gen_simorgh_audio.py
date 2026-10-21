"""SUPER SIMORGH's sound: a santur playing in Dastgah-e Shur, synthesised.

Stdlib only (wave/struct/math/random), deterministic, the same recipe family
as gen_voice_blips.py. Writes assets/minigame/simorgh/*.wav:

* music.wav   — a 9.6s loop: a Shur melody that keeps falling back to its
  tonic, long notes played as RIZ (the santur's rapid tremolo of repeated
  hammer strikes), over a quiet drone. Mixed CIRCULARLY — every ringing tail
  that runs past the end wraps round to the start — so it loops seamlessly.
* coin, jump, bump, hit (a fall), portal (a star block's light burst) and
  valley (reaching the light) — the game's cues, all santur.
* Darkshang's sounds, for the chase: heartbeat (one lub-dub, retriggered
  faster as he closes), drone (an 8s loop of a low dissonant cluster and
  wind, built from whole-cycle sines so it loops without a seam), whisper
  (breathy band-limited noise in syllables), stinger (a scare: a crushed
  santur cluster and a screech) and shriek (being consumed).

What makes it Persian rather than "minor-ish": Shur's second degree is KORON,
a quarter-tone flat (1.5 semitones above the tonic), which equal-tempered
instruments cannot play and synthesis gets for free. And the santur's pairs
of strings are tuned a hair apart, so every note shimmers (the two detuned
partials per harmonic below).

    python3 tools/gen_simorgh_audio.py
"""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/minigame/simorgh'
RATE = 22050
D4 = 293.66
# Dastgah-e Shur on D, in semitones: D, E-koron, F, G, A, Bb, C, D, E-koron, F, G.
SHUR = [0, 1.5, 3, 5, 7, 8, 10, 12, 13.5, 15, 17]


def deg(i, octave=0):
    return D4 * 2 ** ((SHUR[i] + 12 * octave) / 12)


_cache = {}


def pluck(freq, length=1.4):
    """One hammer strike on a santur course: paired, slightly detuned strings,
    upper partials dying faster than the fundamental, and a click of noise."""
    key = (round(freq, 3), length)
    if key in _cache:
        return _cache[key]
    n = int(RATE * length)
    out = [0.0] * n
    rnd = random.Random(int(freq * 1000))
    for h in range(1, 7):
        amp = 1.0 / h ** 1.1
        k = math.exp(-(2.0 + h * 0.9) / RATE)
        for detune in (-0.0011, 0.0011):
            f = freq * h * (1 + 0.0003 * h * h) * (1 + detune)
            if f > RATE * 0.45:
                continue
            w = 2 * math.pi * f / RATE
            ph = rnd.random() * 2 * math.pi
            env = amp * 0.5
            for i in range(n):
                out[i] += env * math.sin(w * i + ph)
                env *= k
    click = int(RATE * 0.006)
    for i in range(click):
        out[i] += (rnd.random() * 2 - 1) * 0.45 * (1 - i / click)
    # a short fade at the very end so a cut-off tail never clicks
    for i in range(int(RATE * 0.05)):
        out[n - 1 - i] *= i / (RATE * 0.05)
    _cache[key] = out
    return out


def mix(buf, at, wave_, gain, wrap):
    n = len(buf)
    start = int(at * RATE)
    for i, v in enumerate(wave_):
        j = start + i
        if j >= n:
            if not wrap:
                break
            j %= n
        buf[j] += v * gain


def riz(buf, at, dur, freq, wrap, rate=13.0, gain=0.3):
    """The santur's tremolo: the note re-struck at `rate` per second."""
    mix(buf, at, pluck(freq), 0.85, wrap)
    t = 1.0 / rate
    i = 0
    while t < dur - 0.02:
        mix(buf, at + t, pluck(freq), gain * (0.9 + 0.1 * (i % 2)), wrap)
        t += 1.0 / rate
        i += 1


def write(name, buf, peak=0.82):
    m = max(abs(v) for v in buf) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(v / m * peak * 32767)) for v in buf))


def music():
    beat = 0.4
    phrase_a = [(4, 1), (3, .5), (2, .5), (3, 1), (2, .5), (1, .5), (2, 2, 'riz'),
                (1, .5), (0, .5), (1, 1), (2, .5), (1, .5), (0, 3, 'riz')]
    phrase_b = [(7, 1), (6, .5), (5, .5), (4, 1), (5, .5), (4, .5), (3, 2, 'riz'),
                (4, .5), (3, .5), (2, 1), (1, .5), (2, .5), (0, 3, 'riz')]
    notes = phrase_a + phrase_b
    length = sum(n[1] for n in notes) * beat
    buf = [0.0] * int(length * RATE)
    t = 0.0
    for n in notes:
        d, beats = n[0], n[1]
        if len(n) > 2:
            riz(buf, t, beats * beat, deg(d), True)
        else:
            mix(buf, t, pluck(deg(d)), 0.8, True)
        t += beats * beat
    # left-hand accompaniment: the low tonic and fifth, every two beats
    b = 0
    while b * beat < length - 0.01:
        f = deg(0, -1) if b % 4 == 0 else deg(4, -2)
        mix(buf, b * beat, pluck(f, 1.8), 0.32, True)
        b += 2
    # the drone: frequencies nudged to whole cycles per loop so it wraps clean
    for f0, g in ((deg(0, -2), 0.05), (deg(4, -2), 0.03)):
        f = round(f0 * length) / length
        sw = 2.0 / length
        for i in range(len(buf)):
            s = i / RATE
            buf[i] += g * math.sin(2 * math.pi * f * s) * (0.7 + 0.3 * math.sin(2 * math.pi * sw * s))
    write('music', buf, 0.7)


def cue(name, events, length):
    buf = [0.0] * int(length * RATE)
    for at, f, g, *rest in events:
        if rest:
            riz(buf, at, rest[0], f, False)
        else:
            mix(buf, at, pluck(f), g, False)
    write(name, buf)


def noise_thud(buf, dur, g):
    rnd = random.Random(7)
    n = int(dur * RATE)
    lp = 0.0
    for i in range(n):
        lp += ((rnd.random() * 2 - 1) - lp) * 0.08
        buf[i] += lp * g * (1 - i / n) ** 2


def heartbeat():
    buf = [0.0] * int(0.6 * RATE)
    for at, g in ((0.0, 1.0), (0.17, 0.7)):
        n = int(0.16 * RATE)
        ph = 0.0
        for i in range(n):
            t = i / RATE
            f = 55.0 - 25.0 * t / 0.16
            ph += 2 * math.pi * f / RATE
            buf[int(at * RATE) + i] += g * math.sin(ph) * math.exp(-t * 22.0) * min(1.0, t * 400.0)
    write('heartbeat', buf, 0.9)


def drone():
    length = 8.0
    n = int(length * RATE)
    buf = [0.0] * n
    rnd = random.Random(31)
    parts = [(55.0, 0.30), (58.3, 0.26), (77.8, 0.18), (82.4, 0.12), (110.0, 0.06), (116.5, 0.05)]
    # wind: many random-phase sines, every one a whole number of cycles per loop
    for _ in range(46):
        parts.append((rnd.uniform(140.0, 700.0), rnd.uniform(0.004, 0.014)))
    for f0, g in parts:
        f = round(f0 * length) / length
        w = 2 * math.pi * f / RATE
        ph = rnd.random() * 2 * math.pi
        lfo = 2 * math.pi * rnd.choice((1, 2, 3)) / length
        lph = rnd.random() * 2 * math.pi
        for i in range(n):
            buf[i] += g * math.sin(w * i + ph) * (0.65 + 0.35 * math.sin(lfo * i / RATE + lph))
    write('drone', buf, 0.75)


def whisper():
    rnd = random.Random(5)
    length = 1.5
    n = int(length * RATE)
    buf = [0.0] * n
    # breath: noise through a resonant band around 2.5-4 kHz, in syllables
    syllables = [(0.05, 0.22), (0.3, 0.16), (0.5, 0.3), (0.86, 0.12), (1.02, 0.34)]
    y1 = y2 = 0.0
    for i in range(n):
        t = i / RATE
        f = 2500.0 + 1400.0 * math.sin(t * 7.0)
        r = 0.97
        c = 2 * r * math.cos(2 * math.pi * f / RATE)
        x = rnd.random() * 2 - 1
        y = x + c * y1 - r * r * y2
        y2, y1 = y1, y
        env = 0.0
        for at, d in syllables:
            if at <= t < at + d:
                u = (t - at) / d
                env = max(env, math.sin(math.pi * u) ** 1.5)
        buf[i] = y * env * 0.05
    # a santur note played backwards underneath
    tail = pluck(deg(1, -1))[: int(1.2 * RATE)]
    for i, v in enumerate(reversed(tail)):
        if i < n:
            buf[i] += v * 0.25
    write('whisper', buf, 0.6)


def stinger():
    buf = [0.0] * int(1.4 * RATE)
    for d, o in ((0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (5, -1)):
        mix(buf, 0.0, pluck(deg(d, o)), 0.9, False)
    noise_thud(buf, 0.3, 3.0)
    ph = 0.0
    for i in range(int(1.1 * RATE)):
        t = i / RATE
        f = 900.0 + 600.0 * t + 40.0 * math.sin(t * 60.0)
        ph += 2 * math.pi * f / RATE
        buf[i] += 0.35 * math.sin(ph) * math.exp(-t * 2.5) * min(1.0, t * 80.0)
    write('stinger', buf, 0.9)


def shriek():
    rnd = random.Random(9)
    length = 2.4
    n = int(length * RATE)
    buf = [0.0] * n
    lp = 0.0
    ph = 0.0
    for i in range(n):
        t = i / RATE
        env = min(1.0, t * 3.0) * (1.0 if t < 1.6 else math.exp(-(t - 1.6) * 5.0))
        lp += ((rnd.random() * 2 - 1) - lp) * 0.15
        f = 130.0 - 90.0 * t / length
        ph += 2 * math.pi * f / RATE
        roar = sum(math.sin(ph * h + h) / h for h in range(1, 9))
        buf[i] = env * (lp * 1.6 + roar * 0.35)
    write('shriek', buf, 0.95)


if __name__ == '__main__':
    heartbeat()
    drone()
    whisper()
    stinger()
    shriek()
    music()
    cue('coin', [(0, deg(7), 0.7), (0.06, deg(10), 0.9)], 1.2)
    cue('jump', [(0, deg(4), 0.5), (0.03, deg(7), 0.6)], 0.6)
    cue('stomp', [(0, deg(0, -1), 0.9), (0.04, deg(4, -1), 0.7)], 0.7)
    bump = [0.0] * int(0.5 * RATE)
    mix(bump, 0, pluck(deg(0, -2)), 0.8, False)
    noise_thud(bump, 0.12, 2.0)
    write('bump', bump)
    cue('portal', [(0, deg(0), 0.7), (0.02, deg(4), 0.6), (0.04, deg(7), 0.6),
                   (0.3, deg(7), 0.8, 1.0)], 2.2)
    cue('valley', [(i * 0.06, deg(d), 0.7) for i, d in enumerate(range(11))]
        + [(0.7, deg(10), 0.8, 0.9)], 2.4)
    hit = [0.0] * int(1.4 * RATE)
    mix(hit, 0, pluck(deg(0, -1)), 0.9, False)
    mix(hit, 0.01, pluck(deg(1, -1)), 0.9, False)
    mix(hit, 0.12, pluck(deg(5, -2)), 0.7, False)
    noise_thud(hit, 0.25, 2.5)
    write('hit', hit)
    print('wrote', ', '.join(sorted(p.name for p in OUT.glob('*.wav'))))
