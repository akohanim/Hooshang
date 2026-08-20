#!/usr/bin/env python3
"""The suspended office ceiling: grid tiles, and the light panels set INTO them.

The reference is a plain modern office ceiling seen from below — white acoustic
tiles in a T-bar grid, with flat luminous panels flush in the grid where a tile
would otherwise be. Not a fixture hanging on rods: a panel that IS one of the
ceiling tiles.

24x8 cells — the same unit `tools/gen_platforms.py` cuts its ceiling strip at,
deliberately, because in this Act the ceiling and the thing he ends up standing
on are the same ceiling. Laying them end to end gives a continuous run.

TWO ORIENTATIONS, because they are two different objects. Overhead, you are
looking UP at it: the grid rail catches the room and the lip below it is in
shadow. As a floor you are looking at it EDGE ON with a surface on top: the lip
is the brightest thing on the cell because it is what says "stand here", and the
panel has moved to the underside where a panel actually is. Reusing the overhead
art as a floor puts its dark edge on top, and `gen_platforms.py` already records
what that looks like — a hole.

  ceiling_tile.png        overhead: a plain tile, T-bar rail on its left edge,
                          so consecutive tiles butt into a grid
  ceiling_light.png       overhead: the same cell with a light panel in it
                          instead of a tile — thin frame, flat field, vignette
  ceiling_light_glow.png  overhead: ONLY what emits, on transparent, with the
                          bloom that spills past the frame onto its neighbours
  ceiling_floor.png       the same tile as a SURFACE: standing lip on top,
                          underside in shadow
  ceiling_floor_light.png the same, with the panel in its underside
  ceiling_floor_glow.png  what that panel emits — biased DOWNWARD, because the
                          light of a ceiling falls into the room beneath it
  ceiling_tile_glow.png   what the PAINTED 8px panel emits. Its own file and not
                          a scaled copy of the 24px one: the painted cell's panel
                          is 5px wide where the prop's is 17, and a glow drawn
                          for the wrong one either floats past the tile's frame
                          or sits inside it looking like a chip of paint

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


## The floor orientation's panel: lower in the cell than the overhead one,
## because on a ceiling seen edge-on the panel is in the underside.
FLOOR_Y0, FLOOR_Y1 = 3, 7
## The standing lip, brightest thing on the cell.
LIP_HI = (198, 204, 214)
LIP_LO = (150, 156, 168)


def floor_cell():
    """A plain ceiling tile seen EDGE ON, as something to stand on."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for x in range(W):
        px[x, 0] = shade(LIP_HI, speckle(x, 0)) + (255,)      # the lip
        px[x, 1] = shade(LIP_LO, speckle(x, 1)) + (255,)
        for y in range(2, H - 1):
            # The face falls away under the lip, into the shadow of its own
            # underside.
            t = 1.0 - (y - 2) / float(H - 3)
            c = mix(TILE_LO, TILE_HI, 0.15 + t * 0.7)
            px[x, y] = shade(c, speckle(x, y)) + (255,)
        px[x, H - 1] = TILE_EDGE + (255,)
    # The rail, but only below the lip: a T-bar does not cross the top surface.
    for y in range(2, H):
        px[0, y] = shade(RAIL_HI, -20) + (255,)
        px[1, y] = RAIL_LO + (255,)
    return img


def floor_light_cell():
    """...with a light panel set into its underside."""
    img = floor_cell()
    px = img.load()
    x0, x1 = PANEL_X0, PANEL_X1
    y0, y1 = FLOOR_Y0, FLOOR_Y1
    for x in range(x0, x1 + 1):
        for y in range(y0, min(y1, H - 1) + 1):
            if x in (x0, x1) or y == y0:
                px[x, y] = FRAME + (255,)
                continue
            fx = 1.0 - abs(x - (x0 + x1) / 2.0) / ((x1 - x0) / 2.0)
            t = min(1.0, 0.5 + 0.5 * fx)
            px[x, y] = mix(FIELD_LO, FIELD_HI, t) + (255,)
    return img


def floor_glow():
    """What the underside panel throws. Biased DOWNWARD — a ceiling lights the
    room beneath it, and a symmetric bloom would put half of it in the slab."""
    img = Image.new("RGBA", (GLOW_W, GLOW_H), (0, 0, 0, 0))
    px = img.load()
    ox, oy = (GLOW_W - W) // 2, (GLOW_H - H) // 2
    x0, x1 = ox + PANEL_X0 + 1, ox + PANEL_X1 - 1
    y0, y1 = oy + FLOOR_Y0 + 1, oy + min(FLOOR_Y1, H - 1)
    cx = (x0 + x1) / 2.0
    for x in range(GLOW_W):
        for y in range(GLOW_H):
            dx = max(0.0, x0 - x, x - x1)
            dy_up = max(0.0, y0 - y)
            dy_dn = max(0.0, y - y1)
            if dx == 0.0 and dy_up == 0.0 and dy_dn == 0.0:
                fx = 1.0 - abs(x - cx) / max(1.0, (x1 - x0) / 2.0)
                px[x, y] = mix(LIT_MID, LIT_CORE, 0.55 + 0.45 * fx) + (255,)
                continue
            # Up is cut short by the tile above the panel; down is open room.
            reach = (dx / 10.0) ** 2 + (dy_up / 1.6) ** 2 + (dy_dn / 6.0) ** 2
            if reach >= 1.0:
                continue
            a = (1.0 - reach) ** 1.8
            if a < 0.18 and (x + y) % 2:
                continue
            px[x, y] = mix(LIT_EDGE, LIT_MID, a) + (int(200 * a),)
    return img


## The painted 8px cell's panel, in cell pixels — see tools/gen_bricks_8px.py's
## `ceiling`, which draws it. Kept here because the glow has to sit exactly on it.
TILE_PANEL_X0, TILE_PANEL_X1 = 2, 6
TILE_PANEL_Y0, TILE_PANEL_Y1 = 4, 6
## Canvas for that glow, with the 8px cell centred in it so the bloom has room to
## fall past the tile onto whatever is under it.
TILE_GLOW_W, TILE_GLOW_H = 24, 16


def tile_glow():
    """What a PAINTED panel cell emits, for the light the importer hangs on it.

    A painted tile cannot glow on its own — CanvasModulate is 0.05 and multiplies
    every CanvasItem — so scripts/ldtk_level_post_import.gd puts a PointLight2D
    wearing this on every panel cell it finds. The shape is art, the brightness
    is light.
    """
    img = Image.new("RGBA", (TILE_GLOW_W, TILE_GLOW_H), (0, 0, 0, 0))
    px = img.load()
    ox, oy = (TILE_GLOW_W - 8) // 2, (TILE_GLOW_H - 8) // 2
    x0, x1 = ox + TILE_PANEL_X0 + 1, ox + TILE_PANEL_X1 - 1
    y0, y1 = oy + TILE_PANEL_Y0 + 1, oy + TILE_PANEL_Y1
    cx = (x0 + x1) / 2.0
    for x in range(TILE_GLOW_W):
        for y in range(TILE_GLOW_H):
            dx = max(0.0, x0 - x, x - x1)
            dy_up = max(0.0, y0 - y)
            dy_dn = max(0.0, y - y1)
            if dx == 0.0 and dy_up == 0.0 and dy_dn == 0.0:
                fx = 1.0 - abs(x - cx) / max(1.0, (x1 - x0) / 2.0)
                px[x, y] = mix(LIT_MID, LIT_CORE, 0.6 + 0.4 * fx) + (255,)
                continue
            # Down is open room; up is the tile the panel is set into.
            reach = (dx / 5.5) ** 2 + (dy_up / 1.4) ** 2 + (dy_dn / 4.5) ** 2
            if reach >= 1.0:
                continue
            a = (1.0 - reach) ** 1.7
            if a < 0.18 and (x + y) % 2:
                continue
            px[x, y] = mix(LIT_EDGE, LIT_MID, a) + (int(205 * a),)
    return img


def ldtk_icon():
    """The 16x16 LDtk shows in its entity list. A slice of the lit floor cell
    rather than a drawing of one, so the icon cannot drift from the art."""
    cell = floor_light_cell().convert("RGBA")
    glow = floor_glow()
    lit = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lit.alpha_composite(cell)
    lit.alpha_composite(glow.crop(((GLOW_W - W) // 2, (GLOW_H - H) // 2,
                                   (GLOW_W - W) // 2 + W, (GLOW_H - H) // 2 + H)))
    icon = Image.new("RGB", (16, 16), (22, 24, 30))
    icon.paste(lit.crop((4, 0, 20, H)).convert("RGB"), (0, 4))
    return icon


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, img in (("ceiling_tile.png", base_cell()),
                      ("ceiling_light.png", light_cell()),
                      ("ceiling_light_glow.png", glow_cell()),
                      ("ceiling_floor.png", floor_cell()),
                      ("ceiling_floor_light.png", floor_light_cell()),
                      ("ceiling_floor_glow.png", floor_glow()),
                      ("ceiling_tile_glow.png", tile_glow())):
        path = os.path.join(OUT, name)
        img.save(path)
        print("wrote %s  (%dx%d)" % (os.path.relpath(path, ROOT), *img.size))
    # The LDtk entity icon lives beside the project file, not with the game art.
    icon_path = os.path.join(ROOT, "ldtk/art/ceiling_floor.png")
    ldtk_icon().save(icon_path)
    print("wrote %s  (16x16)" % os.path.relpath(icon_path, ROOT))


if __name__ == "__main__":
    main()
