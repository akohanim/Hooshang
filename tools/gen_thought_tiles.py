#!/usr/bin/env python3
"""Animated paintable dark-thought hazard tiles for the ThoughtHazards layer.

SIX frames × four tile types (fill, top edge, left edge, corner) on a 32×48
sheet.  The contour SHAPES are fixed — the body outline does not morph.  What
animates is:

  1. **Rim flow** — a travelling brightness wave along the red edge, so the
     outline appears to ripple without changing shape.
  2. **Ghostly faces** — two dot eyes and a small oval mouth that fade in on
     the FILL tile for two frames then fade back out, giving the sludge mass
     a haunted, living quality.

Based on a PixelLab-generated dark sludge animation (PixelLab jobs c5410b67,
9c39797a, 87060ee6).  Palette derived from the PixelLab frames: body
(8,4,10)–(50,30,50), rim (215,70,80).

Re-run after editing: python3 tools/gen_thought_tiles.py
"""
import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ldtk", "art")
CELL = 8
FRAMES = 6

# ---------------------------------------------------------------------------
# Palette — derived from PixelLab analysis
# ---------------------------------------------------------------------------
BODY_DARK  = (8, 4, 10)
BODY_MID   = (30, 18, 33)
BODY_LIGHT = (50, 30, 50)

RIM_HOT = (215, 70, 80)
RIM_DIM = (120, 35, 45)

# Face — dim red glow, visible against the dark body
FACE_COLOR = (150, 50, 55)
FACE_EYES  = {(2, 2), (5, 2)}
FACE_MOUTH = {(3, 5), (4, 5)}
FACE_PIXELS = FACE_EYES | FACE_MOUTH
# Per-frame face visibility: 0 = hidden, 1 = fully visible
FACE_VIS = [0.0, 0.0, 0.4, 1.0, 0.6, 0.0]

# ---------------------------------------------------------------------------
# Contour profiles (STATIC — the same in every frame)
# ---------------------------------------------------------------------------
CONTOUR_TOP  = [1, 0, 0, 1, 2, 0, 0, 1]
CONTOUR_LEFT = [1, 0, 0, 1, 1, 0, 0, 1]


def _hash(x: int, y: int) -> float:
    h = ((x * 7 + y * 13 + x * y * 3) * 2654435761) & 0xFFFF
    return (h % 100) / 99.0


def _lerp(a: tuple, b: tuple, t: float) -> tuple:
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def _body_color(x: int, y: int) -> tuple:
    t = _hash(x, y)
    if t < 0.4:
        c = _lerp(BODY_DARK, BODY_MID, t / 0.4)
    else:
        c = _lerp(BODY_MID, BODY_LIGHT, (t - 0.4) / 0.6)
    return c + (255,)


# ---------------------------------------------------------------------------
# Body masks (same every frame — contours are static)
# ---------------------------------------------------------------------------
def _body_top(x, y):
    if 0 <= x < CELL and 0 <= y < CELL:
        return y >= CONTOUR_TOP[x]
    return y >= 0

def _body_left(x, y):
    if 0 <= x < CELL and 0 <= y < CELL:
        return x >= CONTOUR_LEFT[y]
    return x >= 0

def _body_corner(x, y):
    if 0 <= x < CELL and 0 <= y < CELL:
        return y >= CONTOUR_TOP[x] and x >= CONTOUR_LEFT[y]
    if y < 0 or x < 0:
        return False
    return True

def _body_fill(x, y):
    return True

BODY_FNS = {
    "fill":   _body_fill,
    "top":    _body_top,
    "left":   _body_left,
    "corner": _body_corner,
}


def _is_rim(body_fn, x, y):
    if not body_fn(x, y):
        return False
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        if not body_fn(x + dx, y + dy):
            return True
    return False


# ---------------------------------------------------------------------------
# Rim flow — a sine-wave brightness travelling diagonally across the rim
# ---------------------------------------------------------------------------
def _rim_color(x: int, y: int, frame: int) -> tuple:
    phase = (x * 0.9 + y * 0.6) + frame * (math.tau / FRAMES)
    t = (math.sin(phase) + 1.0) / 2.0
    return _lerp(RIM_DIM, RIM_HOT, t) + (255,)


# ---------------------------------------------------------------------------
# Tile rendering
# ---------------------------------------------------------------------------
TILE_TYPES = ["fill", "top", "left", "corner"]


def draw_tile(tile_type: str, frame: int) -> Image.Image:
    body_fn = BODY_FNS[tile_type]
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()

    for y in range(CELL):
        for x in range(CELL):
            if not body_fn(x, y):
                continue

            if _is_rim(body_fn, x, y):
                px[x, y] = _rim_color(x, y, frame)
                continue

            # Ghostly face on fill tiles only
            if tile_type == "fill" and (x, y) in FACE_PIXELS:
                vis = FACE_VIS[frame]
                if vis > 0:
                    base = _body_color(x, y)[:3]
                    px[x, y] = _lerp(base, FACE_COLOR, vis) + (255,)
                    continue

            px[x, y] = _body_color(x, y)

    return img


# ---------------------------------------------------------------------------
# Build the sheet: 4 columns × 6 rows = 32×48 px
# ---------------------------------------------------------------------------
sheet = Image.new("RGBA", (CELL * len(TILE_TYPES), CELL * FRAMES), (0, 0, 0, 0))
for frame in range(FRAMES):
    for col, tile_type in enumerate(TILE_TYPES):
        tile = draw_tile(tile_type, frame)
        sheet.paste(tile, (col * CELL, frame * CELL))

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, "thought_tiles.png")
sheet.save(path)
print("wrote %s  %dx%d  (%d frames × %d tiles)"
      % (path, sheet.width, sheet.height, FRAMES, len(TILE_TYPES)))
