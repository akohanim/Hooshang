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
window came back as a nearly black bar with no readable shape.

The stamping itself then took two goes. Opaque near-black rectangles with the
top lip left straight read as boxes stuck under an undamaged panel; what makes
it look broken is that the damage is TRANSPARENT (a hole in a ceiling is the
room behind it) and that it comes out of the SILHOUETTE. Cracks are few and
near-vertical for the same reason — a scatter of 45-degree dashes fights the
panel's own shallow seams and reads as dirt.

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
CRACK = tuple(int(v) for v in rot_px[(rot_lum > 55) & (rot_lum < 95)].mean(axis=0))
print("sampled crack colour from the deteriorated render: %s" % (CRACK,))

base = edge(cut(solid, plain_x, TILE_W, TILE_H)).convert("RGBA")

# DAMAGE IS TRANSPARENT, not painted. The first version stamped near-black
# rectangles and they read as boxes stuck under the panel rather than as missing
# material — a hole in a ceiling is the dark room behind it, which is what alpha
# gives for free over whatever the platform happens to be in front of.
#
# And it comes out of the SILHOUETTE. Damage that leaves the top lip perfectly
# straight does not look broken however much texture is scribbled on it, so
# every stage past the first bites the outline, top and bottom.
#
# GAPS are (x, width) slits taken out of the full height — the panel coming
# apart into pieces. BITES are (x, y, w, h) rectangles out of an edge. CRACKS
# are single darkened pixels, kept few and near-vertical: the first version
# scattered 45-degree dashes that fought the panel's own shallow seams and read
# as dirt.
# ONE break that opens up, and almost nothing else. Everything busier than this
# was tried and read worse at 24x8: scattered dashes look like dirt, and a dark
# rim either side of a gap turns the gap into a thick bar, so the panel ends up
# looking barred rather than broken.
#
# GAPS are (x, width) slits through the full height — the panel coming apart.
# BITES are (x, y, w, h) out of an edge, which is what actually sells damage:
# a straight top lip reads as undamaged however much texture is scribbled on it.
# CRACKS are single darkened pixels.
STAGES = [
    {"gaps": [], "bites": [],
     "cracks": [(11, 1), (11, 2), (12, 3)]},
    {"gaps": [(11, 1)],
     "bites": [(4, 7, 3, 1), (18, 7, 2, 1)],
     "cracks": [(5, 2), (5, 3), (18, 2), (18, 3)]},
    {"gaps": [(11, 2)],
     "bites": [(2, 7, 4, 1), (16, 7, 5, 1), (9, 0, 2, 1), (13, 0, 2, 1),
               (0, 6, 2, 2)],
     "cracks": [(4, 2), (4, 3), (5, 4), (17, 2), (17, 3), (18, 4)]},
]
## Each stage loses a little light, so a panel about to go is visibly duller
## than one that is merely cracked even where it is still whole.
DIM = [0.97, 0.91, 0.84]

for i, stage in enumerate(STAGES):
    a = np.array(base).astype(int)
    a[..., :3] = np.clip(a[..., :3] * DIM[i], 0, 255)
    for (cx, cy) in stage["cracks"]:
        if 0 <= cy < TILE_H and 0 <= cx < TILE_W:
            a[cy, cx, :3] = CRACK
    for (gx, gw) in stage["gaps"]:
        a[:, gx:gx + gw, 3] = 0
    for (bx, by, bw, bh) in stage["bites"]:
        a[by:by + bh, bx:bx + bw, 3] = 0
    Image.fromarray(a.astype(np.uint8), "RGBA").save(
        os.path.join(OUT, "crumble_%d.png" % i))
    print("crumble %d  %d gaps, %d bites, %d cracks"
          % (i, len(stage["gaps"]), len(stage["bites"]), len(stage["cracks"])))

# ---- LDtk icons -----------------------------------------------------------
# Square, so the entity reads as a thing rather than as a sliver in the editor.
edge(cut(solid, plain_x, ICON, ICON // 2)).resize((ICON, ICON), Image.NEAREST) \
    .save(os.path.join(LDTK_ART, "platform.png"))
Image.open(os.path.join(OUT, "crumble_1.png")).resize((ICON, ICON), Image.NEAREST) \
    .save(os.path.join(LDTK_ART, "platform_crumbling.png"))
print("wrote %s and the two LDtk icons" % os.path.relpath(OUT, ROOT))
