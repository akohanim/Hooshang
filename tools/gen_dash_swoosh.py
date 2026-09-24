#!/usr/bin/env python3
"""Generate a soft, breathy dash with a gently wobbling cartoon whistle.
Run from anywhere; deterministic 44.1 kHz mono PCM, no external dependencies.
"""
import math
from pathlib import Path
import random
import struct
import wave

RATE = 44100
DURATION = 0.30
OUT = Path(__file__).resolve().parents[1] / 'assets/sfx/dash_swoosh.wav'


def generate():
    rng = random.Random(7103)
    samples = []
    air = rounded_air = phase = 0.0
    for i in range(round(RATE * DURATION)):
        t = i / RATE
        u = t / DURATION
        noise = rng.uniform(-1.0, 1.0)
        # Two low-pass stages remove the hiss; no bright transient or chirp.
        cutoff = 750 - 350 * u
        alpha = 1 - math.exp(-math.tau * cutoff / RATE)
        air += alpha * (noise - air)
        rounded_air += alpha * (air - rounded_air)
        # A smooth little up-and-down smile, without a percussive pitch drop.
        pitch = 225 - 45 * u + 38 * math.sin(math.tau * 1.3 * u)
        phase += math.tau * pitch / RATE
        flutter = 0.94 + 0.06 * math.sin(math.tau * 2 * u)
        body = math.sin(phase) + 0.035 * math.sin(2 * phase)
        attack = math.sin(min(t / 0.045, 1.0) * math.pi / 2) ** 2
        release = math.sin(min((DURATION - t) / 0.16, 1.0) * math.pi / 2) ** 2
        envelope = attack * release * math.exp(-t / 0.19)
        samples.append((1.8 * rounded_air + 0.17 * body) * flutter * envelope)
    gain = 0.38 / max(abs(s) for s in samples)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), 'wb') as stream:
        stream.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        stream.writeframes(b''.join(struct.pack('<h', round(s * gain * 32767)) for s in samples))
    print(OUT)


if __name__ == '__main__':
    generate()
