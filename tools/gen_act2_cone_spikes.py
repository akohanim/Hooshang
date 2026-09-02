#!/usr/bin/env python3
"""Act 2's cone-spike sheets: same geometry as tools/gen_cone_spikes.py, a warm
amber/citrine crystal palette instead of grey stone.

SAME TECHNIQUE, DUPLICATED RATHER THAN IMPORTED — same call as
tools/gen_act2_tileset_8px.py makes relative to gen_bricks_8px.py, and for the
same reason: gen_cone_spikes.py runs its whole generation at import time against
module-level globals (`px`, `W`, `H`, the CONE_*/BED_* colours) that its cone()/
bed() helpers close over directly rather than take as parameters, so reusing it
would mean monkey-patching another script's internal state instead of calling a
designed-to-be-shared function. A second self-contained copy of ~100 lines of
proven geometry is safer than that.

Everything about the SHAPE is unchanged: three-width cone taper (1-2-3px), the
same per-tile LAYOUT and LUMPS (so the sheet is still byte-identical run to
run), the same four facing transforms (flip/rotate the same 'up' tile — see
gen_cone_spikes.py's own note on why each transform keeps the light on the
correct face). Only CONE_*/BED_* change: gemstone amber/citrine facets instead
of pale stone, on a warm sandstone bed instead of cold slate — matching Act 2's
tileset (tools/gen_act2_tileset_8px.py) and the childhood-thought clouds
(tools/gen_act2_thought.py) rather than the office's cold palette.

Writes into assets/hazards/ only (act2_cone_spikes*.png) — no new ldtk/art
icons, since this does not add new LDtk entity defs; Act 2's existing
ConeSpikes* defs (borrowed from Act 1, see ldtk_add_act2_palette_field.py) get
a `ChildhoodPalette` field instead, read by cone_spikes.gd at runtime. The LDtk
editor's own placement icon still shows the office cones — a cosmetic mismatch
in the editor only, not in-game, the same limitation the thought-cloud palette
field has.

WATERCOLOR PASS (2026-09). PALETTE ONLY — THE TAPER GEOMETRY BELOW IS
DELIBERATELY UNTOUCHED. This is the one asset in the whole watercolor batch
where the module docstring above ALREADY explains why: Act 1's own cone
spikes generator found that photo/paint-sourced art turns to mush at this
scale and had to be hand-drawn with a deliberate 1-2-3px taper instead — the
apex has to stay legible as a single pixel-wide point, which is exactly the
kind of fine structure a generative image cannot be trusted to reproduce
after a hard reduction to an 8px cell (see
experiments/act2_watercolor/README.md's same conclusion for tiled/small
props generally). So this reads a Pixellab "pulled back" generation purely
for its COLOUR RAMP — CONE_LIGHT/MID/SHADE/EDGE below are its own most-common
opaque pixels, sorted by luminance — and changes not one pixel of cone(),
bed(), LUMPS or LAYOUT. BED_* is deliberately NOT sampled from the crystal
image at all: it reuses gen_act2_tileset_8px.py's own wall ramp (loaded from
the same ldtk/art/source/act2_wall.png the wall tileset reads), so the cones
visibly sit on the SAME sandstone the walls are built from rather than a
similar-but-different brown.

Source: assets/hazards/source/act2_crystal.png (Pixellab
create_image_pixflux, prompt "cluster of small amber and citrine crystal
spikes on warm sandstone, gem-cut facets catching sunlight... detailed pixel
art with watercolor-influenced soft gradient shading, clean crisp pixel
edges, restrained painterly bleed... warm sun-drenched palette of amber gold
and terracotta", seed 2203).

Re-run after editing: python3 tools/gen_act2_cone_spikes.py
"""
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 8
TILES = 5
W, H = CELL * TILES, CELL
BASE_TOP = 5


def _ramp_from_source(path, n=10):
    """Top-N most common opaque colours in a Pixellab source, sorted
    brightest to darkest. Same technique as the sibling generators; kept as
    its own copy per this project's self-contained-script convention."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


_CRYSTAL_RAMP = _ramp_from_source(
    os.path.join(ROOT, "assets", "hazards", "source", "act2_crystal.png"))
_WALL_RAMP = _ramp_from_source(
    os.path.join(ROOT, "ldtk", "art", "source", "act2_wall.png"), n=12)

# Amber/citrine crystal, lit from the upper left like every hazard in the
# project. Sampled from the crystal swatch: brightest facet sparkle, the two
# amber body stops, and its deepest gem-facet shadow for the edge.
CONE_LIGHT = _CRYSTAL_RAMP[0] + (255,)
CONE_MID = _CRYSTAL_RAMP[2] + (255,)
CONE_SHADE = _CRYSTAL_RAMP[4] + (255,)
CONE_EDGE = _CRYSTAL_RAMP[6] + (255,)
# Warm sandstone bed — reuses the WALL tileset's own ramp (not the crystal
# swatch) so the cones sit on the same stone the walls are built from.
BED_LIGHT = _WALL_RAMP[3] + (255,)
BED_MID = _WALL_RAMP[4] + (255,)
BED_DARK = _WALL_RAMP[6] + (255,)
BED_EDGE = _WALL_RAMP[-1] + (255,)

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c


def cone(ox, cx, height):
    for i in range(height):
        y = BASE_TOP - height + i
        t = i / max(height - 1, 1)
        w = 1 + int(round(2.0 * t))
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


LUMPS = {0: (1, 6), 1: (3,), 2: (0, 5), 3: (2, 7), 4: (1, 4)}


def bed(ox, cap_left, cap_right, tile):
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


LAYOUT = [
    ([(2, 5), (5, 4)], True, True),
    ([(2, 4), (5, 5)], True, False),
    ([(2, 5), (5, 3)], False, False),
    ([(3, 5)], False, False),
    ([(2, 3), (5, 5)], False, True),
]

for i, (cones, cap_l, cap_r) in enumerate(LAYOUT):
    ox = i * CELL
    bed(ox, cap_l, cap_r, i)
    for (cx, height) in sorted(cones, key=lambda c: -c[1]):
        cone(ox, cx, height)


def facing_up(tile):
    return tile


def facing_down(tile):
    return tile.transpose(Image.FLIP_TOP_BOTTOM)


def facing_right(tile):
    return tile.transpose(Image.ROTATE_270)


def facing_left(tile):
    return tile.transpose(Image.FLIP_LEFT_RIGHT).transpose(Image.ROTATE_90)


FACINGS = {
    "act2_cone_spikes": (facing_up, False),
    "act2_cone_spikes_down": (facing_down, False),
    "act2_cone_spikes_right": (facing_right, True),
    "act2_cone_spikes_left": (facing_left, True),
}

for name, (transform, vertical) in FACINGS.items():
    sheet = Image.new("RGBA",
        (CELL, CELL * TILES) if vertical else (CELL * TILES, CELL), (0, 0, 0, 0))
    for i in range(TILES):
        cell = transform(img.crop((i * CELL, 0, (i + 1) * CELL, CELL)))
        sheet.paste(cell, (0, i * CELL) if vertical else (i * CELL, 0))
    sheet.save(os.path.join(ROOT, "assets", "hazards", name + ".png"))
    print("wrote %s  %dx%d" % (name, sheet.width, sheet.height))
