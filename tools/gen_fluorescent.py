#!/usr/bin/env python3
"""The office fluorescent: a suspended tube fixture, drawn rather than greyboxed.

Two files, and the split is the point:

  fluorescent.png      the FIXTURE — housing, reflector wings, end caps, and a
                       dark diffuser. This is what the thing looks like with the
                       tube out, and it is drawn to read on its own.
  fluorescent_lit.png  the TUBE — only the glowing diffuser, on transparent.
                       Laid over the fixture and faded by the light's own
                       energy, so a flicker dims the fixture you can SEE and not
                       just the pool on the floor. A fluorescent whose pool
                       stutters while its tube stays lit reads as a bug.

NO STEMS IN THE ART. They are drawn by the prop (scenes/props/lighting/
fluorescent_tube.gd) as two rods of `cable_length`, exactly the way LampFixture
draws its cable, because the drop varies per instance — the same fixture hangs
28px under a painted ceiling in the office and 80px into an open shaft. Baking a
4px stem into a texture means either a fixture floating under a ceiling or one
crushed against it.

40x10 on the 8px grid: five cells wide, a bit over one tall. Office tubes are
long — that is most of what makes the silhouette read as a fluorescent and not a
lamp — but the game is 320x180, so 40 is already an eighth of the screen and 48
started to look like scenery rather than a fixture.

Per the art direction: soft shading and dithering, NOT flat 8-bit. The reflector
is a two-step gradient with a dither row between, the diffuser is brightest at
its middle and falls off towards the end caps, and the lit tube carries a hot
core with a soft bloom above it inside the housing.

Usage:  python3 tools/gen_fluorescent.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/props")

W, H = 40, 10
## The end caps, in pixels at each end. The diffuser lives between them.
CAP = 4

# Cold office metal, lit by its own tube from below.
PLATE = (176, 184, 194)
METAL = (116, 124, 136)
METAL_D = (74, 80, 92)
SHADOW = (44, 48, 58)
CAP_HI = (140, 148, 160)
CAP_LO = (62, 68, 80)
# The diffuser with the tube out: a dim grey-green perspex, not black.
DEAD_MID = (92, 98, 104)
DEAD_LOW = (66, 71, 78)
# ...and lit: cold white with a blue-green cast, the way a cheap tube reads.
TUBE_CORE = (247, 252, 255)
TUBE_MID = (206, 230, 242)
TUBE_EDGE = (150, 186, 210)
BLOOM = (120, 160, 190)


def dither(x, y):
    """2x2 ordered dither — enough to soften a two-tone step without reading
    as a pattern at this size."""
    return (x + y) % 2 == 0


def falloff(x):
    """1.0 in the middle of the diffuser, easing to ~0.45 at the end caps.

    A tube IS brighter in the middle — the ends are where the pins and the
    starter sit — and a flat bar of one colour is the single thing that makes a
    drawn fluorescent look like a sticker."""
    span = (W - 2 * CAP) / 2.0
    d = abs(x - (W - 1) / 2.0) / span
    return max(0.0, 1.0 - 0.55 * d * d)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def fixture():
    """The housing with the tube out — and it has to read on its own, because a
    dead fixture is set dressing this room actually uses."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for x in range(W):
        cap = x < CAP or x >= W - CAP
        if cap:
            # Solid metal ends: highlight near the top, shadow under, so they
            # read as the caps a tube slots into rather than two grey blocks.
            for y in range(H - 1):
                px[x, y] = (CAP_HI if y == 1 else
                            METAL if y < 4 else
                            METAL_D if y < 7 else CAP_LO) + (255,)
            px[x, H - 1] = SHADOW + (190,)
            continue
        # The top is against the ceiling and stays dark; the reflector below it
        # is what catches the tube.
        px[x, 0] = METAL_D + (255,)
        px[x, 1] = METAL + (255,)
        px[x, 2] = PLATE + (255,)                       # reflector highlight
        px[x, 3] = mix(METAL, METAL_D, 0.35 if dither(x, 3) else 0.65) + (255,)
        for y in range(4, 8):
            t = falloff(x) * (1.0 - (y - 4) * 0.22)     # dims towards the lip
            base = mix(DEAD_LOW, DEAD_MID, t)
            if not dither(x, y):
                base = mix(base, DEAD_LOW, 0.3)
            px[x, y] = base + (255,)
        px[x, 8] = METAL_D + (255,)
        px[x, 9] = SHADOW + (150,)
    return img


def tube():
    """Only what glows. Transparent everywhere else, so it can be faded over the
    fixture by the light's own energy."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for x in range(CAP, W - CAP):
        f = falloff(x)
        # The tube itself is a NARROW hot band with the diffuser glowing around
        # it. A wide even core reads as a light box, not a tube.
        for y in range(4, 8):
            band = [0.42, 1.0, 0.78, 0.34][y - 4]
            t = f * band
            col = mix(TUBE_EDGE, TUBE_MID, min(1.0, t * 1.3))
            if band > 0.7:
                col = mix(col, TUBE_CORE, 0.55 * f)
            a = int(235 * min(1.0, 0.18 + t * 0.9))
            if not dither(x, y) and t < 0.5:
                a = int(a * 0.75)
            px[x, y] = col + (a,)
        # Light thrown up into the reflector, and a lick under the lip.
        px[x, 2] = mix(BLOOM, TUBE_MID, f * 0.7) + (int(95 * f),)
        px[x, 3] = mix(BLOOM, TUBE_MID, f) + (int(160 * f),)
        px[x, 8] = mix(BLOOM, TUBE_MID, f * 0.5) + (int(95 * f),)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, img in (("fluorescent.png", fixture()),
                      ("fluorescent_lit.png", tube())):
        path = os.path.join(OUT, name)
        img.save(path)
        print("wrote %s  (%dx%d)" % (os.path.relpath(path, ROOT), *img.size))


if __name__ == "__main__":
    main()
