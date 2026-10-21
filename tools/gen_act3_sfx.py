#!/usr/bin/env python3
"""Act III's three small sounds -> assets/audio/act3/ (read by systems/sfx.gd).

  bubble.wav   an air bubble popping: a quick upward chirp on a breath of noise
  jelly.wav    a jellyfish bell: a soft, rubbery boing, pitch sagging back
  memory.wav   a memory touched: two glass notes from the act's theme (A, F)
  roar.wav     the tiger: a rasping, falling roar (THE TIGER, THE VINE)
  growl.wav    the tiger below: a low rumble
  gnaw.wav     a mouse's teeth on the vine: a quick dry scrape
  bite.wav     the lemon bitten: a wet crunch
  creak.wav    the vine taking his weight

Synthesised and deterministic, like tools/gen_act3_sea_music.py.

    python3 tools/gen_act3_sfx.py
"""
import wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/act3'
SR = 44100
RNG = np.random.default_rng(7)


def write(name, x):
    x = x / (np.abs(x).max() or 1) * 0.7
    with wave.open(str(OUT / name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def bubble():
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    f = 600 + 2400 * (t / t[-1]) ** 1.6
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 26)
    noise = RNG.standard_normal(n) * np.exp(-t * 80) * 0.25
    return tone + noise


def jelly():
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    f = 190 * (1 + 0.9 * np.exp(-t * 18)) * (1 + 0.04 * np.sin(2 * np.pi * 11 * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(phase) + 0.35 * np.sin(2 * phase)) * np.exp(-t * 7) * np.minimum(1, t * 300)


def memory():
    out = np.zeros(int(1.4 * SR))
    for at, m in ((0.0, 81), (0.18, 77)):
        n = int(1.2 * SR)
        t = np.arange(n) / SR
        f = 440 * 2 ** ((m - 69) / 12)
        mod = 1.6 * np.exp(-t * 3) * np.sin(2 * np.pi * f * 3.5 * t)
        note = np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 2.6)
        i = int(at * SR)
        out[i:i + n] += note[:len(out) - i]
    return out


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def roar():
    """Noise shaped by a pulsing, falling growl: the rasp comes from the pulses."""
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    f0 = 140 * (1 + 0.5 * np.exp(-t * 2.5)) * (1 - 0.25 * t / t[-1])
    pulse = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * np.cumsum(f0) / SR))
    noise = lowpass(RNG.standard_normal(n), 1400)
    voice = np.sin(2 * np.pi * np.cumsum(f0 * 0.5) / SR)
    env = np.minimum(1, t * 6) * np.exp(-np.maximum(0, t - 0.5) * 2.4)
    return (noise * pulse * 1.4 + voice * 0.5) * env


def growl():
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    f0 = 62 * (1 + 0.06 * np.sin(2 * np.pi * 3 * t))
    pulse = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * np.cumsum(f0) / SR))
    noise = lowpass(RNG.standard_normal(n), 500)
    env = np.minimum(1, t * 4) * np.minimum(1, (t[-1] - t) * 4)
    return noise * pulse * env


def gnaw():
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    clicks = np.zeros(n)
    for at in (0.0, 0.03, 0.06):
        i = int(at * SR)
        k = int(0.012 * SR)
        clicks[i:i + k] += RNG.standard_normal(k) * np.exp(-np.arange(k) / SR * 400)
    return clicks


def bite():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    crunch = RNG.standard_normal(n) * np.exp(-t * 18) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 37 * t)))
    juice = lowpass(RNG.standard_normal(n), 2500) * np.exp(-np.maximum(0, t - 0.05) * 12) * 0.4
    return lowpass(crunch, 3500) + juice


def creak():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    f = 230 + 60 * np.sin(2 * np.pi * 1.5 * t)
    pulse = (np.sin(2 * np.pi * np.cumsum(f) / SR) > 0.6).astype(float)
    return lowpass(pulse * RNG.uniform(0.5, 1.0, n), 1800) * np.minimum(1, t * 10) * np.exp(-t * 3)


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    write('bubble.wav', bubble())
    write('jelly.wav', jelly())
    write('memory.wav', memory())
    for name, fn in (('roar', roar), ('growl', growl), ('gnaw', gnaw), ('bite', bite), ('creak', creak)):
        write(name + '.wav', fn())
    print('wrote', ', '.join(p.name for p in sorted(OUT.glob('*.wav'))))
