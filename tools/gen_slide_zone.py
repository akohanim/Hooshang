#!/usr/bin/env python3
"""The slick floor of a SlideZone: one 80x16 sheet of five 16x16 tiles.

Tile order is [single][left cap][middle A][middle B][right cap], the same
convention as tools/gen_glass_spikes.py, so a stretch of any length is drawn
cap, middles, cap and never reads as one stamp repeated.

The look is polished-to-death office floor: a dark slab with a hard specular
line along the very top edge and a wet sheen smeared under it. The highlight is
BROKEN into dashes rather than run as a solid rule — an unbroken 1px line at the
top of a tile reads as a UI border, and this has to read as a surface.

Re-run after editing: python3 tools/gen_slide_zone.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 16
TILES = 5
W, H = CELL * TILES, CELL

SHEEN = (206, 222, 238, 255)     # the specular line along the top edge
WET = (120, 142, 166, 255)       # the smear under it
SLAB = (58, 66, 80, 255)         # the polished slab itself
SLAB_DEEP = (44, 50, 62, 255)    # shaded lower half
EDGE = (28, 32, 40, 255)         # bottom lip, and the cut ends

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c


# Where the top highlight is BROKEN, per tile. Different per tile so a long run
# has no rhythm to it — a repeating gap pattern is what makes tiling visible.
GAPS = {0: (5, 6, 12), 1: (3, 9, 10), 2: (1, 2, 8, 13), 3: (4, 5, 11), 4: (2, 7, 12, 13)}
# A second, dimmer sheen a couple of rows down: light catching a low ripple.
RIPPLE = {0: ((2, 3), (9, 12)), 1: ((6, 9),), 2: ((3, 5), (10, 14)),
          3: ((1, 4), (8, 10)), 4: ((5, 8), (12, 14))}


def slab(ox, tile, cap_left, cap_right):
    for y in range(H):
        for x in range(CELL):
            if y == H - 1:
                c = EDGE
            elif y >= H // 2:
                c = SLAB_DEEP
            else:
                c = SLAB
            put(ox + x, y, c)
    # Hard specular line along the top, broken where GAPS says.
    for x in range(CELL):
        if x not in GAPS[tile]:
            put(ox + x, 0, SHEEN)
    # The wet smear immediately under it, dimmer and broken differently.
    for x in range(CELL):
        if x not in GAPS[tile] and (x + tile) % 3:
            put(ox + x, 1, WET)
    for (a, b) in RIPPLE[tile]:
        for x in range(a, b):
            put(ox + x, 4, WET)
    # The ends are a cut through the slab, so they get the same dark lip the
    # bottom does — otherwise a strip fades into whatever is beside it.
    if cap_left:
        for y in range(H):
            put(ox, y, EDGE)
    if cap_right:
        for y in range(H):
            put(ox + CELL - 1, y, EDGE)


LAYOUT = [(0, True, True), (1, True, False), (2, False, False),
          (3, False, False), (4, False, True)]
for i, cap_l, cap_r in LAYOUT:
    slab(i * CELL, i, cap_l, cap_r)

for folder in ("assets/props", "ldtk/art"):
    img.save(os.path.join(ROOT, folder, "slide_floor.png"))
print("wrote slide_floor  %dx%d" % (W, H))
