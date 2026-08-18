#!/usr/bin/env python3
"""Office-ceiling platforms: a solid one and a crumbling one, cut from renders.

Sources (assets/props/platform/source/): two 2752x1536 JPEGs of a suspended
office ceiling seen edge-on — one intact, one falling apart. Each is a long
horizontal band: a hanger rail along the top, a run of ceiling tiles skewed into
parallelograms, glowing light panels every few tiles, and a dark underside.

WHAT COMES OUT is a horizontally REPEATING strip, not a whole platform. The
platforms are placed in LDtk at whatever width the room wants, so the art has to
be a unit the prop can lay end to end (scenes/props/platforms/platform.gd builds
the strip a tile at a time, the way conveyor_belt_visual.gd does).

24x8 is the unit: 3 cells by 1 on the 8px grid. The width is not arbitrary — the
source's seam period is 533px against a 378px band, so at 8px tall one period
lands at about 11px, and 24 keeps roughly two diagonals per tile the way the
render has them. At 16 the diagonals crowd and the panel reads as corrugation.

THE TOP AND BOTTOM ROWS ARE FORCED after the downscale. Everything else is the
render, but a platform has to say "stand here" in one pixel of lip and one of
shadow, and a LANCZOS average of a perspective rail does not reliably give
either — some windows came back with a dark top row, which reads as a hole.

The crumbling platform gets THREE frames rather than an animation of the
collapse: the collapse itself is motion (fall, spin, fade) and belongs in the
prop, not in a sheet.

Those three are the SOLID tile with damage stamped onto it, and are the one
thing here not cut from a render. Cutting them was the first attempt and it does
not survive the scale: the deteriorated image's cracks and rubble are fine
detail, and eight pixels of height turns them into speckle — the most damaged
window came back as a nearly black bar with no readable shape. Damage that reads
at this size has to be a few deliberate notches, so the holes and cracks are
stamped, and only their COLOURS are sampled from the deteriorated render. It is
seeded, so a re-run gives the same tile rather than reshuffling every platform
in the game.

Re-run after editing: python3 tools/gen_platforms.py
"""
import os
import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "platform")
SRC = os.path.join(OUT, "source")
LDTK_ART = os.path.join(ROOT, "ldtk", "art")

## The band, in source rows. Above it is empty air, below it is the room.
BAND = (579, 957)
## One seam period of the render.
PERIOD = 533
## The repeating unit, in game pixels: 3 cells by 1 on the 8px grid.
TILE_W, TILE_H = 24, 8
## The LDtk entity icon.
ICON = 16
PALETTE = 14


def band(name):
    im = Image.open(os.path.join(SRC, "platform_%s.jpeg" % name)).convert("RGB")
    return im.crop((0, BAND[0], im.width, BAND[1]))


def cut(strip, x, w, h):
    """One window of the band, down to (w, h) with its edges kept."""
    win = strip.crop((x, 0, x + PERIOD, strip.height))
    small = win.resize((w * 4, h * 4), Image.LANCZOS)
    small = ImageEnhance.Sharpness(small).enhance(2.0)
    small = small.resize((w, h), Image.BOX)
    small = ImageEnhance.Sharpness(small).enhance(1.5)
    return small.convert("RGB").quantize(
        colors=PALETTE, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")


def edge(img):
    """Force the lip and the shadow. See the note at the top."""
    a = np.array(img).astype(int)
    body = a[1:-1]
    lip = np.clip(body.reshape(-1, 3).max(axis=0) + 18, 0, 255)
    shade = np.clip(body.reshape(-1, 3).min(axis=0) - 10, 0, 255)
    a[0] = lip
    a[-1] = shade
    return Image.fromarray(a.astype(np.uint8), "RGB")


def lit_windows(strip):
    """Where the glowing light panels are, as window start x's.

    The panels are the only thing in the band brighter than the tile face, so
    they are found by threshold rather than by the seam grid — the grid is
    skewed and the panels do not sit on every tile.
    """
    g = np.array(strip.convert("L")).astype(float)
    hot = (g > 235).mean(axis=0)
    return hot


def damage(strip):
    g = np.array(strip.convert("L")).astype(float)
    return (g < 70).mean(axis=0)


os.makedirs(OUT, exist_ok=True)
os.makedirs(LDTK_ART, exist_ok=True)

# ---- solid: one plain unit, and one with a light panel in it ---------------
solid = band("solid")
hot = lit_windows(solid)
starts = range(600, solid.width - PERIOD, 8)
plain_x = min(starts, key=lambda x: hot[x:x + PERIOD].mean())
lit_x = max(starts, key=lambda x: hot[x:x + PERIOD].mean())
edge(cut(solid, plain_x, TILE_W, TILE_H)).save(os.path.join(OUT, "solid.png"))
edge(cut(solid, lit_x, TILE_W, TILE_H)).save(os.path.join(OUT, "solid_lit.png"))
print("solid      plain x=%d (hot %.3f)   lit x=%d (hot %.3f)"
      % (plain_x, hot[plain_x:plain_x + PERIOD].mean(),
         lit_x, hot[lit_x:lit_x + PERIOD].mean()))

# ---- crumbling: the solid tile, progressively broken ----------------------
rot = band("deteriorated")
rot_px = np.array(rot).reshape(-1, 3)
rot_lum = rot_px.mean(axis=1)
HOLE = tuple(int(v) for v in rot_px[rot_lum < 40].mean(axis=0))      # through to nothing
CRACK = tuple(int(v) for v in rot_px[(rot_lum > 55) & (rot_lum < 95)].mean(axis=0))
print("sampled from the deteriorated render: hole %s  crack %s" % (HOLE, CRACK))

base = edge(cut(solid, plain_x, TILE_W, TILE_H))

# (x, y, w, h) notches bitten out of the tile, and (x, y) crack pixels. Written
# out rather than randomised: at 24x8 there are 192 pixels and where each one
# goes is the difference between "cracked ceiling" and "dirty smudge".
STAGES = [
    {"holes": [(5, 6, 2, 2)],
     "cracks": [(4, 2), (5, 3), (6, 3), (7, 4), (16, 2), (17, 3), (18, 3)]},
    {"holes": [(5, 5, 3, 3), (16, 6, 3, 2)],
     "cracks": [(3, 1), (4, 2), (5, 3), (6, 3), (7, 4), (8, 5),
                (14, 1), (15, 2), (16, 3), (17, 3), (18, 4), (11, 2), (12, 3)]},
    {"holes": [(4, 4, 5, 4), (14, 5, 6, 3), (0, 6, 2, 2)],
     "cracks": [(2, 1), (3, 2), (4, 3), (9, 1), (10, 2), (11, 3), (12, 4),
                (13, 1), (20, 2), (21, 3), (22, 4), (22, 1)]},
]
for i, stage in enumerate(STAGES):
    a = np.array(base).astype(int)
    for (hx, hy, hw, hh) in stage["holes"]:
        a[hy:hy + hh, hx:hx + hw] = HOLE
    for (cx, cy) in stage["cracks"]:
        if 0 <= cy < TILE_H and 0 <= cx < TILE_W:
            a[cy, cx] = CRACK
    Image.fromarray(a.astype(np.uint8)).save(os.path.join(OUT, "crumble_%d.png" % i))
    print("crumble %d  %d holes, %d cracks"
          % (i, len(stage["holes"]), len(stage["cracks"])))
picks = [0, 0, 0]

# ---- LDtk icons -----------------------------------------------------------
# Square, so the entity reads as a thing rather than as a sliver in the editor.
edge(cut(solid, plain_x, ICON, ICON // 2)).resize((ICON, ICON), Image.NEAREST) \
    .save(os.path.join(LDTK_ART, "platform.png"))
Image.open(os.path.join(OUT, "crumble_1.png")).resize((ICON, ICON), Image.NEAREST) \
    .save(os.path.join(LDTK_ART, "platform_crumbling.png"))
print("wrote %s and the two LDtk icons" % os.path.relpath(OUT, ROOT))
