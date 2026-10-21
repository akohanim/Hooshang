#!/usr/bin/env python3
"""Act III's three small sounds -> assets/audio/act3/ (read by systems/sfx.gd).

  bubble.wav   an air bubble popping: a quick upward chirp on a breath of noise
  jelly.wav    a jellyfish bell: a soft, rubbery boing, pitch sagging back
  memory.wav   a memory touched: two glass notes from the act's theme (A, F)

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


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    write('bubble.wav', bubble())
    write('jelly.wav', jelly())
    write('memory.wav', memory())
    print('wrote', ', '.join(p.name for p in sorted(OUT.glob('*.wav'))))
