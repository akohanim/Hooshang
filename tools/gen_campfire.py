#!/usr/bin/env python3
"""The campfire for Act 2's Jamshid encounter — a small animated flame over two
logs. Procedural PIL, not Pixellab: at ~16px this is exactly the reduced scale
CLAUDE.md's art rules say to keep CRISP and pulled-back (a heavy watercolor
bleed turns to mud this small), and a flame is a handful of warm bands that a
few hand-drawn frames read better than any downsampled generation would — the
same call gen_cone_spikes.py records for a 1px spike apex.

Output: assets/props/campfire/flame.png — a horizontal sheet of FRAMES cells,
each CELL_W x CELL_H, logs baked into the bottom of every frame so the prop is
one self-contained AnimatedSprite2D. The warm inner cone (white->yellow->orange
->deep red) sways and breathes per frame off a deterministic sine, so the loop
is smooth and reproducible run to run (no RNG, same reason the thought tiles are
hashed not random).

Usage:  python3 tools/gen_campfire.py
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "props", "campfire")
CELL_W, CELL_H = 16, 20
FRAMES = 6

# Warm flame ramp, hot core last. Logs are the last two browns.
CORE = (255, 246, 214)
INNER = (255, 214, 120)
MID = (255, 150, 54)
OUTER = (214, 74, 34)
EMBER = (150, 34, 26)
LOG_HI = (150, 104, 66)
LOG_LO = (96, 62, 40)


def _flame_layer(draw, cx, base_y, w, h, color):
    """A teardrop flame band: an ellipse body tapering to a point at the top."""
    draw.ellipse([cx - w / 2, base_y - h * 0.55, cx + w / 2, base_y], fill=color)
    draw.polygon([(cx - w / 2, base_y - h * 0.4), (cx + w / 2, base_y - h * 0.4),
                  (cx, base_y - h)], fill=color)


def _frame(i):
    img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    t = i / FRAMES * math.tau
    base_y = CELL_H - 4  # logs occupy the bottom 4px

    # Two crossed logs.
    d.line([(2, CELL_H - 2), (CELL_W - 3, CELL_H - 4)], fill=LOG_LO, width=2)
    d.line([(3, CELL_H - 4), (CELL_W - 2, CELL_H - 2)], fill=LOG_HI, width=2)

    sway = math.sin(t) * 1.4
    breathe = 1.0 + 0.12 * math.sin(t + 1.0)
    cx = CELL_W / 2 + sway
    # Outer -> core, each narrower/shorter and swaying a touch more at the tip.
    _flame_layer(d, cx, base_y, 11, 15 * breathe, OUTER)
    _flame_layer(d, cx + sway * 0.3, base_y, 8, 13 * breathe, MID)
    _flame_layer(d, cx + sway * 0.6, base_y - 1, 5, 10 * breathe, INNER)
    _flame_layer(d, cx + sway * 0.9, base_y - 2, 2.6, 6.5 * breathe, CORE)
    # A couple of embers rising, phased off the same clock.
    ey = base_y - 12 - (i % 3) * 3
    d.point((int(cx + 3), ey), fill=INNER)
    d.point((int(cx - 3), ey - 2), fill=MID)
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet = Image.new("RGBA", (CELL_W * FRAMES, CELL_H), (0, 0, 0, 0))
    for i in range(FRAMES):
        sheet.paste(_frame(i), (i * CELL_W, 0))
    path = os.path.join(OUT_DIR, "flame.png")
    sheet.save(path)
    print("wrote %s  (%d frames of %dx%d)" % (path, FRAMES, CELL_W, CELL_H))


if __name__ == "__main__":
    main()
