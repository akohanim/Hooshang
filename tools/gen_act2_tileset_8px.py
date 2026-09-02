#!/usr/bin/env python3
"""Act 2's Collisions-layer tileset: warm sandstone wall with glazed-tile trim.

Same technique as tools/gen_bricks_8px.py, on purpose — FOUR tiles is the whole
tileset there because the `brick` IntGrid value's four auto-rules only ever ask
for fill / top edge / left edge / top-left corner (confirmed by reading
hooshang_act2.ldtk's own rule data: rule uid 36 -> tileRectsIds [[0]] pattern
[2] = fill, uid 34 -> [[1]] flipY = top, uid 35 -> [[2]] flipX = left, uid 33 ->
[[3]] flipX+flipY = corner). Act 2's Collisions layer already carries those same
four rules (copied from Act 1 as scaffolding) referencing tile ids 0-3 by
POSITION, not by name, so a replacement sheet that keeps that exact order works
with zero rule edits — this script only has to match the order, not reinvent it.

Act 1's ceiling_flor/ceiling IntGrid values (the suspended office ceiling, tile
ids 4-7 on Act 1's 8-tile sheet) are NOT reproduced here. That is an office
fixture with no equivalent in a sun-drenched childhood-memory world, and it is
out of this task's scope to paint one; a level that never uses those IntGrid
values never asks the sheet for tiles past index 3.

WATERCOLOR PASS (2026-09). PALETTE ONLY, GEOMETRY UNCHANGED — this reads a
Pixellab "pulled back" watercolor generation (soft gradient shading, crisp
pixel edges, restrained bleed; see experiments/act2_watercolor/README.md for
why "pulled back" and not the heavier-bleed variant: heavy bleed measurably
turns to mud once reduced to an 8px tile, and this auto-tiles onto the SAME
8px grid) and pulls its actual pixel colours rather than hand-picked hex, but
keeps gen_bricks_8px.py's coursing geometry (brick_px()) untouched. The auto-
rules MIRROR this art (flipX/flipY) to build the other three orientations, so
nothing here may draw an asymmetric detail that only reads one way up.

Source: ldtk/art/source/act2_wall.png (Pixellab create_image_pixflux, prompt
"Persian sandstone brick wall with glazed turquoise and cobalt mosaic tile
trim... detailed pixel art with watercolor-influenced soft gradient shading,
clean crisp pixel edges, restrained painterly bleed, not flat 8-bit NES retro
... sun-drenched warm palette of ochre gold turquoise and terracotta", seed
2201). _ramp_from_source() reads it back and sorts its most-common opaque
colours by luminance, so the FACE/MORTAR/GLAZE ramp below is literally sampled
from that PNG (re-running this script re-reads the file; replacing the source
changes the wall). The five FACE/MORTAR stops came from the wall's own
brick pixels; GLAZE reuses a turquoise accent that showed up unprompted at
3.5% of the image (an amazing coincidence with the OLD hand-picked GLAZE hue,
kept as the anchor) with a lightened/darkened pair computed around it, since
the source never happened to paint a full three-step turquoise ramp on its
own.

Re-run after editing: python3 tools/gen_act2_tileset_8px.py
"""
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ldtk", "art")
SOURCE = os.path.join(OUT, "source", "act2_wall.png")
CELL = 8


def _ramp_from_source(path, n=12):
    """The N most common opaque colours in a Pixellab source PNG, sorted
    brightest to darkest (perceptual luminance). Deterministic and re-derived
    on every run — this is the actual "process the source" step the project's
    gen_*.py convention calls for, just done by frequency+luminance rather
    than by connectivity/crop (there is no single 'the shape' to cut out of a
    texture swatch the way gen_dark_thought.py cuts frames from a strip)."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


def _lighten(c, t):
    return tuple(int(round(c[i] + (255 - c[i]) * t)) for i in range(3))


def _darken(c, t):
    return tuple(int(round(c[i] * (1.0 - t))) for i in range(3))


_RAMP = _ramp_from_source(SOURCE)
# Turquoise/cobalt accent pixels the wall swatch happened to paint in (a
# window or trim fleck), picked out from the general sandstone ramp by hue
# rather than by rank — the swatch never devotes enough of itself to the
# glaze trim to rank in the top brightness stops.
_TEAL = next((c for c in _RAMP if c[1] > c[0] and c[2] > c[0] and c[1] > 90),
             (46, 136, 143))

# Sandstone block face, lit top to bottom like the office brick's FACE ramp,
# so the same brick_px() shading logic reads correctly on a new palette.
# Indices are the wall swatch's own brightest-to-darkest sandstone stops.
FACE_HI = _RAMP[0] + (255,)
FACE = _RAMP[1] + (255,)
FACE_LO = _RAMP[4] + (255,)
# Every second block along a course is a shade off, same anti-stripe rule as
# the office wall (keyed off the block's x index, not random, for the same
# "re-run must give the same sheet" reason).
FACE_ALT = _RAMP[3] + (255,)
MORTAR = _RAMP[-1] + (255,)

# Glazed tile trim: turquoise highlight, cobalt body, deep-navy shadow line —
# the same three-band structure as the office's STONE_HI/STONE/STONE_DARK, so
# a corner still reads as one strip turning rather than two strips meeting.
GLAZE_HI = _lighten(_TEAL, 0.45) + (255,)
GLAZE = _TEAL + (255,)
GLAZE_DARK = _darken(_TEAL, 0.45) + (255,)

BRICK_W = 8
COURSE_H = 4


def brick_px(x, y):
    """One pixel of the sandstone coursing, in TILE coordinates.

    Identical structure to gen_bricks_8px.py's brick_px(): a running-bond fill
    with a half-block offset per course, so it tiles seamlessly in both axes —
    only the palette differs.
    """
    course = y // COURSE_H
    row_in = y % COURSE_H
    if row_in == COURSE_H - 1:
        return MORTAR
    offset = 0 if course % 2 == 0 else BRICK_W // 2
    if (x - offset) % BRICK_W == 0:
        return MORTAR
    index = (x - offset) // BRICK_W
    base = FACE if index % 2 == 0 else FACE_ALT
    if row_in == 0:
        return FACE_HI
    if row_in == COURSE_H - 2:
        return FACE_LO
    return base


def draw(top, left):
    """One tile: sandstone fill, with a glazed-tile lip on the requested sides."""
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()
    for y in range(CELL):
        for x in range(CELL):
            px[x, y] = brick_px(x, y)
    if top:
        for x in range(CELL):
            px[x, 0] = GLAZE_HI
            px[x, 1] = GLAZE
            px[x, 2] = GLAZE_DARK
    if left:
        for y in range(CELL):
            px[0, y] = GLAZE_HI
            px[1, y] = GLAZE
            px[2, y] = GLAZE_DARK
    if top and left:
        # The corner belongs to the top run, same convention as the office
        # wall, so it reads as one lip turning rather than a seam.
        px[0, 0] = GLAZE_HI
        px[1, 0] = GLAZE_HI
        px[2, 0] = GLAZE_HI
        px[0, 1] = GLAZE_HI
        px[1, 1] = GLAZE
        px[2, 1] = GLAZE
        px[0, 2] = GLAZE_HI
        px[1, 2] = GLAZE
        px[2, 2] = GLAZE_DARK
    return img


# Order IS the tile id the existing rules use — do not reorder.
TILES = [
    ("fill", False, False),
    ("top", True, False),
    ("left", False, True),
    ("corner", True, True),
]

sheet = Image.new("RGBA", (CELL * len(TILES), CELL), (0, 0, 0, 0))
for i, (_name, top, left) in enumerate(TILES):
    sheet.paste(draw(top, left), (i * CELL, 0))

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, "act2_tileset_8px.png")
sheet.save(path)
print("wrote %s  %dx%d  (%s)"
      % (path, sheet.width, sheet.height, ", ".join(t[0] for t in TILES)))
