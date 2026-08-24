#!/usr/bin/env python3
"""Paintable dark-thought hazard tiles for the ThoughtHazards IntGrid layer.

FOUR tiles on a 32×8 sheet, the same count and layout as the brick tileset:

    0  fill        2  left edge
    1  top edge    3  top-left corner

Auto-rules with flipX/flipY give all eight edge and corner variants from these
four. The order on the sheet IS the tile id the rules reference.

The body is the same dark purple-black as the DarkThought entity sprite
(sampled from ldtk/art/dark_thought.png). The exposed-edge rim is the same
hot red. **The edges are BUBBLY** — cloud-like organic contours with two lobes
rather than straight lines — so a painted cluster reads as an amorphous dark
mass, not a grid of boxes.

Each contour profile starts and ends at the same offset (the SEAM value), so
adjacent tiles of the same type connect seamlessly. The corner tile uses BOTH
contour profiles (AND), producing a smooth concave corner. The fill tile is
fully opaque interior.

Re-run after editing: python3 tools/gen_thought_tiles.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ldtk", "art")
CELL = 8

# Sampled from ldtk/art/dark_thought.png — the body ramp.
BODY_DARK = (12, 8, 15)
BODY_MID = (22, 14, 22)
BODY_LIGHT = (35, 20, 32)

# The hot red rim, sampled from the same sheet.
RIM_HOT = (215, 53, 38)
RIM_MID = (150, 30, 24)

# ---------------------------------------------------------------------------
# Contour profiles — how many pixels from the exposed edge the body starts.
# Column 0 and column 7 MUST match (the seam), so adjacent tiles tile cleanly.
# Lower values = body extends further toward the edge (bump peaks at 0).
# ---------------------------------------------------------------------------

# Top edge: gentle undulation — two bumps, shallow valley between them.
# Max recession is 2px, bumps extend 1px past baseline. The bubbly quality
# comes from the irregularity, not the depth.
CONTOUR_TOP = [1, 0, 0, 1, 2, 0, 0, 1]

# Left edge: same gentle treatment.
CONTOUR_LEFT = [1, 0, 0, 1, 1, 0, 0, 1]


def _hash(x: int, y: int) -> float:
    """Repeatable 0-1 noise keyed to tile-local coordinates."""
    h = ((x * 7 + y * 13 + x * y * 3) * 2654435761) & 0xFFFF
    return (h % 100) / 99.0


def _lerp(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(int(a[i] + (b[i] - a[i]) * max(0.0, min(1.0, t)))
                 for i in range(3))


def _body_color(x: int, y: int) -> tuple:
    """Smoky interior color with subtle noise."""
    t = _hash(x, y)
    if t < 0.4:
        c = _lerp(BODY_DARK, BODY_MID, t / 0.4)
    else:
        c = _lerp(BODY_MID, BODY_LIGHT, (t - 0.4) / 0.6)
    return c + (255,)


# ---------------------------------------------------------------------------
# Body masks — whether pixel (x, y) is body for each tile type.
# Out-of-bounds queries model what the NEIGHBOR tile would have at that spot.
# ---------------------------------------------------------------------------

def _body_top(x: int, y: int) -> bool:
    if 0 <= x < CELL and 0 <= y < CELL:
        return y >= CONTOUR_TOP[x]
    if y < 0:
        return False  # exposed edge above
    return True  # body on other three sides


def _body_left(x: int, y: int) -> bool:
    if 0 <= x < CELL and 0 <= y < CELL:
        return x >= CONTOUR_LEFT[y]
    if x < 0:
        return False  # exposed edge to the left
    return True


def _body_corner(x: int, y: int) -> bool:
    if 0 <= x < CELL and 0 <= y < CELL:
        return y >= CONTOUR_TOP[x] and x >= CONTOUR_LEFT[y]
    if y < 0 or x < 0:
        return False  # exposed edges above and left
    return True


def _body_fill(x: int, y: int) -> bool:
    return True  # fully surrounded


TILE_TYPES = {
    "fill": _body_fill,
    "top": _body_top,
    "left": _body_left,
    "corner": _body_corner,
}


def _rim_distance(body_fn, x: int, y: int) -> int:
    """Distance from the nearest transparent pixel. -1 if not body."""
    if not body_fn(x, y):
        return -1
    # Check immediate neighbors (4-connected only for a crisper 1px outline)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        if not body_fn(x + dx, y + dy):
            return 0
    return 1  # interior


def draw_tile(name: str) -> Image.Image:
    """Render one 8×8 tile with organic contours and red rim."""
    body_fn = TILE_TYPES[name]
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()

    for y in range(CELL):
        for x in range(CELL):
            d = _rim_distance(body_fn, x, y)
            if d < 0:
                continue  # transparent
            if d == 0:
                px[x, y] = RIM_HOT + (255,)
            else:
                px[x, y] = _body_color(x, y)
    return img


# Sheet order: fill, top, left, corner — matches the auto-rule tile IDs.
TILES = ["fill", "top", "left", "corner"]

sheet = Image.new("RGBA", (CELL * len(TILES), CELL), (0, 0, 0, 0))
for i, name in enumerate(TILES):
    sheet.paste(draw_tile(name), (i * CELL, 0))

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, "thought_tiles.png")
sheet.save(path)
print("wrote %s  %dx%d  (%s)" % (path, sheet.width, sheet.height, ", ".join(TILES)))
