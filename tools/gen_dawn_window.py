#!/usr/bin/env python3
"""The sunrise seen through an office window — the last room of Act I.

  assets/background/dawn_sky.png   40x54

This is the warm twin of assets/background/night_sky + moon.png. Every window in
Act I so far has been the SAME window: a cold blue rectangle with a moon in it,
passed twenty times on the way out and never once looked at. Room 22 is that
window with the night finished behind it, and it is the first and only warm
natural light in the Act — which is the entire reason the room exists.

WHY A GRADIENT AND NOT FLAT COLOUR. MoonWindow's sky is a single ColorRect,
which is right for a night sky: it is genuinely almost uniform. A dawn is not —
it is a vertical ramp from the last of the night at the top to the fire at the
horizon, and flattening that to one colour loses the only thing that says
"sunrise" rather than "someone left an orange light on".

SIZED TO MoonWindow's SkyPatch (40x54) so the two are interchangeable behind the
same 48x64 window_frame.png. Don't grow it: the frame's mullions are drawn at
fixed pixels and the sky has to sit behind them exactly.

Dithered, not banded. At 40px tall a smooth 54-step ramp lands 2-3 rows per
value and reads as stripes, so the ramp is ordered-dithered between neighbouring
stops instead — soft shading via dithering is the stated art direction
(CLAUDE.md), not a compromise.

Re-run after editing: python3 tools/gen_dawn_window.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "background")

W, H = 40, 54

# Top to bottom. The night does not end at the top of the frame — it is still up
# there, which is what makes the warmth at the bottom read as new.
#
# (position 0..1, r, g, b)
SKY = [
    (0.00, 22, 26, 58),     # last of the night
    (0.26, 46, 44, 84),     # indigo
    (0.48, 104, 66, 96),    # the violet band where night gives way
    (0.66, 176, 92, 88),    # rose
    (0.82, 232, 140, 78),   # amber
    (1.00, 255, 196, 116),  # the horizon itself, almost white-hot
]

# The sun, sitting ON the horizon line — half of it still below. A whole disc
# floating clear of the bottom reads as midday through tinted glass.
SUN_X, SUN_Y, SUN_R = 25.0, 47.0, 7.0
SUN_CORE = (255, 246, 214)
SUN_RIM = (255, 214, 150)

# Thin cloud bars. Horizontal, dark against the glow, unevenly spaced — they are
# here to break the ramp up so the eye has something to land on, so they go in
# the bright half where they actually show.
#
# TAPERED AT BOTH ENDS, which is the whole difference between a cloud and a
# rectangle. A bar that stops dead reads as a drawn line no matter how soft its
# top and bottom edge are.
CLOUDS = [
    # (y, x0, x1, half-thickness, darkness 0..1)
    (33.0, 2, 27, 1.5, 0.30),
    (39.5, 13, 39, 1.1, 0.24),
    (44.5, -2, 16, 1.0, 0.18),
]

# 4x4 ordered dither. Applied to the ramp's fractional position, so a pixel
# halfway between two stops takes one or the other by position rather than
# averaging into a new band.
BAYER = np.array([
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
], dtype=np.float64) / 16.0


def ramp(t: float) -> np.ndarray:
    """Colour at 0..1 down the sky, linearly between the SKY stops."""
    for i in range(len(SKY) - 1):
        p0, *c0 = SKY[i]
        p1, *c1 = SKY[i + 1]
        if t <= p1 or i == len(SKY) - 2:
            f = 0.0 if p1 == p0 else (t - p0) / (p1 - p0)
            f = min(max(f, 0.0), 1.0)
            return np.array(c0, dtype=np.float64) * (1 - f) \
                + np.array(c1, dtype=np.float64) * f
    return np.array(SKY[-1][1:], dtype=np.float64)


def main() -> None:
    px = np.zeros((H, W, 4), dtype=np.float64)

    for y in range(H):
        for x in range(W):
            # Nudge the sample point by the dither cell before reading the ramp:
            # neighbouring pixels land on either side of a stop instead of all
            # landing on the average of it.
            jitter = (BAYER[y % 4][x % 4] - 0.5) * (1.4 / H)
            px[y, x, :3] = ramp(min(max((y / (H - 1)) + jitter, 0.0), 1.0))
            px[y, x, 3] = 255.0

    for cy, x0, x1, half, dark in CLOUDS:
        mid = (x0 + x1) * 0.5
        reach = (x1 - x0) * 0.5
        for y in range(H):
            # A pixel of soft edge above and below, so a cloud is a smudge in
            # the haze rather than a drawn line.
            fade = max(0.0, 1.0 - abs(y - cy) / (half + 0.8))
            if fade <= 0.0:
                continue
            for x in range(W):
                # Cosine taper along the bar: full darkness in the middle,
                # nothing at the ends.
                t = abs(x - mid) / reach
                if t >= 1.0:
                    continue
                taper = 0.5 + 0.5 * np.cos(t ** 1.6 * np.pi)
                px[y, x, :3] *= 1.0 - dark * fade * taper

    core = np.array(SUN_CORE, dtype=np.float64)
    rim = np.array(SUN_RIM, dtype=np.float64)
    for y in range(H):
        for x in range(W):
            # Squashed vertically: the disc is sitting in thick air at the
            # horizon, and a perfect circle at 7px reads as a ball, not a sun.
            d = np.hypot(x - SUN_X, (y - SUN_Y) * 1.4)
            # Haze reaching well past the disc. Without it the sun is a sticker;
            # this is what makes it look like it is BEHIND the same air the
            # clouds are in.
            haze = np.exp(-((d / (SUN_R * 2.6)) ** 2)) * 0.55
            # The disc proper: hard-ish in the middle, one pixel of falloff.
            disc = min(max((SUN_R - d) / 1.6, 0.0), 1.0)
            glow = min(haze + disc, 1.0)
            if glow <= 0.004:
                continue
            tint = rim * (1 - disc) + core * disc
            px[y, x, :3] = px[y, x, :3] * (1 - glow) + tint * glow

    img = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "dawn_sky.png")
    img.save(path)
    print("wrote %s (%dx%d)" % (path, W, H))


if __name__ == "__main__":
    main()
