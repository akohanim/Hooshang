#!/usr/bin/env python3
"""Magic carpet art: one repeating 16x8 rug tile per CarpetPattern.

Four sheets, one per scenes/props/zones/magic_carpet.gd's CarpetPattern value
— RIDE / BOB / SWEEP / BOUNCE — each a different colour AND a different woven
motif, so which pattern a placed carpet uses is readable from the art alone
("paint the behavior, don't just rely on a tooltip" — the same reasoning
DarkThought's tone-specific sheets and ConeSpikes' four facings both already
follow).

The border-plus-motif technique and the khatam "diamond unioned with square is
an eight-point star" trick are lifted straight from tools/gen_persian_trim.py's
`star()`, at a smaller radius, so the carpet's motifs read as the same visual
language as the dialogue box's own Persian trim rather than inventing a new one.

Each tile repeats SEAMLESSLY on its own (no separate end-cap art) — the motif
period divides the tile width evenly, and the gold border runs the full top and
bottom edge, so laying copies edge to edge (magic_carpet.gd's own tile-laying,
copying platform.gd's technique) reads as one continuous rug.

WATERCOLOR PASS (2026-09). PALETTE ONLY — THE FOUR MOTIFS (star/wave/chevron/
burst) AND THEIR TILING MATH ARE UNCHANGED. Each pattern's period has to
divide the 16px tile width evenly for the seamless-repeat contract in the
header above, which rules out cutting these from a generated bitmap the same
way gen_act2_cone_spikes.py's header already argues for the cone taper — see
that file's note, and experiments/act2_watercolor/README.md's general call
for tiled/small props. GOLD_HI/GOLD are read from a Pixellab source; the four
pattern fills are also each anchored to a colour actually sampled somewhere in
this Act's other watercolor generations, so RIDE/BOB/SWEEP/BOUNCE each read as
kin to a different one of this batch's other assets rather than four
arbitrary hues — BOB's teal is the wall tileset's own glaze accent, BOUNCE's
amber is the cone spikes' crystal body, SWEEP's violet is the thought-cloud
family, and RIDE's terracotta-crimson is the crystal's own deep gem-facet
shadow.

Source: assets/props/magic_carpet/source/act2_carpet_reference.png — this is
NOT a fresh generation for this prop specifically; it is the pulled-back
khatam/mosaic tile sample from the original watercolor art-direction
experiment (experiments/act2_watercolor/tile_khatam_watercolor_pulled_back.png,
prompt "khatam marquetry mosaic tile pattern, geometric star and cross
Persian tilework... detailed pixel art with watercolor-influenced flat colour
shading and crisp pixel edges... restrained painterly bleed... warm
sun-drenched palette of turquoise cobalt gold and terracotta", seed 202),
copied here because it is already exactly the "small geometric Persian motif,
pulled-back watercolor" reference this prop needs and a second generation
would only add sampling noise, not a materially different palette.

Re-run after editing: python3 tools/gen_magic_carpet.py
"""
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "magic_carpet")
LDTK_ART = os.path.join(ROOT, "ldtk", "art")
SOURCE = os.path.join(OUT, "source", "act2_carpet_reference.png")


def _ramp_from_source(path, n=14):
    """Top-N most common opaque colours in a Pixellab source, sorted
    brightest to darkest. Same technique as the sibling generators; kept as
    its own copy per this project's self-contained-script convention."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


_RAMP = _ramp_from_source(SOURCE)
# Indexed by hand against the khatam swatch's actual sorted ramp (gold stops
# first, teal stops trailing — printed and checked when this was written)
# rather than a hue-matching search: an earlier version of this script
# searched for "an amber" twice and both searches landed on the SAME stop,
# leaving the border gold and the BOUNCE fill identical and its own burst
# motif invisible against its background. Explicit indices avoid that class
# of bug recurring silently.
_TEAL = _RAMP[8]          # (39, 165, 177) — first of the swatch's teal run
_AMBER_DEEP = _RAMP[7]    # (229, 122, 44) — its deepest, most saturated gold

CELL_W, CELL_H = 16, 8
GOLD_HI = _RAMP[0] + (255,)   # (227, 199, 143) palest cream-gold
GOLD = _RAMP[3] + (255,)      # (234, 167, 69) solid gold border


def star(dx, dy, r):
    """Khatam motif: a diamond unioned with a square — an eight-point star.
    Copied from gen_persian_trim.py's star() at a smaller radius."""
    return (abs(dx) + abs(dy) <= r) or (max(abs(dx), abs(dy)) <= r * 0.70)


def _base(fill, border=GOLD, border_hi=GOLD_HI):
    img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    px = img.load()
    for y in range(CELL_H):
        for x in range(CELL_W):
            px[x, y] = fill
    for x in range(CELL_W):
        px[x, 0] = border_hi
        px[x, CELL_H - 1] = border
    return img, px


def draw_ride(fill):
    """RIDE: a row of small khatam medallions — the classic flying-carpet
    read, for the default player-steered pattern."""
    img, px = _base(fill)
    for cx in (3.5, 11.5):
        for y in range(1, CELL_H - 1):
            for x in range(CELL_W):
                if star(x - cx, y - (CELL_H / 2.0 - 0.5), 1.8):
                    px[x, y] = GOLD_HI
    return img


def draw_bob(fill):
    """BOB: a horizontal wave/ripple line — reads as up-down motion."""
    import math
    img, px = _base(fill)
    for x in range(CELL_W):
        wy = (CELL_H / 2.0 - 0.5) + math.sin(x / CELL_W * math.tau) * 1.6
        y = int(round(wy))
        if 1 <= y <= CELL_H - 2:
            px[x, y] = GOLD_HI
            if 1 <= y + 1 <= CELL_H - 2:
                px[x, y + 1] = GOLD
    return img


def draw_sweep(fill):
    """SWEEP: chevrons pointing sideways — reads as side-to-side travel."""
    img, px = _base(fill)
    for cx in (2, 6, 10, 14):
        for i in range(3):
            for dy in (-i, i):
                x = cx + i
                y = int(CELL_H / 2) + dy
                if 0 <= x < CELL_W and 1 <= y <= CELL_H - 2:
                    px[x, y] = GOLD_HI
    return img


def draw_bounce(fill):
    """BOUNCE: a tighter, spikier star — a burst of energy, echoing the
    spring platform's own coil read."""
    img, px = _base(fill)
    for cx in (3.5, 11.5):
        for y in range(1, CELL_H - 1):
            for x in range(CELL_W):
                if star(x - cx, y - (CELL_H / 2.0 - 0.5), 2.4) and \
                        not star(x - cx, y - (CELL_H / 2.0 - 0.5), 1.1):
                    px[x, y] = GOLD_HI
    return img


# Each fill anchored to a colour sampled somewhere else in this watercolor
# batch — see the header note on why these four hues aren't arbitrary.
_CRYSTAL_RAMP = _ramp_from_source(
    os.path.join(ROOT, "assets", "hazards", "source", "act2_crystal.png"))
_SLUDGE_RAMP = _ramp_from_source(
    os.path.join(ROOT, "assets", "hazards", "source", "act2_sludge.png"))

PATTERNS = [
    ("ride", _CRYSTAL_RAMP[6] + (255,), draw_ride),      # crystal's deep gem-edge red
    ("bob", _TEAL + (255,), draw_bob),                   # wall tileset's own glaze teal
    ("sweep", _SLUDGE_RAMP[4] + (255,), draw_sweep),      # thought-cloud violet family
    ("bounce", _AMBER_DEEP + (255,), draw_bounce),         # crystal/cone amber family
]

os.makedirs(OUT, exist_ok=True)
os.makedirs(LDTK_ART, exist_ok=True)

for name, fill, fn in PATTERNS:
    tile = fn(fill)
    path = os.path.join(OUT, "%s.png" % name)
    tile.save(path)
    print("wrote %s  %dx%d" % (path, tile.width, tile.height))

# LDtk icon: the RIDE tile (the default pattern), upscaled to a square.
icon = Image.open(os.path.join(OUT, "ride.png")).resize((16, 16), Image.NEAREST)
icon.save(os.path.join(LDTK_ART, "magic_carpet.png"))
print("wrote %s" % os.path.relpath(os.path.join(LDTK_ART, "magic_carpet.png"), ROOT))
