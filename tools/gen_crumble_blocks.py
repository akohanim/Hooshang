#!/usr/bin/env python3
"""Crumbling platform art: loose, cracked chunks that read as "this gives way"
next to every Act's scaffolding. One shared geometry, one palette per Act.

WHY THIS REPLACED THE BEVELLED STONES. The old blocks were a cool blue-grey
8px box with a lit top/left rim and a dark bottom/right one, which is the
scaffolding's own vocabulary almost pixel for pixel: `gen_scaffolding.py`'s
boxed couplers are that same lit box in that same steel ramp, and Act 1's
rooms (Level_2, Level_V7) run crumbling panels and scaffold bays end to end in
one row. In play the two read as one material, so nothing said which half of
a ledge was about to go. The prison has it too — it re-uses the Act 1 steel
scaffold — and in the gardens the grey read as inert stone.

What separates them now, in order of how far away it still reads:
  1. SILHOUETTE. Scaffolding is a rigid, straight-edged run. Each crumble chunk
     has a broken underside (`bottom`: the lowest painted row of every column,
     ragged and different per chunk) rimmed in the darkest stop, and a notch
     in the lip where one chunk meets the next, so a run is a row of loose
     lumps rather than one beam.
  2. MATERIAL. Warm, mottled, cracked masonry against cool steel / turquoise
     tube, with a dark crack already started in every chunk at rest.
  3. PALETTE. Each Act's ramp sits away from that Act's scaffold (below).

The three damage frames keep the contract `crumbling_platform.gd` already
drives: 24x8, three 8px chunks the script tiles by `i % 3`, frame 0 at rest.
Each frame stamps on top of the one before — the crack reaches the lip (1),
then splits the chunk top to bottom with its far side catching light, the lip
breaks at the crack and more of the underside goes (2) — so they can only ever
read as the same panel getting worse.

PALETTES, one per Act, same roles:
  - OFFICE (Act 1, `crumble_N.png`): dusty plaster/aggregate, hand-picked like
    `gen_scaffolding.py`'s steel. Warm and mid-toned against that light cool
    steel, and duller and yellower than the orange office brick.
  - CHILDHOOD (Act 2, `crumble_act2_N.png`): sun-baked mud-brick with straw
    flecks, the pulled-back watercolor pipeline (CLAUDE.md, Act 2 convention):
    the RAMP comes from a Pixellab swatch via `_ramp_from_source`, the shapes
    stay procedural. A fresh swatch could not be generated for this pass (the
    Pixellab subscription had lapsed), so it reads `ldtk/art/source/
    act2_wall.png`, the Act 2 masonry swatch `gen_act2_cone_spikes.py` already
    reuses for its stone bed, and picks the adobe stops by HUE rather than rank
    (`gen_act2_tileset_8px.py`'s `_TEAL` pattern): clay browns for the body,
    pale sand for the sunlit lip and straw. Rose-umber clay sits opposite the
    turquoise/brass scaffold and darker than the peach prison masonry and the
    ochre garden turf.
  - PSYCHEDELIC (Act 3, `crumble_act3_N.png`): Act 3 is strictly black and
    white (`build_act3_psychedelic.py`), and its terrain and scaffold are white
    LINES on black. A crumble is the one SOLID white mass, broken by black
    cracks, with black seams between chunks.

Re-run after editing: python3 tools/gen_crumble_blocks.py
(`gen_platforms.py` also calls run() last, so it cannot overwrite these.)
"""
import colorsys
from collections import Counter
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/props/platform"
CELL = 8

# Roles, painted per pixel and coloured per Act:
#   g glint (the lip)  l light  b body  c mottle  f fleck
#   s shade  e seam between chunks  d underside rim / crack  . clear
#
# Per chunk:
#   bottom  lowest painted row of each column: the broken underside
#   mottle  body pixels one stop darker, so the face is not a flat fill
#   flecks  aggregate / straw catching light
#   cracks  frame 0's hairline, then what frame 1 adds to it
#   split   frame 2: the crack runs on to the underside
#   lit     frame 2: the far side of the split catches the light; on the lip
#           row that pixel is knocked out instead, a bite out of the top
#   bites   rows of underside lost by frames 1 and 2, as (column, rows)
CHUNKS = [
    dict(bottom=(6, 7, 7, 6, 5, 6, 7, 6),
         mottle=((2, 3), (5, 4), (3, 5)), flecks=((1, 3), (6, 2)),
         cracks=(((4, 1), (4, 2), (3, 3)),
                 ((4, 0), (3, 4), (2, 4), (5, 2), (6, 3))),
         split=((3, 5), (4, 5), (4, 4)),
         lit=((5, 1), (5, 0)),
         bites=(((1, 1),), ((4, 1), (0, 1), (6, 1)))),
    dict(bottom=(7, 6, 6, 7, 7, 6, 5, 6),
         mottle=((1, 4), (4, 3), (5, 5)), flecks=((3, 2), (2, 5)),
         cracks=(((2, 1), (3, 2), (3, 3)),
                 ((2, 0), (2, 4), (1, 5), (4, 3), (5, 4))),
         split=((2, 5), (2, 6), (3, 6)),
         lit=((3, 1), (3, 0)),
         bites=(((5, 1),), ((3, 1), (7, 1), (0, 1)))),
    dict(bottom=(6, 7, 6, 6, 7, 7, 6, 6),
         mottle=((2, 2), (4, 4), (1, 5)), flecks=((5, 3), (2, 4)),
         cracks=(((5, 1), (5, 2), (6, 3)),
                 ((5, 0), (6, 4), (4, 3), (3, 4))),
         split=((6, 5), (5, 5), (5, 6)),
         lit=((6, 1), (6, 0)),
         bites=(((2, 1),), ((5, 1), (1, 1), (7, 1)))),
]


def _ramp_from_source(path, n=40):
    """Top-N most common opaque colours in a Pixellab source, sorted
    brightest to darkest. Same technique as the sibling generators; kept as
    its own copy per this project's self-contained-script convention."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


def _hsv(c):
    return colorsys.rgb_to_hsv(*(x / 255 for x in c))


def _hex(c):
    return "#%02x%02x%02x" % c


_WALL_RAMP = _ramp_from_source(ROOT / "ldtk/art/source/act2_wall.png")
# Clay: the red-brown stops, neither the sand lights nor the near-black
# mortar. Sand: the pale warm stops that read as sun on a dry top edge.
_CLAY = [c for c in _WALL_RAMP
         if (_hsv(c)[0] < 0.08 or _hsv(c)[0] > 0.94)
         and 0.25 <= _hsv(c)[1] <= 0.65 and 0.2 < _hsv(c)[2] < 0.7]
_SAND = [c for c in _WALL_RAMP
         if 0.05 <= _hsv(c)[0] <= 0.11 and _hsv(c)[1] < 0.55
         and _hsv(c)[2] > 0.84]
assert len(_CLAY) >= 5 and len(_SAND) >= 2, (_CLAY, _SAND)

PALETTES = {
    "crumble_{}": dict(
        g="#e6dabb", l="#c6b28c", b="#a38e69", c="#927c5a", f="#d2c096",
        s="#6d5c44", e="#6d5c44", d="#3a3029"),
    "crumble_act2_{}": dict(
        g=_hex(_SAND[0]), l=_hex(_SAND[-1]), b=_hex(_CLAY[0]),
        c=_hex(_CLAY[2]), f=_hex(_SAND[1]), s=_hex(_CLAY[4]),
        e=_hex(_CLAY[4]), d=_hex(_CLAY[-1])),
    "crumble_act3_{}": dict(
        g="#ffffff", l="#ffffff", b="#ffffff", c="#ffffff", f="#ffffff",
        s="#ffffff", e="#000000", d="#000000"),
}


def roles(chunk, frame):
    """One 8x8 chunk at one damage frame, as rows of role letters."""
    bottom = list(chunk["bottom"])
    for stage in chunk["bites"][:frame]:
        for x, rows in stage:
            bottom[x] -= rows
    grid = [["."] * CELL for _ in range(CELL)]
    for x in range(CELL):
        # The seam column starts a row down: the notch in the lip between two
        # chunks is what makes a run read as separate lumps.
        for y in range(1 if x == CELL - 1 else 0, bottom[x] + 1):
            if y == bottom[x]:
                role = "d"
            elif x == CELL - 1:
                role = "e"
            elif y == bottom[x] - 1:
                role = "s"
            elif y == 0:
                role = "g"
            elif y == 1 or x == 0:
                role = "l"
            else:
                role = "b"
            grid[y][x] = role
    for x, y in chunk["mottle"]:
        if grid[y][x] == "b":
            grid[y][x] = "c"
    for x, y in chunk["flecks"]:
        if grid[y][x] in "bc":
            grid[y][x] = "f"
    for path in chunk["cracks"][:frame + 1]:
        for x, y in path:
            if grid[y][x] != ".":
                grid[y][x] = "d"
    if frame >= 2:
        for x, y in chunk["split"]:
            if grid[y][x] != ".":
                grid[y][x] = "d"
        for x, y in chunk["lit"]:
            if grid[y][x] != ".":
                grid[y][x] = "l" if y else "."
    return grid


def strip(palette, frame):
    rgb = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5))
           for k, v in palette.items()}
    im = Image.new("RGBA", (CELL * len(CHUNKS), CELL))
    for i, chunk in enumerate(CHUNKS):
        for y, row in enumerate(roles(chunk, frame)):
            for x, role in enumerate(row):
                if role != ".":
                    im.putpixel((i * CELL + x, y), rgb[role] + (255,))
    return im


def run():
    for name, palette in PALETTES.items():
        for frame in range(3):
            strip(palette, frame).save(OUT / (name.format(frame) + ".png"))
    # The LDtk icon is shared by all three projects; it shows the office look.
    icon = Image.new("RGBA", (16, 16))
    icon.paste(strip(PALETTES["crumble_{}"], 0).crop((0, 0, 16, 8)), (0, 4))
    icon.save(ROOT / "ldtk/art/platform_crumbling.png")
    print("crumble sheets: %s" % ", ".join(
        name.format("0-2") for name in PALETTES))


if __name__ == "__main__":
    run()
