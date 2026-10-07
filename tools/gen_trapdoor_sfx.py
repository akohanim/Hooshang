#!/usr/bin/env python3
"""Rebuild the brief office-hatch latch release and body landing sounds."""
import math
from pathlib import Path
import random
import struct

ROOT = Path(__file__).resolve().parents[1] / 'assets/sfx'
RATE = 22050


def render(name, duration, landing=False):
    rng = random.Random(1415)
    samples = []
    low_noise = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        low_noise += 0.12 * (rng.uniform(-1, 1) - low_noise)
        envelope = math.exp(-t * (23 if landing else 10))
        bass = math.sin(math.tau * (72 if landing else 110) * t) * envelope
        if landing:
            value = bass * 0.5 + low_noise * math.exp(-t * 35) * 1.1
        else:
            ring = sum(math.sin(math.tau * f * t) * math.exp(-t * d)
                       for f, d in [(337, 16), (593, 21), (971, 29)])
            rattle = sum(math.exp(-max(t - start, 0) * 75) if t >= start else 0
                         for start in [0, 0.045, 0.10, 0.19, 0.24])
            value = bass * 0.25 + ring * 0.09 + low_noise * rattle * 0.75
        # Short attack and tail ramps avoid digital clicks.
        value *= min(1, t / 0.003, (duration - t) / 0.025)
        samples.append(int(max(-1, min(1, value)) * 32767))
    data = struct.pack('<' + 'h' * len(samples), *samples)
    # Native resources work in exports and fresh checkouts without raw-file
    # remapping or an editor audio-import pass.
    (ROOT / name).write_text(
        '[gd_resource type="AudioStreamWAV" format=3]\n\n[resource]\n'
        f'format = 1\nmix_rate = {RATE}\nstereo = false\n'
        'data = PackedByteArray(' + ', '.join(map(str, data)) + ')\n')


def render_open():
    """100 ms latch release and dry hinge tick; no sustained creak or ring."""
    rng = random.Random(1414)
    duration = 0.1
    samples = []
    last_noise = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        bright = noise - last_noise
        last_noise = noise
        latch = math.exp(-t * 95) * (bright * .20 + math.sin(math.tau * 780 * t) * .16)
        hinge_t = max(0, t - .026)
        hinge = 0 if t < .026 else math.exp(-hinge_t * 85) * (noise * .18 + math.sin(math.tau * 240 * hinge_t) * .24)
        ramp = min(1, t / .001, (duration - t) / .012)
        samples.append(int(max(-1, min(1, (latch + hinge) * ramp)) * 32767))
    data = struct.pack('<' + 'h' * len(samples), *samples)
    (ROOT / 'trapdoor_open.tres').write_text(
        '[gd_resource type="AudioStreamWAV" format=3]\n\n[resource]\n'
        f'format = 1\nmix_rate = {RATE}\nstereo = false\n'
        'data = PackedByteArray(' + ', '.join(map(str, data)) + ')\n')


if __name__ == '__main__':
    render_open()
    render('trapdoor_land.tres', 0.20, landing=True)
