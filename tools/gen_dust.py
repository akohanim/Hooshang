#!/usr/bin/env python3
"""Dust puffs: three 8x8 tiles on one 24x8 sheet.

Kicked up under his feet on a jump, a landing and a dash start. Deliberately
NOT death_shard.png reused with a different tint: a shard is a hard-edged piece
of something breaking, and dust is the opposite reading — soft, shapeless, and
gone. Sharing the sheet would make a landing look like a small death.

Three sizes rather than one, so a puff of five reads as a cloud rather than as
five copies of a sprite. Each is a soft radial falloff (alpha, not colour) so it
fades at the rim rather than ending on a hard circle — the project's art
direction is detailed pixel art with soft shading, not flat retro (CLAUDE.md).

White, so a single export tints the whole puff per Act.

Re-run after editing: python3 tools/gen_dust.py
"""
import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "effects")
CELL = 8
# radius, and how hard the core is. A small puff is denser than a big one, which
# is what keeps the big one reading as the one that has already spread out.
SHAPES = ((3.4, 0.55), (2.6, 0.75), (1.8, 0.95))

img = Image.new("RGBA", (CELL * len(SHAPES), CELL), (0, 0, 0, 0))
px = img.load()

for i, (radius, core) in enumerate(SHAPES):
    ox = i * CELL
    cx = cy = (CELL - 1) / 2.0
    for y in range(CELL):
        for x in range(CELL):
            d = math.hypot(x - cx, y - cy)
            if d > radius:
                continue
            # Flat core out to `core` of the radius, then a smooth fade to 0.
            t = max(0.0, (d - radius * core) / max(radius * (1.0 - core), 0.001))
            a = int(round(255 * (1.0 - t) ** 1.6))
            if a > 0:
                px[ox + x, y] = (255, 255, 255, a)

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, "dust_puff.png")
img.save(path)
print("wrote %s  %dx%d" % (path, img.width, img.height))
