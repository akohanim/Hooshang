#!/usr/bin/env python3
"""Paintable Act 2 water tiles for the `Water` IntGrid layer — the tile-based
counterpart to the resizable `Pond` entity (scenes/props/zones/pond.gd). Both
stay in the project side by side: `Pond` for a simple rectangular body you
drag and resize, this layer for an irregular shape you paint cell by cell,
with a real edge where the water meets a bank instead of a flat cut.

FIVE tile types on an 8px grid, laid out the same way tools/gen_thought_tiles.py
lays out ThoughtHazards — TILE_TYPES as COLUMNS, animation FRAMES as ROWS, so
scripts/ldtk_water_layer.gd can reuse that exact "col = tile type (fixed at
import), row = current frame (rewritten every tick)" contract:

    fill        the liquid's own body — soft horizontal caustic bands, not
                flat colour, so it reads as WATER regardless of what is
                behind it (see the revision note below for why that matters).
    top         fill + a bright, animated shimmer line along the top edge —
                the surface catching light.
    left        fill + a two-tone contact line down the left edge (a dark
                line right at the boundary, a bright one just inside it) —
                where painted water meets a wall. flipX (see the LDtk rule)
                mirrors this to the right edge for free — one drawn edge,
                two uses.
    corner      top's shimmer AND left's contact line combined, for a corner
                cell where the surface meets a wall. flipX+flipY covers the
                other three corners the same way. (A dedicated bottom/floor
                tile the way Pond now has one would need a whole SECOND
                north/south-checking rule pair to add safely — out of scope
                here; `top` flipped is what draws the bottom edge, same as
                before this revision.)
    fill_deep   a SEPARATE column, still — ldtk_water_layer.gd retargets a
                painted cell's FILL here at room-entry time once it measures
                the cell as far enough below the surface, which is how the
                per-cell depth tracking survives moving from a hand-sized
                Pond box (which always knew its own "row 0 = surface" by
                construction) to a freeformed painted shape (which does not,
                from LDtk's rule engine alone — an auto-rule only ever sees
                immediate-neighbour IntGrid values, never "how far down am
                I"). It now renders IDENTICALLY to `fill`, though (see the
                revision note below) — a distinct darker tone here used to be
                exactly what "deep" meant visually, but `left`/`corner` never
                read which column they sat next to and always drew the
                shallow tone regardless, so a shape spanning both bands
                showed a hard seam where the fill flipped tone plus a darker
                interior boxed in by lighter, unmatched wall columns.
                left/fill/fill_deep repeat the same image on all 3 rows
                rather than only having one row each, so the sheet stays ONE
                uniform grid and the runtime driver never needs to
                special-case which columns animate and which don't — it just
                never bothers re-picking a frame for them.

REVISION (liquid-in-a-container pass, matching tools/gen_pond_water.py's own
note): sparse dapple dots read as flecks floating in front of the backdrop, not
as the water's own structure — a screenshot of the shipped tiles next to real
brick read as tinted glass over the room's own parallax stripes. Soft banded
caustics fix that regardless of what is behind the water, and every edge that
touches a wall now gets the dark-contact-then-bright-highlight pairing real
liquid pressed against glass shows, instead of one flat highlight line.
`_SHADOW` is `_DEEP` scaled down, not a ramp colour — see gen_pond_water.py's
header for why (this source has nothing dark enough in it for a contact line).

Source: assets/props/pond/source/act2_pond_water.png — the SAME Pixellab
source (create_image_pixflux, "clear pond water surface with soft ripples...
watercolor-influenced soft gradient shading in turquoise, cobalt and pale
aqua... restrained painterly bleed", seed 2026) gen_pond_water.py already
reads for Pond's own art, so the two authoring paths read as the same water
rather than two different colour stories. GEOMETRY STAYS PROCEDURAL — same
rule as every other small/tiled Act 2 asset (see gen_pond_water.py's own
header for the fuller argument); only the colour ramp comes from Pixellab.

REAL ALPHA, same as Pond: every tile sits well under full opacity so whatever
the room painted underneath keeps reading through the water.

Output: ldtk/art/act2_water_tiles.png, 5 columns x 3 rows of 8x8 cells (40x24).

Re-run after editing: python3 tools/gen_act2_water_tiles.py
"""
import math
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ldtk", "art")
SOURCE = os.path.join(ROOT, "assets", "props", "pond", "source", "act2_pond_water.png")

CELL = 8
FRAMES = 3
# Column order = tileRectsIds in tools/ldtk_add_act2_water_tiles.py — the two
# files share this order by convention, not by import, so keep them in step.
TILE_TYPES = ["fill", "top", "left", "corner", "fill_deep"]


def _ramp_from_source(path, n=24):
    """Top-N most common opaque colours in a Pixellab source, sorted
    brightest to darkest. Same technique as every sibling generator; kept as
    its own copy per this project's self-contained-script convention."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


_RAMP = _ramp_from_source(SOURCE)
# Explicit indices, printed and checked against this exact source when this
# was written — same convention gen_magic_carpet.py's own note explains.
_HIGHLIGHT = _RAMP[0]   # (242, 252, 250) near-white shimmer/contact glint
_SHALLOW = _RAMP[10]    # (45, 246, 235) bright clear teal — the fill's ONLY tone now
_DEEP = _RAMP[21]       # (34, 191, 187) the ramp's darkest stop — no longer used for
                        # the fill itself, only to derive _SHADOW below
_SHADOW = tuple(int(c * 0.45) for c in _DEEP)  # see header note — not a ramp colour


def _lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[c] + (b[c] - a[c]) * t for c in range(3))


def _rgba(rgb, a):
    return (int(rgb[0]), int(rgb[1]), int(rgb[2]), a)


def _liquid_fill(px, dark, light, alpha, row_phase):
    """Soft horizontal caustic bands — the shared 'this is liquid' texture;
    see the revision note above for why this replaced isolated dapple dots."""
    for y in range(CELL):
        band = (math.sin((y + row_phase) * 1.05) + 1.0) * 0.5
        for x in range(CELL):
            drift = (math.sin(x * 0.8 - y * 0.4 + row_phase) + 1.0) * 0.5
            t = band * 0.7 + drift * 0.3
            px[x, y] = _rgba(_lerp(dark, light, t), alpha)


def _shimmer(px, shift):
    """The animated surface line: a bright band across row 0, with two
    hotter glint pixels that slide sideways by `shift` cells between the
    three frames."""
    for x in range(CELL):
        px[x, 0] = _rgba(_HIGHLIGHT, 160)
    for gx in (1, 5):
        px[(gx + shift) % CELL, 0] = _rgba(_HIGHLIGHT, 235)


def _wall(px):
    """Contact shadow + highlight down the left edge — where painted water
    meets a wall. flipX (the LDtk rule) mirrors this to the right edge."""
    for y in range(CELL):
        px[0, y] = _rgba(_SHADOW, 215)
        px[1, y] = _rgba(_HIGHLIGHT, 190)


def draw(tile_type, frame):
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()
    animated = tile_type in ("top", "corner")
    phase = frame * 2 if animated else 0
    # One fill tone for every tile type, `fill_deep` included (see the
    # fill_deep note above) — no more per-type dark/light pair, so there is
    # nothing left to mismatch against `left`/`corner`, which never varied
    # their own tone in the first place.
    light = _lerp(_SHALLOW, _HIGHLIGHT, 0.35)
    _liquid_fill(px, _SHALLOW, light, 150, phase)
    if animated:
        _shimmer(px, phase)
    if tile_type in ("left", "corner"):
        _wall(px)
    return img


os.makedirs(OUT, exist_ok=True)
sheet = Image.new("RGBA", (CELL * len(TILE_TYPES), CELL * FRAMES), (0, 0, 0, 0))
for frame in range(FRAMES):
    for col, tile_type in enumerate(TILE_TYPES):
        sheet.paste(draw(tile_type, frame), (col * CELL, frame * CELL))

path = os.path.join(OUT, "act2_water_tiles.png")
sheet.save(path)
print("wrote %s  %dx%d  (%d frames x %d tiles)"
      % (path, sheet.width, sheet.height, FRAMES, len(TILE_TYPES)))
