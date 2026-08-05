#!/usr/bin/env python3
"""Broken-glass spike sheets, one per surface the strip can be stuck to.

Writes four sheets of five 16x16 tiles each, into assets/hazards/ (what the
game draws) and ldtk/art/ (what the LDtk editor previews):

    glass_spikes.png        floor    80x16, points up
    glass_spikes_down.png   ceiling  80x16, points down
    glass_spikes_right.png  left wall   16x80, points right
    glass_spikes_left.png   right wall  16x80, points left

Tile order is always [single][first cap][middle A][middle B][last cap] — for a
floor strip "first" is the left end, for a wall strip it is the top. A strip of
any length is drawn cap, middles, cap, so it never reads as one stamp repeated.

Only the floor sheet is DRAWN. The other three are that sheet transformed, and
the transforms are chosen so the light keeps coming from the upper left in all
four (see FACINGS) rather than rotating with the spikes, which is what makes a
rotated sprite look like a rotated sprite.

Re-run after editing: python3 tools/gen_glass_spikes.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 16
TILES = 5
W, H = CELL * TILES, CELL

# Dirt-and-rubble bed the shards are set into.
BASE_TOP = 12          # first dirt row
GLASS_EDGE = (38, 54, 66, 255)
GLASS_DEEP = (120, 158, 178, 255)
GLASS_MID = (186, 212, 226, 255)
GLASS_LIGHT = (238, 246, 250, 255)
DIRT_EDGE = (42, 29, 22, 255)
DIRT_DARK = (74, 53, 39, 255)
DIRT_MID = (107, 79, 58, 255)
DIRT_LIGHT = (140, 108, 80, 255)

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c


# How tall a shard stands per pixel of its half-width. Shards are specified by
# WIDTH and the height follows, so every one of them keeps the same slope — the
# first pass set the two independently and the tall ones came out as 1px
# needles, a picket fence rather than broken glass.
SLOPE = 2.6


def shard(ox, apex_x, half, lean=0):
    """One triangular shard: apex at the top, `half` px each side at the bed.

    Lit from the left — a white face, a blue-grey body and a dark right edge —
    which is what makes a flat triangle read as glass rather than as a tooth.
    """
    apex_y = max(0, BASE_TOP - int(round(half * SLOPE)))
    span = BASE_TOP - apex_y
    for y in range(apex_y, BASE_TOP + 1):
        t = (y - apex_y) / span if span else 1.0
        w = int(round(half * t))
        cx = apex_x + int(round(lean * t))
        for x in range(cx - w, cx + w + 1):
            if x == cx + w and w > 0:
                c = GLASS_EDGE
            elif x == cx - w and w > 1:
                c = GLASS_DEEP if y > apex_y + 1 else GLASS_MID
            elif x <= cx:
                c = GLASS_LIGHT
            else:
                c = GLASS_MID
            put(ox + x, y, c)
        if w == 0:
            put(ox + cx, y, GLASS_LIGHT)


# Which columns of the bed rise a pixel above the rest. Fixed per tile so the
# top edge is a broken rubble line and not a ruler.
LUMPS = {0: (3, 4, 10), 1: (2, 8, 9), 2: (5, 6, 12), 3: (1, 7, 13), 4: (4, 10, 11)}


def bed(ox, cap_left, cap_right, tile):
    """The rubble the shards are set in, with a dark lip where it is cut."""
    for x in LUMPS[tile]:
        put(ox + x, BASE_TOP - 1, DIRT_DARK)
    for y in range(BASE_TOP, H):
        for x in range(CELL):
            if y == BASE_TOP:
                c = DIRT_DARK if (x + y) % 3 else DIRT_MID
            elif y == H - 1:
                c = DIRT_EDGE
            elif y == H - 2:
                c = DIRT_DARK
            else:
                c = DIRT_MID if (x * 5 + y * 3) % 4 else DIRT_LIGHT
            put(ox + x, y, c)
    # Speckles of grit, fixed positions so the tile is the same every import.
    for (x, y) in [(2, 13), (7, 12), (11, 14), (5, 14), (13, 12)]:
        put(ox + x, y, DIRT_DARK)
    if cap_left:
        for y in range(BASE_TOP, H):
            put(ox, y, DIRT_EDGE)
    if cap_right:
        for y in range(BASE_TOP, H):
            put(ox + CELL - 1, y, DIRT_EDGE)


# (shards, caps) per tile. Heights vary tile to tile so a long run reads as
# broken glass rather than as a comb; neighbouring tiles keep their outermost
# shards clear of the seam so nothing merges into a slab when they repeat.
LAYOUT = [
    # single: both ends capped
    ([(4, 2, 0), (9, 4, 0), (13, 2, 0)], True, True),
    # first cap
    ([(4, 3, 0), (9, 2, 0), (13, 4, -1)], True, False),
    # middle A
    ([(2, 2, 0), (7, 4, 1), (12, 3, 0)], False, False),
    # middle B
    ([(3, 4, 0), (8, 2, 0), (12, 3, -1)], False, False),
    # last cap
    ([(3, 2, 0), (7, 4, 0), (12, 3, 1)], False, True),
]

for i, (shards, cap_l, cap_r) in enumerate(LAYOUT):
    ox = i * CELL
    bed(ox, cap_l, cap_r, i)
    # Tallest first, so the short ones overlap IN FRONT and the row reads as
    # depth rather than as one sawtooth silhouette.
    for (ax, half, lean) in sorted(shards, key=lambda s: -s[1]):
        shard(ox, ax, half, lean)


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
    "glass_spikes": (facing_up, False),
    "glass_spikes_down": (facing_down, False),
    "glass_spikes_right": (facing_right, True),
    "glass_spikes_left": (facing_left, True),
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
