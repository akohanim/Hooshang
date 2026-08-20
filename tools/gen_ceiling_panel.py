#!/usr/bin/env python3
"""The suspended office ceiling: grid tiles, and the light panels set INTO them.

The reference is a plain modern office ceiling seen from below — white acoustic
tiles in a T-bar grid, with flat luminous panels flush in the grid where a tile
would otherwise be. Not a fixture hanging on rods: a panel that IS one of the
ceiling tiles.

Three files, 24x8 each — the same unit `tools/gen_platforms.py` cuts its ceiling
strip at, deliberately, because in this Act the ceiling and the thing he ends up
standing on are the same ceiling. Laying them end to end gives a continuous run.

  ceiling_tile.png        a plain tile, with the T-bar rail on its left edge, so
                          consecutive tiles butt into a grid
  ceiling_light.png       the same cell with a light panel in it instead of a
                          tile: thin frame, flat field, corner vignette
  ceiling_light_glow.png  ONLY what emits, on transparent, with the bloom that
                          spills past the frame onto the neighbouring tiles

THE GLOW IS A SEPARATE FILE BECAUSE IT BECOMES A LIGHT, not paint. CanvasModulate
is 0.05 in Act I and multiplies every CanvasItem, so a painted luminous panel
arrives at 5% of what was drawn — the trap SunShaft and WallPattern document.
The prop wears this file as a PointLight2D texture: the panel's shape is art, its
brightness is light, and nothing multiplies it away.

Drawn DIM. Everything here is a surface in a dark office, seen by the light of
the panels next to it; a tile drawn at office-daylight white comes out as a
bright bar in a room that is meant to be nearly black, and there is nothing left
to raise when a light does hit it.

Per the art direction: soft shading and dithering, NOT flat 8-bit. The tile face
carries a low-amplitude speckle (mineral fibre, and it keeps a 24px run of one
grey from banding), the panel field is brightest just inside its frame and falls
off to the corners the way a diffuser does, and the bloom is a real falloff
rather than a hard edge.

Usage:  python3 tools/gen_ceiling_panel.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/props/ceiling")

W, H = 24, 8

# The grid rail: a bright edge with its own shadow, which is what makes a run of
# tiles read as a GRID rather than as one long board.
RAIL_HI = (150, 156, 166)
RAIL_LO = (58, 62, 72)
# The tile face, unlit. Mid greys — see the note about drawing dim.
TILE_HI = (118, 124, 134)
TILE_LO = (86, 92, 102)
TILE_EDGE = (60, 64, 74)
# The panel: a darker frame around a field that is pale even before it is lit,
# so a DEAD panel still reads as a panel and not as a missing tile.
FRAME = (66, 70, 82)
FIELD_HI = (176, 186, 198)
FIELD_LO = (128, 136, 150)
# ...and what it throws when it is on. Cold, with the faintest green in it, the
# way a cheap tube reads against a warm bulb.
LIT_CORE = (250, 253, 255)
LIT_MID = (214, 232, 242)
LIT_EDGE = (158, 192, 212)

## The panel's frame, in cell pixels. Not a symmetric inset: the T-bar eats the
## first two columns, so centring the panel on the CELL leaves it visibly left of
## centre in the tile face you actually see. 4..21 centres it on that.
PANEL_X0, PANEL_X1 = 4, 21
PANEL_Y0, PANEL_Y1 = 1, 6

## The glow gets its own, larger canvas so the bloom can spill onto the tiles
## either side. Clipped to the cell it stops dead at the T-bar, which is the one
## thing a panel light never does.
GLOW_W, GLOW_H = 48, 16


def speckle(x, y):
    """Deterministic low-amplitude noise — mineral fibre, and it stops a 24px
    run of one grey from banding. A hash rather than `random` so re-running the
    tool cannot quietly produce different art.

    The first version multiplied x and y by two large primes and took three bits
    of the result, which at this amplitude came out as a clean 2x2 CHECKER — a
    pattern, which is the opposite of what noise is for. This mixes the bits
    properly and stays inside +/-2, where it reads as texture rather than as
    dirt."""
    h = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h >> 15) & 3) - 1.5         # -1.5 .. 1.5


def shade(c, amount):
    return tuple(max(0, min(255, int(round(v + amount)))) for v in c)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def tile_face(px, x, y):
    """One pixel of plain ceiling tile: lighter at the top where it catches the
    room, darker at the lip."""
    t = 1.0 - (y - 1) / float(H - 2)
    c = mix(TILE_LO, TILE_HI, t * 0.9)
    px[x, y] = shade(c, speckle(x, y)) + (255,)


def rail(px, x_rail):
    """The T-bar at the cell's left edge, and the shadow it drops."""
    for y in range(H):
        px[x_rail, y] = shade(RAIL_HI, -14 if y > H - 3 else 0) + (255,)
        px[x_rail + 1, y] = RAIL_LO + (255,)


def base_cell():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for x in range(W):
        px[x, 0] = TILE_EDGE + (255,)                 # against the slab above
        for y in range(1, H - 1):
            tile_face(px, x, y)
        px[x, H - 1] = shade(TILE_EDGE, 6) + (255,)   # the lip into the room
    rail(px, 0)
    return img


def light_cell():
    """A cell whose tile has been swapped for a panel — off."""
    img = base_cell()
    px = img.load()
    x0, x1 = PANEL_X0, PANEL_X1
    y0, y1 = PANEL_Y0, PANEL_Y1
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            if x in (x0, x1) or y in (y0, y1):
                px[x, y] = FRAME + (255,)             # the frame it sits in
                continue
            # The field: brightest just inside the frame, falling to the corners
            # the way a diffuser does.
            fx = 1.0 - abs(x - (x0 + x1) / 2.0) / ((x1 - x0) / 2.0)
            fy = 1.0 - abs(y - (y0 + y1) / 2.0) / ((y1 - y0) / 2.0)
            t = min(1.0, 0.45 + 0.55 * (fx * 0.55 + fy * 0.45))
            px[x, y] = mix(FIELD_LO, FIELD_HI, t) + (255,)
    return img


def glow_cell():
    """Only what emits, on its own larger canvas. Transparent everywhere else,
    because this becomes the texture of a light rather than something drawn."""
    img = Image.new("RGBA", (GLOW_W, GLOW_H), (0, 0, 0, 0))
    px = img.load()
    # Where the panel's field sits once the cell is centred in this canvas.
    ox, oy = (GLOW_W - W) // 2, (GLOW_H - H) // 2
    x0, x1 = ox + PANEL_X0 + 1, ox + PANEL_X1 - 1
    y0, y1 = oy + PANEL_Y0 + 1, oy + PANEL_Y1 - 1
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    for x in range(GLOW_W):
        for y in range(GLOW_H):
            # Distance outside the field, in pixels, on each axis.
            dx = max(0.0, x0 - x, x - x1)
            dy = max(0.0, y0 - y, y - y1)
            if dx == 0.0 and dy == 0.0:
                fx = 1.0 - abs(x - cx) / max(1.0, (x1 - x0) / 2.0)
                fy = 1.0 - abs(y - cy) / max(1.0, (y1 - y0) / 2.0)
                t = 0.55 + 0.45 * (fx * 0.5 + fy * 0.5)
                px[x, y] = mix(LIT_MID, LIT_CORE, t) + (255,)
                continue
            # The bloom past the frame, onto the tiles either side. Wider across
            # than down: the panel is a long shape and its spill follows it.
            reach = (dx / 11.0) ** 2 + (dy / 4.5) ** 2
            if reach >= 1.0:
                continue
            a = (1.0 - reach) ** 1.8
            # Dither the faintest of it so the bloom does not end on a ring.
            if a < 0.18 and (x + y) % 2:
                continue
            px[x, y] = mix(LIT_EDGE, LIT_MID, a) + (int(200 * a),)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, img in (("ceiling_tile.png", base_cell()),
                      ("ceiling_light.png", light_cell()),
                      ("ceiling_light_glow.png", glow_cell())):
        path = os.path.join(OUT, name)
        img.save(path)
        print("wrote %s  (%dx%d)" % (os.path.relpath(path, ROOT), *img.size))


if __name__ == "__main__":
    main()
