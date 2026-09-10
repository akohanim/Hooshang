#!/usr/bin/env python3
"""Pond water: a 10-tile x 3-frame sheet for scenes/props/zones/pond.gd —
TOP/LEFT/RIGHT/BOTTOM edges (plus the four corners) around a single uniform
fill, so a Pond reads as liquid actually CONTAINED by whatever is built
around it — brick, most of the time — rather than a translucent rectangle
with nothing at its own boundary. pond.gd lays these out over the whole box
the same way SlideZone lays its own floor sheet (tools/gen_slide_zone.py):
one AtlasTexture per cell, tiled and edge-picked to fit however the Pond is
dragged in LDtk.

REVISION (liquid-in-a-container pass). Two things changed from the version
this replaced, both aimed at the same complaint — a screenshot of the shipped
water next to real brick read as "a tinted window over the level's own
parallax stripes," not water:

1. **The fill is a soft banded CAUSTIC pattern now, not sparse dapple dots.**
   Isolated highlight dots read as flecks floating IN FRONT of whatever is
   behind the water; soft horizontal bands (light bending through a body of
   liquid) read as the water's OWN internal structure regardless of what is
   behind it, which is what actually stops it looking like recoloured
   background. Alpha is higher too (was 118/168, now 150/195) — still real
   transparency, just no longer so thin that a busy backdrop overpowers it.

2. **Every edge that would touch a container wall gets a two-tone contact
   line: a dark line right at the boundary, a bright one just inside it.**
   This is the classic "liquid pressed against glass" cue — a contact shadow
   (the wall casting into the liquid) plus a meniscus/refraction highlight —
   and it is what a flat cut can never sell. TOP additionally gets the
   animated shimmer band; BOTTOM gets the same two-tone line turned into a
   floor-contact/sediment read instead. The four corners combine whichever
   pair of edges meet there.

Sheet layout — TILE_TYPES as COLUMNS (10), animation FRAMES as ROWS (3),
mirroring the exact "col = type, row = frame" contract
tools/gen_thought_tiles.py and scripts/ldtk_water_layer.gd already use:

    TOP, TOP_LEFT, TOP_RIGHT, LEFT, RIGHT, BOTTOM, BOTTOM_LEFT,
    BOTTOM_RIGHT, FILL_SHALLOW, FILL_DEEP

Only the TOP/TOP_LEFT/TOP_RIGHT columns actually differ frame to frame (the
surface shimmer); the rest repeat their one drawn frame on all 3 rows so the
sheet stays a single uniform grid pond.gd can index without special-casing
which columns animate.

FILL_SHALLOW and FILL_DEEP are still two distinct columns structurally —
pond.gd still picks between them by row — but they now render IDENTICALLY.
A separate darker tone for FILL_DEEP used to be exactly what "deep" meant
visually, but it fought the wall/edge tiles: LEFT/RIGHT/TOP_LEFT/TOP_RIGHT
always drew the shallow tone regardless of which rows pond.gd actually spans
them across (pond.gd runs LEFT/RIGHT down the pond's full height, past the
shallow/deep boundary), so a tall pond showed a hard seam where the fill
tone flipped plus a darker interior rectangle boxed in by lighter wall
columns that never got the memo. Simplest fix: one fill tone, everywhere —
see `draw()` below. Anything that wants a real depth cue again later should
build it as a gradient the wall tiles also participate in, not a second flat
colour only the fill knows about.

Source: assets/props/pond/source/act2_pond_water.png (Pixellab
create_image_pixflux, "clear pond water surface with soft ripples and light
refraction... watercolor-influenced soft gradient shading in turquoise,
cobalt and pale aqua... restrained painterly bleed", seed 2026). GEOMETRY
STAYS PROCEDURAL — only the colour ramp comes from Pixellab, same rule every
small/tiled Act 2 asset in this project follows.

`_SHADOW` IS A DELIBERATE DEPARTURE FROM THE EXTRACTED RAMP, same call
tools/gen_spring_platform.py's own grey makes and for the same reason: this
source is a bright, sunlit swatch (Act 2's own mood) with nothing dark enough
in it to read as a contact shadow — its darkest stop is still a fairly
saturated mid-teal. A contact line needs to be visibly DARKER than the body
it sits against or it doesn't read as a line at all, so it is `_DEEP` scaled
down rather than a fifth colour picked from a ramp that does not have one.

Output: assets/props/pond/pond_water.png, 80x24 (10 cols x 3 rows of 8x8).

Re-run after editing: python3 tools/gen_pond_water.py
"""
import math
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "pond")
SOURCE = os.path.join(OUT, "source", "act2_pond_water.png")

CELL = 8
FRAMES = 3
TILE_TYPES = ["top", "top_left", "top_right", "left", "right",
              "bottom", "bottom_left", "bottom_right", "fill_shallow", "fill_deep"]


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
_HIGHLIGHT = _RAMP[0]    # (242, 252, 250) near-white shimmer/meniscus glint
_SHALLOW = _RAMP[10]     # (45, 246, 235) bright clear teal — the fill's ONLY tone now
_DEEP = _RAMP[21]        # (34, 191, 187) the ramp's darkest stop — no longer used for
                         # the fill itself, only to derive _SHADOW below
_SHADOW = tuple(int(c * 0.45) for c in _DEEP)  # see header note — not a ramp colour


def _lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[c] + (b[c] - a[c]) * t for c in range(3))


def _rgba(rgb, a):
    return (int(rgb[0]), int(rgb[1]), int(rgb[2]), a)


def _liquid_fill(px, dark, light, alpha, row_phase):
    """Soft horizontal caustic bands — light bending through a body of
    liquid — rather than isolated dapple dots, so the water reads as having
    its OWN structure instead of just tinting whatever sits behind it."""
    for y in range(CELL):
        band = (math.sin((y + row_phase) * 1.05) + 1.0) * 0.5
        for x in range(CELL):
            drift = (math.sin(x * 0.8 - y * 0.4 + row_phase) + 1.0) * 0.5
            t = band * 0.7 + drift * 0.3
            px[x, y] = _rgba(_lerp(dark, light, t), alpha)


def _shimmer(px, shift):
    """The animated surface line: a bright band across row 0, with two
    hotter glint pixels sliding sideways by `shift` cells between frames."""
    for x in range(CELL):
        px[x, 0] = _rgba(_HIGHLIGHT, 160)
    for gx in (1, 5):
        px[(gx + shift) % CELL, 0] = _rgba(_HIGHLIGHT, 235)


def _wall_left(px):
    """Contact shadow + meniscus highlight down the left edge — where the
    liquid meets a container wall (a brick column, most of the time)."""
    for y in range(CELL):
        px[0, y] = _rgba(_SHADOW, 215)
        px[1, y] = _rgba(_HIGHLIGHT, 190)


def _wall_right(px):
    for y in range(CELL):
        px[CELL - 1, y] = _rgba(_SHADOW, 215)
        px[CELL - 2, y] = _rgba(_HIGHLIGHT, 190)


def _floor(px):
    """The same contact-line idea, turned horizontal for the container's own
    floor — a dark pressure line with a faint reflected highlight above it,
    read as sediment/weight rather than a meniscus."""
    for x in range(CELL):
        px[x, CELL - 1] = _rgba(_SHADOW, 225)
        px[x, CELL - 2] = _rgba(_HIGHLIGHT, 150)


def draw(tile_type, frame):
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()
    animated = tile_type.startswith("top")
    # Only the animated columns' fill actually varies by frame — everything
    # else draws frame 0's pixels on every row, so the sheet's "extra" rows
    # for a static column are pixel-identical rather than wasted variation
    # nothing ever reads (pond.gd always samples row 0 for a static type).
    phase = frame * 2 if animated else 0
    # One fill tone for every tile type (see the FILL_SHALLOW/FILL_DEEP note
    # above) — no more per-type dark/light pair, so there is nothing left to
    # mismatch against the wall tiles, which never varied their own tone.
    light = _lerp(_SHALLOW, _HIGHLIGHT, 0.35)
    _liquid_fill(px, _SHALLOW, light, 150, phase)
    if animated:
        _shimmer(px, phase)
    if tile_type.startswith("bottom"):
        _floor(px)
    if tile_type.endswith("left"):
        _wall_left(px)
    if tile_type.endswith("right"):
        _wall_right(px)
    return img


os.makedirs(OUT, exist_ok=True)
sheet = Image.new("RGBA", (CELL * len(TILE_TYPES), CELL * FRAMES), (0, 0, 0, 0))
for frame in range(FRAMES):
    for col, tile_type in enumerate(TILE_TYPES):
        sheet.paste(draw(tile_type, frame), (col * CELL, frame * CELL))

path = os.path.join(OUT, "pond_water.png")
sheet.save(path)
print("wrote %s  %dx%d  (%d frames x %d tiles)"
      % (path, sheet.width, sheet.height, FRAMES, len(TILE_TYPES)))
