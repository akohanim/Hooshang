#!/usr/bin/env python3
"""Mushroom power-ups: cap + stem, one sheet per MushroomType (mushroom.gd).

One shape, recoloured per type — the same call dark_thought.gd's three tones
make (see gen_dark_thought.py): a second hand-drawn shape per colour is a
second chance for the silhouette to drift, and the whole point of "the same
power-up in a different colour" is that it reads as the same object.

Only BLACK_WHITE exists as a power today (see mushroom.gd's MushroomType), but
the shape is built from a PALETTE dict keyed by type name so a second colour is
a second palette entry and nothing else — no new drawing code.

BLACK_WHITE is a photo-negative of a normal toadstool on purpose: a black cap
with white spots is the palette's own tell for what the power does (turns the
world's dark/light thought-clouds off), the same way the grey thought-tiles
already read as "the hazard" before you touch them.

11x12 canvas: a domed cap over a short stem, small enough to sit convincingly
inside a 16px mystery box and still read as a creature at 1x scale next to a
9x12 Hooshang.

Re-run after editing: python3 tools/gen_mushroom.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "mushroom")

W, H = 11, 12
CAP_H = 6           # rows 0..5 are the dome
OUTLINE = (0x10, 0x10, 0x10, 255)

# Per-type palette: cap fill, cap highlight, spot colour, stem fill, stem
# shade. Keyed by the identifier mushroom.gd's MushroomType enum names map to
# (lower-cased), so a new enum value only needs a new row here.
PALETTES = {
    "black_white": {
        "cap": (0x1C, 0x1C, 0x1E, 255),
        "cap_hi": (0x3A, 0x3A, 0x3E, 255),
        "spot": (0xF2, 0xF2, 0xEC, 255),
        "stem": (0xEE, 0xE8, 0xD8, 255),
        "stem_lo": (0xC9, 0xC1, 0xAC, 255),
    },
}


def cap_mask():
    """Which (x, y) cells are inside the dome, and which are its RIM row (the
    bottom lip of the cap, drawn a shade darker so the dome reads as sitting
    OVER the stem rather than fused to it)."""
    cx = (W - 1) / 2.0
    cells = set()
    for y in range(CAP_H):
        # Wider each row down, narrowing back in at the very top — a dome, not
        # a triangle or a flat-topped block.
        half = (W / 2.0) * (0.35 + 0.65 * ((y + 0.5) / CAP_H)) ** 0.7
        for x in range(W):
            if abs(x - cx) <= half:
                cells.add((x, y))
    return cells


def draw(name, pal):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    cap = cap_mask()
    rim_y = CAP_H - 1

    for (x, y) in cap:
        px[x, y] = pal["cap_hi"] if y <= 1 else pal["cap"]
    # Spots: a few fixed positions relative to cap width, not random — the
    # sheet has to look the same on every regeneration.
    for (sx, sy) in ((2, 1), (5, 0), (8, 1), (3, 3), (7, 3)):
        if (sx, sy) in cap:
            px[sx, sy] = pal["spot"]
    # The rim: darken the bottom row of the dome so it reads as a lip.
    for (x, y) in cap:
        if y == rim_y:
            r, g, b, a = pal["cap"]
            px[x, y] = (max(r - 30, 0), max(g - 30, 0), max(b - 30, 0), a)

    # Stem: a short, slightly tapered column under the cap's middle.
    stem_w = 5
    sx0 = int((W - stem_w) / 2)
    for y in range(CAP_H, H):
        narrow = 1 if y == H - 1 else 0
        for x in range(sx0 + narrow, sx0 + stem_w - narrow):
            px[x, y] = pal["stem_lo"] if x in (sx0 + narrow, sx0 + stem_w - 1 - narrow) \
                else pal["stem"]

    # One-pixel outline around the whole silhouette — pop against a dark room,
    # the same reason the mystery box glyph gets a drop shadow.
    solid = set(cap)
    for y in range(CAP_H, H):
        narrow = 1 if y == H - 1 else 0
        for x in range(sx0 + narrow, sx0 + stem_w - narrow):
            solid.add((x, y))
    for (x, y) in list(solid):
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in solid:
                px[nx, ny] = OUTLINE

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "mushroom_%s.png" % name)
    img.save(path)
    print("wrote %s  %dx%d" % (path, img.width, img.height))


for name, pal in PALETTES.items():
    draw(name, pal)
