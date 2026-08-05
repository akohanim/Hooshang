#!/usr/bin/env python3
"""The conveyor belt sheet: one 16x16 grid holding every piece of the belt.

Writes assets/props/conveyor_belt.png, 128x96 = 8 columns x 6 rows of 16x16
cells. The rows are layers, not variants — a belt cell is a BASE sprite with a
TREAD sprite drawn over it, so the rubber can scroll without multiplying the
number of grimy-metal tiles by the number of animation frames:

    row 0  base     [single][cap left][middle A][middle B][cap right]
    row 1  tread    middle,   phases 0..7
    row 2  tread    cap left, phases 0..7
    row 3  tread    cap right, phases 0..7
    row 4  tread    single,   phases 0..7
    row 5  arrow    [points right][points left]

Base tile order matches tools/gen_glass_spikes.py — [single][first][middle A]
[middle B][last] — because every strip-shaped prop in this project is laid out
cap, middles, cap, and having them disagree about which cell is which is a bug
waiting to happen.

Anatomy of a cell, top to bottom: row 0 is the crown the player stands on, rows
0-8 are the rubber band seen edge-on, row 9 is the shadow under it, rows 10-14
are the steel skirt, row 15 is the contact shadow on the floor. The cap tiles
round the band off around a roller drum whose axle you can see from the side.

MOTION lives in the tread rows and nowhere else. A tread tile is transparent
except for the raised cleats — vertical ridges every 8px — so phase N is simply
the cleats moved N pixels right, and 8 phases is an exact loop. The cleats break
the crown line as they pass, which is what makes the belt read as moving even
where the player's own sprite covers most of it. Cap phases are the same cleats
masked to the rounded band and kept off the drum, so the ridges crowd into the
curve and vanish at the roller instead of running off the end of the world.

DIRECTION is said twice, deliberately: the tread scrolls, and an amber chevron
is recessed in the steel skirt every few cells. Motion alone is ambiguous the
instant the player stands still, and a belt you have to watch for a second to
read is a belt you get thrown off. Both chevrons are DRAWN, not mirrored, so the
light keeps coming from the upper left in each (same reasoning as the four
glass-spike facings).

Everything is desaturated and dim on purpose: Act I is a night office, so this
is worn black rubber and scuffed steel, with the indicator as the only warm
thing on it.

Re-run after editing:  python3 tools/gen_conveyor_belt.py
Preview it (6x, dark background, both directions, every phase):
                       python3 tools/gen_conveyor_belt.py --preview out.png
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "props")
CELL = 16
COLS, ROWS = 8, 6

# --- vertical anatomy ------------------------------------------------------
BAND_BOT = 8      # last row of rubber; the band is rows 0..8
SEAM = 9          # the dark line the band sits on
SKIRT = range(10, 15)
FLOOR = 15        # contact shadow

# The rubber band, top to bottom. A soft ramp rather than two flat tones: the
# crown has to read as a lit horizontal surface (it is the one he stands on) and
# the rest has to fall away from it.
BAND = [
    (86, 92, 102), (58, 62, 71), (46, 50, 57), (40, 43, 50), (36, 39, 45),
    (33, 36, 42), (30, 32, 38), (26, 28, 33), (19, 21, 25),
]
# Scuffed steel skirt, same idea: a bevel that catches the light at the top and
# goes to nothing at the floor. Kept a step DARKER than the band's crown on
# purpose — the first pass lit the skirt brightest and the belt read as a pale
# rail with a black plate balanced on it, which is exactly backwards: the line
# the eye should find is the one he stands on.
SKIRT_COLS = {
    SEAM: (12, 13, 16),
    10: (82, 88, 98), 11: (62, 66, 74), 12: (50, 54, 61),
    13: (40, 43, 50), 14: (28, 30, 36),
    FLOOR: (10, 11, 13),
}

RUST = (84, 54, 36)
RUST_DARK = (58, 38, 26)
SCUFF = (26, 28, 33)
EDGE = (16, 18, 22)

# A raised cleat: a lit column with its own shadow column behind it. Indexed by
# row so the ridge shades along with the band it stands on.
CLEAT_HI = [
    (150, 158, 170), (112, 119, 131), (96, 102, 113), (84, 90, 100),
    (74, 79, 88), (64, 69, 77), (54, 58, 66), (42, 45, 52), (28, 30, 36),
]
CLEAT_SH = [
    (44, 47, 54), (16, 18, 22), (14, 16, 20), (13, 14, 18), (12, 13, 17),
    (11, 12, 16), (10, 11, 15), (9, 10, 13), (8, 9, 12),
]
CLEAT_STEP = 8    # px between cleats; also the number of animation phases

# The indicator. The only warm colour on the prop.
AMBER_CORE = (255, 224, 152)
AMBER_MID = (240, 162, 54)
AMBER_DARK = (166, 96, 26)
GLOW_NEAR = (240, 162, 54, 64)
GLOW_FAR = (240, 162, 54, 26)

# Roller geometry, in tile-local pixels. The band is an ellipse-ended lozenge;
# rx is wider than ry so the end reads as a roller seen side-on rather than as a
# ball. Centres: 4.5 from the left end, 4.5 from the right.
CX_LEFT, CX_RIGHT = 4.5, 10.5
CY = 4.0
RX, RY = 5.6, 4.8
DRUM_R = 2.8
CLEAT_CLEAR = 3.7   # cleats keep this far off the drum


def new_tile():
    return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))


def covered(x, y, ends):
    """Is (x, y) part of the rubber band on a tile with these rounded `ends`?"""
    if y < 0 or y > BAND_BOT:
        return False
    if "left" in ends and x < CX_LEFT:
        if ((x - CX_LEFT) / RX) ** 2 + ((y - CY) / RY) ** 2 > 1.0:
            return False
    if "right" in ends and x > CX_RIGHT:
        if ((x - CX_RIGHT) / RX) ** 2 + ((y - CY) / RY) ** 2 > 1.0:
            return False
    return True


def drum_dist(x, y, cx):
    return ((x - cx) ** 2 + (y - CY) ** 2) ** 0.5


def band(px, ends):
    """Fill the rubber, then light its silhouette."""
    for x in range(CELL):
        for y in range(BAND_BOT + 1):
            if not covered(x, y, ends):
                continue
            c = BAND[y]
            # Worn patches. Fixed positions, so the tile is identical every run
            # and a long belt does not shimmer when Godot re-imports it.
            if 2 <= y <= 6 and (x * 7 + y * 13) % 11 == 0:
                c = tuple(min(255, v + 7) for v in c)
            px[x, y] = c + (255,)
    if "left" in ends:
        _rim(px, ends, "left")
    if "right" in ends:
        _rim(px, ends, "right")


def _rim(px, ends, side):
    """Light the curved end. Upper left catches the light, everything else is
    the dark edge — the same lamp that lights every other prop in Act I."""
    rng = range(CELL) if side == "left" else range(CELL - 1, -1, -1)
    for y in range(BAND_BOT + 1):
        for x in rng:
            if covered(x, y, ends):
                if side == "left":
                    c = (112, 119, 131) if y <= 3 else (74, 79, 88) if y == 4 else EDGE
                else:
                    c = (96, 102, 113) if y == 0 else (60, 64, 72) if y == 1 else (12, 14, 18)
                px[x, y] = c + (255,)
                break
    # The top and bottom of the curve, where a per-row rim never lands.
    cols = range(0, 4) if side == "left" else range(CELL - 4, CELL)
    for x in cols:
        ys = [y for y in range(BAND_BOT + 1) if covered(x, y, ends)]
        if not ys:
            continue
        px[x, ys[0]] = ((124, 132, 144) if side == "left" else (92, 98, 108)) + (255,)
        px[x, ys[-1]] = (10, 11, 14, 255)


def drum(px, cx):
    """The roller's end plate, visible past the rubber: steel, lit upper left,
    with the axle as a dark hole in the middle. This is the pixel that says
    'machine' rather than 'a black stripe on the floor'."""
    for x in range(CELL):
        for y in range(BAND_BOT + 1):
            d = drum_dist(x, y, cx)
            if d > DRUM_R:
                continue
            dx, dy = x - cx, y - CY
            if d > DRUM_R * 0.82:
                c = (26, 28, 34)
            elif dx + dy < -1.2:
                c = (126, 134, 146)
            elif dx + dy > 1.6:
                c = (30, 32, 38)
            else:
                c = (72, 77, 86)
            if d <= 1.05:
                c = (16, 18, 22) if d > 0.4 else (58, 62, 70)
            px[x, y] = c + (255,)


def skirt(px, ends, bolts, grime):
    """The steel below the band: bevel, bolts and grime."""
    for y, c in SKIRT_COLS.items():
        for x in range(CELL):
            px[x, y] = c + (255,)
    for x in grime:
        px[x, 12] = RUST + (255,)
        px[x, 13] = RUST_DARK + (255,)
    for x in bolts:
        px[x, 12] = (108, 115, 126, 255)
        px[x + 1, 12] = (72, 77, 86, 255)
        px[x, 13] = (50, 54, 61, 255)
        px[x + 1, 13] = (24, 26, 31, 255)
    # Where the skirt is cut it gets a dark edge, so a capped end reads as the
    # end of the machine and not as a tile that ran out.
    if "left" in ends:
        for y in list(SKIRT) + [SEAM]:
            px[0, y] = (18, 20, 25, 255)
            px[1, y] = tuple(int(v * 0.65) for v in SKIRT_COLS[y]) + (255,)
    if "right" in ends:
        for y in list(SKIRT) + [SEAM]:
            px[CELL - 1, y] = (18, 20, 25, 255)
            px[CELL - 2, y] = tuple(int(v * 0.65) for v in SKIRT_COLS[y]) + (255,)


# name -> (rounded ends, bolt x positions, grime x positions)
BASE_TILES = [
    ("single", ("left", "right"), (7,), ()),
    ("cap_left", ("left",), (11,), (8,)),
    ("mid_a", (), (8,), (2, 13)),
    ("mid_b", (), (3, 12), (7,)),
    ("cap_right", ("right",), (3,), (7,)),
]


def base_tile(ends, bolts, grime):
    tile = new_tile()
    px = tile.load()
    skirt(px, ends, bolts, grime)
    band(px, ends)
    if "left" in ends:
        drum(px, CX_LEFT)
    if "right" in ends:
        drum(px, CX_RIGHT)
    for x in [0, CELL - 1]:
        if (x == 0 and "left" in ends) or (x == CELL - 1 and "right" in ends):
            px[x, FLOOR] = (8, 9, 11, 255)
    return tile


def cleat_mask(ends):
    """Where a cleat is allowed: on the band, and clear of the roller drum."""
    ok = set()
    for x in range(CELL):
        for y in range(BAND_BOT + 1):
            if not covered(x, y, ends):
                continue
            if "left" in ends and drum_dist(x, y, CX_LEFT) <= CLEAT_CLEAR:
                continue
            if "right" in ends and drum_dist(x, y, CX_RIGHT) <= CLEAT_CLEAR:
                continue
            ok.add((x, y))
    return ok


def tread_tile(mask, phase):
    """Cleats only — everything else is transparent, so one set of phases works
    over any base tile with the same silhouette."""
    tile = new_tile()
    px = tile.load()
    for k in range(0, CELL, CLEAT_STEP):
        hx = (phase + k) % CELL
        sx = (hx + 1) % CELL
        for y in range(BAND_BOT + 1):
            if (hx, y) in mask:
                px[hx, y] = CLEAT_HI[y] + (255,)
            if (sx, y) in mask:
                px[sx, y] = CLEAT_SH[y] + (255,)
    return tile


# A chevron as (dx, dy) from its top-left, plus which pixel is the point. Drawn
# per direction rather than mirrored so the bright tip is always the leading
# edge and the tail always the dim end.
CHEVRON_RIGHT = [(0, 0), (1, 1), (2, 2), (1, 3), (0, 4)]
CHEVRON_LEFT = [(2, 0), (1, 1), (0, 2), (1, 3), (2, 4)]


def arrow_tile(points_right):
    tile = new_tile()
    px = tile.load()
    shape = CHEVRON_RIGHT if points_right else CHEVRON_LEFT
    tip = (2, 2) if points_right else (0, 2)
    lit = {}
    for x0 in (4, 9):
        for (dx, dy) in shape:
            x, y = x0 + dx, 10 + dy
            if (dx, dy) == tip:
                lit[(x, y)] = AMBER_CORE
            elif dy in (0, 4):
                lit[(x, y)] = AMBER_DARK
            else:
                lit[(x, y)] = AMBER_MID
    # Bloom onto the steel around it. The belt lives in a dark room, so the
    # halo is most of what sells this as a lamp recessed in the metal rather
    # than orange paint.
    glow = {}
    for (x, y) in lit:
        for (dx, dy, c) in [(1, 0, GLOW_NEAR), (-1, 0, GLOW_NEAR),
                            (0, 1, GLOW_NEAR), (0, -1, GLOW_NEAR),
                            (1, 1, GLOW_FAR), (1, -1, GLOW_FAR),
                            (-1, 1, GLOW_FAR), (-1, -1, GLOW_FAR)]:
            p = (x + dx, y + dy)
            if p in lit or not (0 <= p[0] < CELL and SEAM <= p[1] <= FLOOR):
                continue
            if glow.get(p, (0, 0, 0, 0))[3] < c[3]:
                glow[p] = c
    for p, c in glow.items():
        px[p[0], p[1]] = c
    for p, c in lit.items():
        px[p[0], p[1]] = c + (255,)
    return tile


def build_sheet():
    sheet = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
    for i, (_name, ends, bolts, grime) in enumerate(BASE_TILES):
        sheet.paste(base_tile(ends, bolts, grime), (i * CELL, 0))
    # Tread rows, in the order the GDScript expects: middle, cap left, cap
    # right, single.
    for row, ends in enumerate([(), ("left",), ("right",), ("left", "right")], start=1):
        mask = cleat_mask(ends)
        for phase in range(CLEAT_STEP):
            sheet.paste(tread_tile(mask, phase), (phase * CELL, row * CELL))
    sheet.paste(arrow_tile(True), (0, 5 * CELL))
    sheet.paste(arrow_tile(False), (CELL, 5 * CELL))
    return sheet


# --- preview ---------------------------------------------------------------
# Mirrors the layout in scenes/props/zones/conveyor_belt_visual.gd. It exists to
# be LOOKED at: a belt that reads correctly in code and wrong on screen is the
# normal outcome of a first pass at 16px.
ARROW_EVERY = 4


def base_variant(i, cells):
    if cells == 1:
        return 0
    if i == 0:
        return 1
    if i == cells - 1:
        return 4
    return 2 if i % 2 else 3


TREAD_ROW = {0: 4, 1: 2, 2: 1, 3: 1, 4: 3}


def arrow_cells(cells):
    first, last = 1, cells - 2
    if last < first:
        return [cells // 2]
    span = last - first + 1
    n = max(1, span // ARROW_EVERY)
    used = (n - 1) * ARROW_EVERY + 1
    start = first + (span - used) // 2
    return [start + k * ARROW_EVERY for k in range(n)]


def compose(sheet, cells, points_right, phase):
    out = Image.new("RGBA", (cells * CELL, CELL), (0, 0, 0, 0))
    for i in range(cells):
        v = base_variant(i, cells)
        cut = lambda c, r: sheet.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))
        out.alpha_composite(cut(v, 0), (i * CELL, 0))
        out.alpha_composite(cut(phase % CLEAT_STEP, TREAD_ROW[v]), (i * CELL, 0))
    for i in arrow_cells(cells):
        col = 0 if points_right else 1
        out.alpha_composite(sheet.crop((col * CELL, 5 * CELL, (col + 1) * CELL, 6 * CELL)),
                            (i * CELL, 0))
    return out


def _stack(top, bottom):
    out = Image.new("RGBA", (max(top.width, bottom.width), top.height + bottom.height),
                    (17, 18, 22, 255))
    out.alpha_composite(top, (0, 0))
    out.alpha_composite(bottom, (0, top.height))
    return out


def preview(sheet, path, scale=6):
    cells = 11
    belt_w = cells * CELL
    pad = 6
    rows = [("right, phase 0", compose(sheet, cells, True, 0)),
            ("left, phase 0", compose(sheet, cells, False, 0)),
            ("short (3 cells)", compose(sheet, 3, True, 2)),
            ("single cell", compose(sheet, 1, True, 4))]
    strip = [compose(sheet, cells, True, p) for p in range(CLEAT_STEP)]
    h = (len(rows) + len(strip)) * (CELL + pad) + pad * 3
    canvas = Image.new("RGBA", (belt_w + pad * 2, h), (17, 18, 22, 255))
    y = pad
    for _label, img in rows:
        canvas.alpha_composite(img, (pad, y))
        y += CELL + pad
    y += pad * 2
    for img in strip:          # every phase, stacked: the loop must be seamless
        canvas.alpha_composite(img, (pad, y))
        y += CELL + pad
    canvas = canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST)
    # A footer at the scales the game actually shows: the world is rasterised at
    # 320x180 and integer-upscaled, so 2x and 3x are what a player sees. Art
    # that only works at 6x is art that does not work.
    foot_h = (CELL * 2 + pad) * 2 + (CELL * 3 + pad) * 2 + pad * 2
    foot = Image.new("RGBA", (canvas.width, foot_h), (17, 18, 22, 255))
    y = pad
    for s in (2, 3):
        for d in (True, False):
            row = compose(sheet, cells, d, 0)
            foot.alpha_composite(row.resize((row.width * s, row.height * s), Image.NEAREST),
                                 (pad * 2, y))
            y += CELL * s + pad
    canvas = _stack(canvas, foot)
    canvas.save(path)
    print("wrote preview %s  %dx%d" % (path, canvas.width, canvas.height))


def ldtk_thumbnails(sheet):
    """One 16x16 tile per direction, for the LDtk entity palette.

    LDtk draws an entity as a flat colour unless its definition points at a
    tileset, and a belt drawn as an amber rectangle is a belt whose direction
    you cannot see while you are placing it — which is the whole reason the
    entity was split in two. Derived from the game sheet rather than drawn
    again, so the arrows in the editor can never disagree with the arrows in
    the game.
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    art = os.path.join(root, "ldtk", "art")
    os.makedirs(art, exist_ok=True)
    # Column 2 of the base row is middle A, row 1 is the middle tread, row 5
    # holds the two chevrons — see this file's header for the sheet map.
    base = sheet.crop((2 * CELL, 0, 3 * CELL, CELL))
    tread = sheet.crop((0, 1 * CELL, CELL, 2 * CELL))
    for name, col in (("right", 0), ("left", 1)):
        tile = base.copy()
        tile.alpha_composite(tread)
        tile.alpha_composite(sheet.crop(
            (col * CELL, 5 * CELL, (col + 1) * CELL, 6 * CELL)))
        path = os.path.join(art, "conveyor_belt_%s.png" % name)
        tile.save(path)
        print("wrote %s  %dx%d" % (path, tile.width, tile.height))


if __name__ == "__main__":
    sheet = build_sheet()
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, "conveyor_belt.png")
    sheet.save(out)
    print("wrote %s  %dx%d" % (out, sheet.width, sheet.height))
    ldtk_thumbnails(sheet)
    if "--preview" in sys.argv:
        preview(sheet, sys.argv[sys.argv.index("--preview") + 1])
