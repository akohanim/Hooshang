#!/usr/bin/env python3
"""The Persian rosette that blooms on the office walls: a 128px light cookie.

A LIGHT TEXTURE, not wall art. `CanvasModulate` is 0.05 across Act I and
multiplies every CanvasItem, so a pattern painted onto the backdrop would come
out at a twentieth of what was drawn -- the same reason the sun shafts are
PointLight2Ds and not polygons (LIGHTING.md). Projected as a light it is exempt,
and it picks up the wall it lands on instead of sitting flatly on top of it.

So this is white with the shape in the ALPHA, and the colour comes from the
light's own `color` at runtime. That is what lets one texture cycle through a
whole psychedelic palette without a sheet per hue.

RADIALLY SOFT AT THE RIM, deliberately. A hard-edged cookie reads as a slide
projector pointed at a wall; this has to read as pattern surfacing out of the
dark and sinking back, so every element is a gaussian band and the whole thing
is multiplied by a falloff that reaches zero before the texture edge.

The motif is eightfold, like the dialogue trim's khatam (tools/gen_persian_trim.py)
-- a bright core, a star-pointed ring, and an outer petalled band. Eight because
that is the fold of Persian geometric ornament, and because at eight the petals
are still countable at 128px; sixteen turns to mush.

Re-run after editing: python3 tools/gen_persian_glyph.py
"""
import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "effects")
SIZE = 128
FOLD = 8

# Where each band sits, as a fraction of the radius, and how wide it is.
CORE_R = 0.12
STAR_R, STAR_W = 0.52, 0.038
STAR_WOBBLE = 0.16      # how star-pointed the inner ring is (0 = a circle)
OUTER_R, OUTER_W = 0.84, 0.030
PETAL_FLOOR = 0.30      # how much of the outer band survives between petals


def band(r, centre, width):
    return math.exp(-(((r - centre) / width) ** 2))


img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
px = img.load()
half = SIZE / 2.0

for y in range(SIZE):
    for x in range(SIZE):
        dx = (x - half + 0.5) / half
        dy = (y - half + 0.5) / half
        r = math.hypot(dx, dy)
        if r >= 1.0:
            continue
        th = math.atan2(dy, dx)
        petal = 0.5 + 0.5 * math.cos(FOLD * th)

        core = math.exp(-((r / CORE_R) ** 2))
        # The inner ring is pulled out into points, which is what makes it a
        # star rather than a circle -- the same union-of-two-squares silhouette
        # the trim uses, done here in polar because it has to stay soft.
        star = band(r, STAR_R * (1.0 - STAR_WOBBLE + STAR_WOBBLE * 2.0 * petal),
                    STAR_W)
        outer = band(r, OUTER_R, OUTER_W) * (PETAL_FLOOR + (1.0 - PETAL_FLOOR) * petal)
        # Hairlines from the core out to the star points: without them the rings
        # read as unrelated circles instead of one piece of ornament.
        spoke = math.exp(-(((1.0 - petal) / 0.06) ** 2)) * band(r, STAR_R * 0.6, 0.28)

        a = core * 0.85 + star * 0.9 + outer * 0.6 + spoke * 0.42
        # Reaches zero before the texture edge, so the light has no rim to it.
        a *= (1.0 - r) ** 0.55
        a = max(0.0, min(1.0, a))
        if a > 0.002:
            px[x, y] = (255, 255, 255, int(round(a * 255)))

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, "persian_glyph.png")
img.save(path)
print("wrote %s  %dx%d" % (path, img.width, img.height))
