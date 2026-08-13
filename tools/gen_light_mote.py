#!/usr/bin/env python3
"""A single speck of dust hanging in a sunbeam.

  assets/props/light_mote.png   8x8

NOT the same thing as debris_dust.png, and the difference matters. That one is
rubbish coming off a collapsing ceiling: several pixels, a definite shape, drawn
to be seen falling. This one is meant to be almost nothing — one soft round point
that only exists because a beam of light happened to catch it.

The first pass at room 22 reused debris_dust and it read as small chevrons
drifting through the air, because at 4x4 with several lit pixels a mote HAS a
shape, and a rotating particle shows it to you. A mote must not have a shape.

Radially symmetric on purpose, for the same reason: CPUParticles2D gives each
particle a random rotation, and anything that isn't a circle spins visibly.

Sized so it can be scaled DOWN. 8x8 with a ~3px core lands at 2-4px on screen at
the scales SunShaft uses, which at 320x180 is what a dust mote is.

Re-run after editing: python3 tools/gen_light_mote.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props")

N = 8
CENTRE = (N - 1) / 2.0
# Where the alpha has fallen to about a third. Small: the visible mote is the
# core, and the rest is the soft edge that stops it looking like a square.
SIGMA = 1.15

# White. What colour a mote appears is entirely the light it is sitting in —
# baking a tint in here would fight the beam it is meant to belong to.


def main() -> None:
    px = np.zeros((N, N, 4), dtype=np.float64)
    for y in range(N):
        for x in range(N):
            d = np.hypot(x - CENTRE, y - CENTRE)
            a = np.exp(-((d / SIGMA) ** 2))
            if a <= 0.02:      # trim the tail, or the sprite has a faint square
                continue
            px[y, x] = (255.0, 255.0, 255.0, min(a, 1.0) * 255.0)

    img = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "light_mote.png")
    img.save(path)
    print("wrote %s (%dx%d)" % (path, N, N))


if __name__ == "__main__":
    main()
