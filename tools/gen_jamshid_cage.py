#!/usr/bin/env python3
"""Jamshid's cage: a locked lattice, and the same frame with the door swung
open. Fixed 16x24 (two cells wide, three tall) — see jamshid_cage.gd's SIZE.

Procedural, same flat-shaded-geometry technique as tools/gen_cone_spikes.py —
no character art here, just a barred door; Jamshid himself is a later task.

CLOSED: a frame of warm sandstone posts (matching the Act 2 tileset) with
vertical iron bars set into it, evenly spaced.
OPEN: the same frame, its bars swung aside on the left post — a gap wide
enough to read as "you can walk through this now" at a glance, without the
bars vanishing outright (a cage that simply disappears reads as a bug, not an
unlocking).

WATERCOLOR PASS (2026-09). PALETTE ONLY — THE POST/BAR GEOMETRY IS UNCHANGED.
Same reasoning as every other small prop in this batch: the closed/open read
(bars swept aside vs. evenly spaced) has to survive at 16x24, so the frame()/
bars() layout stays hand-drawn (experiments/act2_watercolor/README.md, and
gen_act2_cone_spikes.py's precedent for exactly this call).

POST_* is NOT its own Pixellab generation — it reuses the wall tileset's own
ramp (ldtk/art/source/act2_wall.png, the same source gen_act2_tileset_8px.py
reads) so the cage posts are literally the same sandstone the walls are built
from, per this file's own original header ("Sandstone posts (matching the Act
2 tileset)"). BAR_* has no dedicated "iron bars" generation either; it is
hand-tuned as a cool blue-grey that reads as metal against that warm
sandstone, nudged toward the wall tileset's own GLAZE_DARK hue for the same
"the accent colours in a room agree with each other" reason the tileset's own
GLAZE ramp exists — the pre-watercolor version was already colour-neutral
iron with no such tie to anything else in the room.

Re-run after editing: python3 tools/gen_jamshid_cage.py
"""
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "jamshid_cage")
LDTK_ART = os.path.join(ROOT, "ldtk", "art")

W, H = 16, 24


def _ramp_from_source(path, n=12):
    """Top-N most common opaque colours in a Pixellab source, sorted
    brightest to darkest. Same technique as the sibling generators; kept as
    its own copy per this project's self-contained-script convention."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


_WALL_RAMP = _ramp_from_source(
    os.path.join(ROOT, "ldtk", "art", "source", "act2_wall.png"))

POST_HI = _WALL_RAMP[0] + (255,)
POST = _WALL_RAMP[1] + (255,)
POST_DARK = _WALL_RAMP[4] + (255,)
# Cool blue-grey iron, hand-tuned to lean toward the wall tileset's own
# GLAZE_DARK hue rather than a neutral grey — see header.
BAR_HI = (150, 165, 172, 255)
BAR = (95, 108, 116, 255)
BAR_DARK = (48, 56, 64, 255)


def put(px, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c


def frame(img):
    """The two posts and the top lintel, common to both frames."""
    px = img.load()
    for y in range(H):
        for x in (0, 1, W - 2, W - 1):
            shade = POST_HI if x in (0, W - 2) else POST_DARK
            put(px, x, y, shade if y < H - 1 else POST_DARK)
    for x in range(W):
        put(px, x, 0, POST_HI)
        put(px, x, 1, POST)


def bars(img, xs):
    """Vertical iron bars at the given x columns, floor to lintel."""
    px = img.load()
    for x in xs:
        for y in range(2, H - 1):
            put(px, x, y, BAR_HI if y == 2 else (BAR_DARK if y == H - 2 else BAR))


closed = Image.new("RGBA", (W, H), (0, 0, 0, 0))
frame(closed)
bars(closed, [4, 7, 10])

opened = Image.new("RGBA", (W, H), (0, 0, 0, 0))
frame(opened)
# Bars swung aside against the left post — still visible (it is a hinged
# door, not a vanished obstacle), but nothing blocks the gap any more.
bars(opened, [2, 3])

os.makedirs(OUT, exist_ok=True)
os.makedirs(LDTK_ART, exist_ok=True)
closed.save(os.path.join(OUT, "closed.png"))
opened.save(os.path.join(OUT, "open.png"))
# LDtk editor icon — the closed frame, same file the game itself uses at rest.
closed.save(os.path.join(LDTK_ART, "jamshid_cage_closed.png"))
print("wrote %s and open.png  %dx%d" % (os.path.join(OUT, "closed.png"), W, H))
print("wrote %s" % os.path.join(LDTK_ART, "jamshid_cage_closed.png"))
