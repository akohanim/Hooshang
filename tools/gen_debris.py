#!/usr/bin/env python3
"""Falling debris for the collapsing escape rooms: dust, paper and masonry.

Three textures, because CPUParticles2D takes ONE texture per emitter and these
things move nothing like each other — dust drifts and hangs, paper tumbles and
flutters, brick DROPS. scenes/props/CollapseAmbience.tscn runs an emitter of each
(and a second one-shot set for the bursts thrown by a big hit).

  debris_dust.png   4x4   — a few soft grey motes, mostly single pixels
  debris_paper.png  6x6   — torn office-paper flecks, off-white with a shaded
                            edge so they read as having a face and a back
  debris_brick.png  8x8   — a chunk knocked out of the wall: an angular lump
                            with a lit top-left face and a dark underside

Both are drawn ONE cell each rather than as a sheet: particles pick a random
rotation and scale at spawn, so the variety comes from the emitter, not from
frames. Anything more detailed disappears anyway — these are 3-6px on a 320x180
screen, behind a room that is mostly dark.

Palette is Act I's: desaturated, cold, dim (CLAUDE.md art direction). The paper
is deliberately NOT white — a pure #FFF fleck against this office reads as a
sparkle, not as rubbish coming off a ceiling.

The BRICK is the exception and is sampled straight off the wall it comes out of
(assets/background/brick_wall_fill.png: face #B03F36, mortar #360A25). A chunk in
any other red reads as a falling object that happens to be near a brick wall,
rather than as a piece OF it — which is the whole illusion.

Re-run after editing: python3 tools/gen_debris.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props")

# Alpha, not colour, carries most of these: the room's CanvasModulate is ~0.09,
# so a mote's brightness on screen is set by the light it happens to fall
# through far more than by the value baked in here.
DUST = [
    # (x, y, r, g, b, a)
    (1, 0, 168, 166, 176, 200),
    (2, 1, 148, 146, 158, 235),
    (1, 2, 132, 130, 142, 180),
    (3, 2, 120, 118, 130, 120),
    (0, 3, 140, 138, 150, 150),
]

# A torn scrap, lit from the upper left like everything else in this project
# (see tools/gen_glass_spikes.py — the light does not rotate with the sprite).
PAPER = [
    (1, 0, 214, 210, 198, 255),
    (2, 0, 224, 220, 208, 255),
    (3, 0, 206, 202, 190, 255),
    (0, 1, 198, 194, 182, 255),
    (1, 1, 232, 228, 216, 255),
    (2, 1, 222, 218, 206, 255),
    (3, 1, 190, 186, 174, 255),
    (4, 1, 176, 172, 162, 255),
    (1, 2, 210, 206, 194, 255),
    (2, 2, 196, 192, 180, 255),
    (3, 2, 172, 168, 158, 255),
    (2, 3, 164, 160, 150, 255),
    (3, 3, 150, 146, 138, 255),
]

# A chunk of the wall, 8x8 and deliberately NOT symmetric: it has a wide lit top
# face, a body in the wall's own red, and a dark underside. Lit from the upper
# left like everything else in this project.
#
# Bigger than the other two on purpose. Dust and paper are meant to be felt more
# than seen; a brick is meant to be SEEN, because it is the piece of this that
# says the building is coming apart rather than merely dusty.
BRICK_FACE = (176, 63, 54)
BRICK_LIT = (206, 96, 78)
BRICK_MID = (150, 52, 48)
BRICK_DARK = (96, 28, 40)
BRICK_MORTAR = (54, 10, 37)

BRICK = [
    # top face, catching the light
    (2, 1, *BRICK_LIT, 255), (3, 1, *BRICK_LIT, 255), (4, 1, *BRICK_LIT, 255),
    (1, 2, *BRICK_LIT, 255), (2, 2, *BRICK_FACE, 255), (3, 2, *BRICK_FACE, 255),
    (4, 2, *BRICK_FACE, 255), (5, 2, *BRICK_MID, 255),
    # body
    (1, 3, *BRICK_FACE, 255), (2, 3, *BRICK_FACE, 255), (3, 3, *BRICK_FACE, 255),
    (4, 3, *BRICK_MID, 255), (5, 3, *BRICK_MID, 255), (6, 3, *BRICK_DARK, 255),
    (1, 4, *BRICK_MID, 255), (2, 4, *BRICK_FACE, 255), (3, 4, *BRICK_MID, 255),
    (4, 4, *BRICK_MID, 255), (5, 4, *BRICK_DARK, 255), (6, 4, *BRICK_DARK, 255),
    # a bite of mortar still stuck to one edge — the tell that it was PART of
    # something a moment ago
    (2, 5, *BRICK_MID, 255), (3, 5, *BRICK_DARK, 255), (4, 5, *BRICK_MORTAR, 255),
    (5, 5, *BRICK_MORTAR, 255),
    (3, 6, *BRICK_MORTAR, 255), (4, 6, *BRICK_DARK, 255),
]


def draw(pixels, size, path):
    a = np.zeros((size, size, 4), dtype=np.uint8)
    for x, y, r, g, b, alpha in pixels:
        a[y, x] = (r, g, b, alpha)
    Image.fromarray(a, "RGBA").save(path)
    print("wrote %s (%dx%d)" % (os.path.relpath(path, ROOT), size, size))


os.makedirs(OUT, exist_ok=True)
draw(DUST, 4, os.path.join(OUT, "debris_dust.png"))
draw(PAPER, 6, os.path.join(OUT, "debris_paper.png"))
draw(BRICK, 8, os.path.join(OUT, "debris_brick.png"))
