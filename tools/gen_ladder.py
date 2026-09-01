#!/usr/bin/env python3
"""The climbable Ladder prop's rung art: one repeating 8x8 tile, two dark
rails with a cream-over-gold rung centred in the MIDDLE of every cell.

ONE TILE, not five capped/middle variants like the spike strips or the slide
floor. A ladder of any height is just this tile stacked — there is no "end"
to cap: the collider stops wherever the LDtk height field says regardless of
where the art happens to land, and a rail that keeps going past the last
drawn rung reads fine (real ladders do exactly that against a wall).

The rung sits in rows 3-4 of the 8-row cell, not flush against row 0 like the
tile used to draw it. That is what makes a ladder of ANY height open at both
ends without a second "cap" tile: every stacked copy, first and last alike,
starts and ends on its own open (rail-only) rows 0-2 / 5-7, so the seam
between two tiles is always open too and there is never a rung flush against
the ladder's very top or bottom pixel.

Colour is a light-brown rail with a pale cream / warm-gold rung: a dark rail
(the original take, after a reference ladder sprite) all but vanished against
Act I's dim, desaturated office — see LIGHTING.md — so the wood is lightened
and warmed to stay legible as a climbable prop rather than office clutter,
with the rung kept brighter still so it reads as its own highlighted band
rather than fading into the rail either.

Re-run after editing: python3 tools/gen_ladder.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 8

RAIL = (176, 128, 74, 255)
RUNG_HI = (241, 224, 186, 255)
RUNG = (219, 164, 78, 255)

img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
px = img.load()

for y in range(CELL):
    # Left rail.
    px[1, y] = RAIL
    px[2, y] = RAIL
    # Right rail.
    px[5, y] = RAIL
    px[6, y] = RAIL

# The rung sits in the middle of the cell (rows 3-4), leaving rows 0-2 and
# 5-7 open on every tile — see the module docstring for why that is what
# keeps a ladder of any height from starting or ending on a rung.
for x in range(2, 6):
    px[x, 3] = RUNG_HI
    px[x, 4] = RUNG

for folder in ("assets/props", "ldtk/art"):
    img.save(os.path.join(ROOT, folder, "ladder_rung.png"))
print("wrote ladder_rung  %dx%d" % (CELL, CELL))
