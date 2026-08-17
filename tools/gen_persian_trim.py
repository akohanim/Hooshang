#!/usr/bin/env python3
"""Persian border band for the dialogue box: one 32x16 tile that repeats.

Drawn in the DIALOGUE BOX's authoring space, not the game's. That box is a
CanvasLayer scaled 0.25 with its children laid out at 1280x720 (see
scenes/ui/dialogue_box.gd), so a pixel here is a quarter of a 320x180 design
pixel and this art is allowed the detail a 3px-tall gold bar never could be.
It is UI, not world art, and it never passes through the game viewport.

16px TALL is not an aesthetic choice, it is the gap in the layout. The banner's
name label starts at y=20 and the band hangs off the banner's own edge, so
anything taller draws underneath the speaker's name. Retune the two together.

A TILE, not a 1280-wide strip. The banner is a fixed width today and the trim
would fit, but it is drawn with STRETCH_TILE so nothing about it depends on that
-- and a strip sized to the banner would have to be redrawn the first time the
box changes width, which is the sort of coupling that gets discovered late.

The motif is khatam: the eight-pointed star that comes from overlaying a square
on itself turned 45 degrees. Stars sit at the tile centres with a lozenge on the
seam, so the seam carries half a lozenge on each side and reads as part of the
run rather than as where two copies meet -- which is the whole job of a repeat.

Gold matches the accent bar this replaces, Color(1, 0.82, 0.42).

Re-run after editing: python3 tools/gen_persian_trim.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui")

W, H = 32, 16
STAR_R = 5.5          # half-width of the star, in px
LOZENGE_R = 2.8       # the smaller diamond that sits on the seam
RULE_Y = (0, H - 1)   # the thin rules that close the band top and bottom

# Bright edge, dim interior: an outline-only motif disappears at a distance and
# a solid one reads as a gold blob, so it gets both.
INK = (255, 219, 128, 255)
FILL = (150, 108, 44, 190)
RULE = (255, 219, 128, 210)
RULE_SOFT = (150, 108, 44, 120)

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()

CY = H / 2.0 - 0.5


def star(dx, dy, r):
    """Khatam: a diamond unioned with a square, which is an 8-pointed star."""
    return (abs(dx) + abs(dy) <= r) or (max(abs(dx), abs(dy)) <= r * 0.70)


def inside(x, y):
    dy = y - CY
    # Star at the tile centre.
    if star(x - (W / 2.0 - 0.5), dy, STAR_R):
        return True
    # Lozenge straddling the seam: drawn at BOTH edges so the two halves meet
    # when the tile repeats.
    for cx in (-0.5, W - 0.5):
        if abs(x - cx) + abs(dy) <= LOZENGE_R:
            return True
    # The rail joining them, one pixel of body so the run reads as continuous.
    return abs(dy) <= 0.5


for y in range(H):
    for x in range(W):
        if inside(x, y):
            px[x, y] = FILL

# Outline: any filled pixel with an empty 4-neighbour. Done as a second pass so
# the shapes are unioned first and interior seams between them never draw.
edge = []
for y in range(H):
    for x in range(W):
        if px[x, y][3] == 0:
            continue
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if not (0 <= nx < W and 0 <= ny < H) or px[nx, ny][3] == 0:
                edge.append((x, y))
                break
for x, y in edge:
    px[x, y] = INK

for y in RULE_Y:
    for x in range(W):
        px[x, y] = RULE
# A softer inner rule a pixel in, so the band has a lip rather than a hard cut.
for y in (RULE_Y[0] + 1, RULE_Y[1] - 1):
    for x in range(W):
        if px[x, y][3] == 0:
            px[x, y] = RULE_SOFT

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, "persian_trim.png")
img.save(path)
print("wrote %s  %dx%d" % (path, img.width, img.height))
