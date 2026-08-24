#!/usr/bin/env python3
"""Small conical spike sheets, one per surface the strip can be stuck to.

Writes four sheets of five 8x8 tiles each, into assets/hazards/ (what the game
draws) and ldtk/art/ (what the LDtk editor previews):

    cone_spikes.png        floor    40x8, points up
    cone_spikes_down.png   ceiling  40x8, points down
    cone_spikes_right.png  left wall   8x40, points right
    cone_spikes_left.png   right wall  8x40, points left

Tile order is always [single][first cap][middle A][middle B][last cap] — for a
floor strip "first" is the left end, for a wall strip it is the top. A strip of
any length is drawn cap, middles, cap, so it never reads as one stamp repeated.

EIGHT PIXELS, NOT SIXTEEN. This is the same shape as gen_glass_spikes.py and
half the scale: one grid cell, not two. Everything below that looks like a magic
number is that halving meeting a slope that would not survive it — see CONES.

WHERE THE ART CAME FROM. Pixellab generated the source (160x32, job
8859b779-ed0d-400c-a025-55e058a8b18b, prompt asking for detailed pixel art with
soft shading and dynamic lighting, explicitly NOT 8-bit/NES). What is reused
from it is measured, not eyeballed: the palettes below are its five most common
cone colours and four most common bed colours, and the proportions come from its
thirteen cones. What is NOT reused is the bitmap, and that is the whole reason
this file exists rather than a crop:

  - DENSITY. It drew 13 cones across 160px, a 12.3px pitch. Reduced 4x to the
    40px sheet that is a cone every 3px — a picket fence, and at 8px tall the
    gaps between them close up entirely into a grey sawtooth band.
  - SLOPE. Its cones run height = 2.35 x half-width. Held at that, a cone tall
    enough to read (5px of the 8px cell) is 4-5px wide, so two of them plus a
    gap needs 10-12px in a cell that has 8. The cones here are steeper on
    purpose; it is the one proportion of the source that an 8px cell cannot
    take, and paired narrow spikes are what the hazard is meant to read as.
  - A 4x DOWNSAMPLE OF A 15px CONE IS MUSH. Five pixels of height is not enough
    for a resampler to keep a point on: box-averaging rounds the apex off and
    nearest-neighbour drops whole rows of the lit face. Redrawing keeps the
    apex one clean pixel wide, which is the only thing that says "spike".

Re-run after editing: python3 tools/gen_cone_spikes.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 8
TILES = 5
W, H = CELL * TILES, CELL

## First row of the base the cones are set in. Five rows of cone over three of
## base: the brief's ~5-6px of cone, and it matches the source's proportions
## more closely than it looks — its base was 9 of 32 rows, which is 2.25 here,
## and 3 rows is that rounded up so the base still has a lip and a floor.
BASE_TOP = 5

## Sampled from the Pixellab source: its five most common cone colours and four
## most common bed colours, in frequency order. Lit from the upper left, so the
## light face is the LEFT one — the same lighting direction every other hazard
## in the project is drawn with, and what FACINGS below is built to preserve.
CONE_LIGHT = (250, 238, 209, 255)
CONE_MID = (202, 189, 171, 255)
CONE_SHADE = (150, 135, 119, 255)
CONE_EDGE = (96, 84, 97, 255)
BED_MID = (75, 65, 81, 255)
BED_DARK = (53, 41, 56, 255)
BED_LIGHT = (96, 84, 97, 255)
BED_EDGE = (38, 28, 41, 255)

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c


def cone(ox, cx, height):
    """One cone: a single-pixel apex widening to three where it meets the base.

    THREE WIDTHS, NOT TWO. The first version stepped straight from a 1px apex to
    a 3px body, which at five rows tall is a stem on a block — it rendered as a
    row of flat-topped pillars, not spikes. Growing 1 - 2 - 3 puts a genuine
    slope on it, and two pixels is the only intermediate an 8px cell has room
    for.

    The even width is asymmetric on purpose: the extra pixel goes to the SHADED
    side, so the lit left face stays a straight edge all the way up. Splitting it
    the other way rounds the lit side off and the cone stops catching the light
    as one plane.
    """
    for i in range(height):
        y = BASE_TOP - height + i
        t = i / max(height - 1, 1)
        w = 1 + int(round(2.0 * t))            # 1, 2, 3
        left = cx if w < 3 else cx - 1
        for k in range(w):
            x = left + k
            if k == 0 and w > 1:
                c = CONE_LIGHT
            elif k == w - 1:
                c = CONE_EDGE if y == BASE_TOP - 1 else CONE_SHADE
            else:
                c = CONE_MID
            if w == 1:
                c = CONE_LIGHT
            put(ox + x, y, c)


## Which columns of the base rise a pixel. Fixed per tile so the top edge is a
## broken line and not a ruler, and so the sheet is byte-identical every run.
LUMPS = {0: (1, 6), 1: (3,), 2: (0, 5), 3: (2, 7), 4: (1, 4)}


def bed(ox, cap_left, cap_right, tile):
    """The base the cones are set in, with a dark lip where it is cut."""
    for y in range(BASE_TOP, H):
        for x in range(CELL):
            if y == H - 1:
                c = BED_EDGE
            elif y == BASE_TOP:
                c = BED_LIGHT if (x + tile) % 3 == 0 else BED_MID
            else:
                c = BED_DARK if (x * 3 + y) % 4 else BED_MID
            put(ox + x, y, c)
    for x in LUMPS[tile]:
        put(ox + x, BASE_TOP - 1, BED_MID)
    if cap_left:
        for y in range(BASE_TOP, H):
            put(ox, y, BED_EDGE)
    if cap_right:
        for y in range(BASE_TOP, H):
            put(ox + CELL - 1, y, BED_EDGE)


## (cones as (centre, height), cap_left, cap_right) per tile.
##
## Centres stay in columns 2..5 so no cone touches column 0 or 7: at this size a
## cone on the seam merges with its neighbour in the next tile and a run turns
## into one continuous ridge. Heights vary tile to tile, and MIDDLE_B is a
## single tall cone rather than a pair — the pattern that breaks up a long run
## is a missing spike, not a shorter one.
LAYOUT = [
    ([(2, 5), (5, 4)], True, True),     # single: capped both ends
    ([(2, 4), (5, 5)], True, False),    # first cap
    ([(2, 5), (5, 3)], False, False),   # middle A
    ([(3, 5)], False, False),           # middle B — one, on purpose
    ([(2, 3), (5, 5)], False, True),    # last cap
]

for i, (cones, cap_l, cap_r) in enumerate(LAYOUT):
    ox = i * CELL
    bed(ox, cap_l, cap_r, i)
    # Tallest first so a shorter neighbour overlaps IN FRONT of it, the same
    # reason gen_glass_spikes sorts its shards.
    for (cx, height) in sorted(cones, key=lambda c: -c[1]):
        cone(ox, cx, height)


def facing_up(tile):
    return tile


def facing_down(tile):
    """Ceiling. Flip vertically: 'up' becomes 'down' and the lit face, which is
    the left one, stays on the left where the light is."""
    return tile.transpose(Image.FLIP_TOP_BOTTOM)


def facing_right(tile):
    """Points right, so it is stuck to a LEFT wall. Rotating clockwise sends
    'up' to 'right' and the lit left face to the top — which is where a light
    in the upper left would put it anyway."""
    return tile.transpose(Image.ROTATE_270)


def facing_left(tile):
    """Points left, off a RIGHT wall. Mirror first, so the lit face moves to
    the right slope, THEN turn anticlockwise — 'up' goes to 'left' and the lit
    face lands on top again. Rotating alone would have lit it from below."""
    return tile.transpose(Image.FLIP_LEFT_RIGHT).transpose(Image.ROTATE_90)


# name -> (transform, is the strip vertical)
FACINGS = {
    "cone_spikes": (facing_up, False),
    "cone_spikes_down": (facing_down, False),
    "cone_spikes_right": (facing_right, True),
    "cone_spikes_left": (facing_left, True),
}

for name, (transform, vertical) in FACINGS.items():
    sheet = Image.new("RGBA",
        (CELL, CELL * TILES) if vertical else (CELL * TILES, CELL), (0, 0, 0, 0))
    for i in range(TILES):
        cell = transform(img.crop((i * CELL, 0, (i + 1) * CELL, CELL)))
        sheet.paste(cell, (0, i * CELL) if vertical else (i * CELL, 0))
    for folder in ("assets/hazards", "ldtk/art"):
        sheet.save(os.path.join(ROOT, folder, name + ".png"))
    print("wrote %s  %dx%d" % (name, sheet.width, sheet.height))
