#!/usr/bin/env python3
"""A shaft of light, as a PointLight2D texture.

  assets/props/light_shaft.png   128x256

WHY THIS IS A LIGHT AND NOT A POLYGON. The obvious way to draw a sunbeam is a
soft translucent quad over the room. That does not work here: `CanvasModulate` is
0.05 across the whole Act, and it multiplies every CanvasItem — so a painted beam
comes out at 5% of whatever you drew and vanishes. Lights are the one thing
CanvasModulate does NOT touch; they add on top of it. Making the beam a light
means it is bright for exactly the same reason every other light in the game is,
and it lights what it falls across for free (LIGHTING.md).

APEX AT THE TEXTURE'S CENTRE, which is why the top half of the canvas is empty.
PointLight2D draws its texture centred on the node and scales about that centre,
so putting the beam's origin at the centre means the emission point stays pinned
to the node under any `texture_scale` and the beam rotates about the window it
comes from, rather than swinging around some point in mid-air. The wasted half is
transparent pixels on a 128x256 texture — nothing worth the coupling that fixing
it with an offset would buy.

WHITE, deliberately. The colour comes from the PointLight2D's `color`, so one
texture serves a gold sunrise, a cold moon shaft, or anything Act II wants.

Re-run after editing: python3 tools/gen_light_shaft.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props")

W, H = 128, 256
APEX_X, APEX_Y = W / 2.0, H / 2.0
LENGTH = H - APEX_Y          # the beam runs from the centre to the bottom edge

# Half-width at the apex and at the far end, in px. Nearly parallel on purpose:
# this is sunlight, and the sun is far enough away that a beam through a window
# barely spreads. A visible cone reads as a torch or a stage lamp.
#
# NARROW, because SunShaft draws several of these side by side and the dark gaps
# between them are the point. The first pass was 9 -> 22 and at three beams they
# merged back into one broad wedge with no frame-shadow in it at all.
WIDTH_NEAR, WIDTH_FAR = 6.0, 14.0

# How sharply the beam falls off across its width. Higher = crisper edge. Around
# 2 the edge is soft enough to read as air rather than as a drawn shape, and
# hard enough that the beam still has a direction.
EDGE = 1.6

# A brighter thread down the middle. This is the detail that separates "a shaft
# of light" from "a wedge of fog" — real beams have a hot core.
CORE_STRENGTH = 0.45
CORE_WIDTH = 0.34            # as a fraction of the beam's half-width

# Along the beam: fade in over the first slice (light leaving the window is
# already at full strength, but a hard start reads as a cut edge), hold, then
# die away. FADE_POW > 1 keeps it bright most of the way and drops it late,
# which is what makes the beam look long.
FADE_IN = 0.06
FADE_POW = 0.85

# Faint lengthwise streaking, so the beam is not a perfectly smooth airbrush.
# Very low: at 2-3x zoom this should be felt and not seen.
STREAKS = 7
STREAK_STRENGTH = 0.07


def main() -> None:
    px = np.zeros((H, W, 4), dtype=np.float64)
    rng = np.random.default_rng(7)
    # One phase per streak so they do not line up into a symmetric pattern.
    phases = rng.uniform(0.0, np.pi * 2.0, STREAKS)

    for y in range(H):
        t = (y - APEX_Y) / LENGTH        # 0 at the apex, 1 at the far end
        if t < 0.0:
            continue
        half = WIDTH_NEAR + (WIDTH_FAR - WIDTH_NEAR) * t
        along = min(t / FADE_IN, 1.0) * ((1.0 - t) ** FADE_POW)
        if along <= 0.0:
            continue
        for x in range(W):
            u = abs(x - APEX_X) / half
            if u >= 1.6:
                continue
            across = np.exp(-((u * EDGE) ** 2))
            core = CORE_STRENGTH * np.exp(-((u / CORE_WIDTH) ** 2))
            streak = 0.0
            for i in range(STREAKS):
                streak += np.sin((x - APEX_X) * (0.55 + i * 0.21) + phases[i])
            streak = streak / STREAKS * STREAK_STRENGTH * across
            v = (across + core + streak) * along
            if v <= 0.002:
                continue
            px[y, x, :3] = 255.0
            px[y, x, 3] = min(v, 1.0) * 255.0

    img = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "light_shaft.png")
    img.save(path)
    print("wrote %s (%dx%d)" % (path, W, H))


if __name__ == "__main__":
    main()
