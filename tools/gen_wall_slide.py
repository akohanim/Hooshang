#!/usr/bin/env python3
"""The wall slide: three frames cut from the painted sheet, plus the landing.

Source: assets/hooshang_sprites/source/wall_slide_sheet.png — a 2x2 grid of
1024px cells on a flat opaque grey, with a title burned into the top-left.
Output: 88x88 RGBA frames under assets/hooshang_sprites/animations/, laid out
the way every other clip in there already is:

    Wall_Slide/east/frame_000..002.png   the slide proper, a loop
    Wall_Land/east/frame_000.png         the bottom-right cell, see below

assets/hooshang_frames.tres plays the three as 0-1-2-1 rather than 0-1-2. The
dust builds across them, so a straight loop snaps a settled cloud back to first
sparks once a second; running the middle pose again on the way out both hides
that seam and reads as what he is doing — scrabbling for grip. (That note lives
here because Godot rewrites a .tres on save and strips comments out of it.)

Three things here are not a resize, and each is a way the frame goes wrong:

- **The grey is keyed out, not thresholded away.** It is opaque #8D949C and it
  is also mixed into every antialiased edge, so a hard alpha cut alone leaves a
  grey halo tracing him. The key recovers the mixing fraction, un-mixes the
  edge colour back out of it (C = a*F + (1-a)*BG, solved for F), and only THEN
  cuts alpha hard on the way down — the same order gen_pomegranate.py uses on
  its painted rim, for the same reason.
- **The wall is dropped.** Each slide cell draws the wall he is sliding on as a
  vertical line, and the level already draws that. Kept, it would put a second
  wall on screen, floating over the real one, every time he touches one. The
  dust IS kept: it reads as his motion, not as scenery, and it lives entirely
  left of the wall, so the same cut keeps one and loses the other.
- **He is registered to the hitbox, not to his cell.** The four poses sit at
  four different places in their 1024px cells, which is framing, not animation.
  Left alone it would read as a shudder. Every frame is placed so the wall in
  the art lands on the wall in the game (WALL_X) and his lowest boot lands on
  the same foot line the rest of the sprite sheet uses (FEET_Y).

The fourth pose (bottom-right) is NOT a wall slide: he is crouched on the
ground, no wall contact, landing. wall_slide is a state the player can hold
indefinitely (_state_wall_slide in player.gd), so a one-off landing beat in
that loop would replay forever. It is cut anyway, at the same scale and onto
the same canvas, as its own single-frame `Wall_Land` clip — the art exists and
the day a LAND state does, it is already the right size.

He faces RIGHT with the wall on his right, which is what the game wants
unflipped: entering WALL_SLIDE requires input pushing INTO the wall
(_post_move), and `facing` is set from that same input, so facing == wall_dir
always. `flip_h = facing < 0` then puts his hand on the correct wall for free.

Re-run after editing: python3 tools/gen_wall_slide.py [--preview OUT.png]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "hooshang_sprites")
SRC = os.path.join(SPRITES, "source", "wall_slide_sheet.png")
ANIM = os.path.join(SPRITES, "animations")

CELL = 1024                      # the sheet is 2x2 of these
CANVAS = 88                      # every existing frame in the pack is 88x88

## The flat backdrop, sampled off the sheet's corners. Everything within
## KEY_LO of it is background; everything past KEY_HI is solid him; between the
## two is the painted edge, which is where the halo comes from.
BG = np.array([141, 148, 156], dtype=np.int16)
KEY_LO = 6                       # measured backdrop noise never exceeds 4
KEY_HI = 44

## Alpha below this is cut away entirely once the frame is small. Same job as
## gen_pomegranate.py's cut: a painted edge fades out over several source
## pixels and at 88px that becomes a fringe of half-transparent grey.
ALPHA_CUT = 116
## Colours kept after the downscale. The coat, trousers, skin and hair each
## carry a gradient, and dropping much below this flattens them into the
## "8-bit/NES" look CLAUDE.md explicitly rules out.
PALETTE = 40

## How tall, in output px, the TALLEST of the three slide poses is drawn.
##
## The trap this number exists to avoid: the cells are 1024px and the frames
## are 88, so a wrong scale changes Hooshang's size the instant he touches a
## wall. It cannot be copied straight off a standing frame — the existing
## clips measure 43-44px tall (Breathing_Idle, Wall_Jump frame_000) and he is
## TUCKED here, knees up, so an honest tuck has to come out shorter than a
## stand or he reads as a bigger man on walls.
##
## What settles it is the HEAD, the one part of him that a pose cannot resize.
## At 38 his head measures 11px wide and 9 rows to the neck; Breathing_Idle's
## is 12 by 9. The landing pose then lands at 34px against the same clip's 43,
## a crouch at 79% of his standing height, which is what a crouch is. Change
## this and re-measure both, not one.
SLIDE_H = 38

## Where he is pinned on the 88x88 canvas, in texture px.
##
## Hooshang.tscn draws the sprite centred with offset (0,-7) at scale 0.39, so
## texture (tx,ty) sits at world (0.39*(tx-44), 0.39*(ty-51)). The hitbox is
## 8x12: its right face is world x=+4 -> tx 54.3, its floor is world y=+6 ->
## ty 66.4. FEET_Y matches the pack, whose feet land on 65.
WALL_X = 54                      # the wall face, for the three slide poses
FEET_Y = 65                      # his lowest boot, every pose
CENTRE_X = 44                    # poses with no wall are centred instead

## The caption band: searched this far down from the top edge (his crown is at
## row 205), and called a caption at this many near-black pixels in one row.
LABEL_MARGIN = 200
LABEL_INK = 250

## A column that is opaque down more than this much of its cell is the drawn
## wall, not him: his tallest body column covers ~0.45 of a cell, the wall
## covers ~0.78. Likewise a row this wide is the ground line under the landing.
WALL_COVER = 0.68
GROUND_COVER = 0.70
## ...and the cut is taken this far to the near side of it. The line's own
## antialiased edge is only ~2px, but leaving it behind is not a cosmetic
## problem: those pixels are neither backdrop nor him, so they SEAL the strip
## of backdrop between his back and the wall, the hole fill below then reads
## that strip as interior, and he comes out with a solid grey slab painted
## down his side. It cost him half an output pixel of fingertip to fix.
CUT_FEATHER = 4


# ------------------------------------------------------------------ input ----

def load_sheet():
    rgb = np.array(Image.open(SRC).convert("RGB"), dtype=np.int16)
    if rgb.shape[:2] != (CELL * 2, CELL * 2):
        raise SystemExit("expected a %dx%d sheet, got %dx%d"
                         % (CELL * 2, CELL * 2, rgb.shape[1], rgb.shape[0]))
    return rgb


def strip_labels(sheet, dist):
    """Blank the burned-in title rows in place.

    "WALL-SLIDE ANIMATION SHEET" is a caption, not art, and the whole of it
    sits in the margin above the first cell: it runs rows 41-81, and the
    topmost pixel of Hooshang anywhere on the sheet is row 205. So the search
    is confined to the top margin and the test is just ink — near-black pixels
    per row. That test does NOT generalise past the margin, which is the reason
    for the confinement: his outline puts 800 near-black pixels in a row
    through the middle of a pose, more than any letterform does.

    This sheet was described as captioned twice, top-left and bottom-left. It
    is captioned once. The bottom 200 rows are the landing pose's dust and its
    ground bar, and there is no text under them.
    """
    ink = (sheet[:LABEL_MARGIN].max(axis=2) < 75).sum(axis=1)
    rows = np.where(ink > LABEL_INK)[0]
    if len(rows):
        dist[max(0, rows.min() - 6):rows.max() + 7, :] = 0


# ------------------------------------------------------------- geometry ----

def flood(passable, seed):
    """Everything in `passable` reachable from `seed`, 4-connected.

    A plain dilate-and-mask to a fixed point. It runs to ~1200 iterations on a
    1024px cell and still costs well under a second, which is cheaper than
    taking a scipy dependency for the two places this is needed.
    """
    reach = seed & passable
    while True:
        grown = reach.copy()
        grown[1:, :] |= reach[:-1, :]
        grown[:-1, :] |= reach[1:, :]
        grown[:, 1:] |= reach[:, :-1]
        grown[:, :-1] |= reach[:, 1:]
        grown &= passable
        if np.array_equal(grown, reach):
            return reach
        reach = grown


def cell_geometry(dist):
    """(wall_x, ground_y) for one cell's distance map, either may be None."""
    solid = dist > 18
    cover = solid.sum(axis=0)
    wall = np.where(cover > WALL_COVER * CELL)[0]
    wall_x = int(wall.min()) if len(wall) else None
    if wall_x is not None:
        solid = solid.copy()
        solid[:, wall_x:] = False
    rows = np.where(solid.sum(axis=1) > GROUND_COVER * CELL)[0]
    return wall_x, (int(rows.min()) if len(rows) else None)


def body_box(dist):
    """His own bounding box — the blob he is, with the dust left out.

    Scale and placement both key off this, and the dust must not vote on
    either: it hangs up to 80 source px below his boots and by a different
    amount in each pose, so a bbox that counted it would set every frame down
    at a different height.

    The blob is found by flooding out from the widest strongly-coloured row,
    which crosses his torso in all four poses. A centroid would not do: these
    are curled poses and the centre of the bounding box lands in the air under
    his knees.
    """
    solid = dist > 55
    row = int(np.argmax(solid.sum(axis=1)))
    seed = np.zeros_like(solid)
    seed[row, int(np.median(np.where(solid[row])[0]))] = True
    ys, xs = np.where(flood(solid, seed))
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def scenery_cut(dist, row, col):
    """One cell's distance map with the drawn wall and ground taken out.

    Returns (map, wall_x) — wall_x is None for the pose with no wall, which is
    also the only one with a ground bar, and the only one placed by its centre.
    """
    d = dist[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL].copy()
    wall_x, ground_y = cell_geometry(d)
    if wall_x is not None:
        wall_x = max(0, wall_x - CUT_FEATHER)
        d[:, wall_x:] = 0          # the wall line and anything drawn behind it
    if ground_y is not None:
        d[max(0, ground_y - CUT_FEATHER):, :] = 0   # ground bar under the landing
    return d, wall_x


# ------------------------------------------------------------------- key ----

def keyed(rgb, dist):
    """Grey backdrop -> alpha, with the grey taken back out of the edge.

    Two steps that have to happen in this order. The soft ramp gives the
    painted edge a mixing fraction instead of an all-or-nothing cut; the
    un-mix then solves C = a*F + (1-a)*BG for F, which is what actually removes
    the grey from the rim rather than merely making it see-through.

    Enclosed backdrop-coloured pixels are forced solid first. His hair and
    collar carry highlights within 17 of the backdrop, and keying is a colour
    test, not a shape test — untreated it punches holes through the middle of
    his head.
    """
    open_ = dist <= KEY_LO
    border = np.zeros_like(open_)
    border[0, :] = border[-1, :] = True
    border[:, 0] = border[:, -1] = True
    holes = open_ & ~flood(open_, border)
    alpha = np.clip((dist.astype(np.float32) - KEY_LO) / (KEY_HI - KEY_LO), 0.0, 1.0)
    alpha[holes] = 1.0

    a = alpha[..., None]
    front = np.where(a > 0.02, (rgb - (1.0 - a) * BG) / np.maximum(a, 0.02), rgb)
    out = np.zeros(rgb.shape[:2] + (4,), dtype=np.uint8)
    out[..., :3] = np.clip(front, 0, 255).astype(np.uint8)
    out[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(out)


def shrink(img, size):
    """Down to `size`, premultiplied, then re-cut to hard pixel edges.

    Premultiplying before the resample is what stops the transparent pixels'
    colour bleeding inward; going via 4x the target and sharpening in between
    is gen_pomegranate.py's trick for keeping structure that a single
    12x reduction would average away — here it is the difference between a
    face and a beige smudge.
    """
    a = np.array(img).astype(np.float32)
    a[..., :3] *= a[..., 3:4] / 255.0
    mid = (size[0] * 4, size[1] * 4)
    small = Image.fromarray(a.astype(np.uint8)).resize(mid, Image.LANCZOS)
    small = ImageEnhance.Sharpness(small).enhance(2.0)
    small = small.resize(size, Image.BOX)

    b = np.array(small).astype(np.float32)
    alpha = b[..., 3:4] / 255.0
    b[..., :3] = np.where(alpha > 0.02, b[..., :3] / np.maximum(alpha, 0.02), b[..., :3])
    b[..., 3] = np.where(b[..., 3] >= ALPHA_CUT, 255, 0)
    small = Image.fromarray(np.clip(b, 0, 255).astype(np.uint8))
    small = ImageEnhance.Sharpness(small).enhance(1.4)
    flat = small.convert("RGB").quantize(
        colors=PALETTE, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    return Image.fromarray(
        np.dstack([np.array(flat), np.array(small)[..., 3]]).astype(np.uint8))


# ----------------------------------------------------------------- cells ----

def cut(sheet, dist, row, col, scale):
    """One cell -> one 88x88 frame, placed against the hitbox."""
    rgb = sheet[row * CELL:(row + 1) * CELL,
                col * CELL:(col + 1) * CELL].astype(np.float32)
    d, wall_x = scenery_cut(dist, row, col)
    bx0, _, bx1, by1 = body_box(d)

    art = keyed(rgb, d)
    box = art.getbbox()            # includes his dust, which travels with him
    art = art.crop(box)
    size = (max(1, int(round(art.width * scale))),
            max(1, int(round(art.height * scale))))
    small = shrink(art, size)

    # Cell px -> small-frame px, so the anchors survive the resize exactly.
    def to_small(x, y):
        return (x - box[0]) * scale, (y - box[1]) * scale

    if wall_x is not None:
        anchor_x, _ = to_small(wall_x, 0)
        left = WALL_X - int(round(anchor_x))
    else:
        mid, _ = to_small((bx0 + bx1) * 0.5, 0)
        left = CENTRE_X - int(round(mid))
    _, foot = to_small(0, by1)
    top = FEET_Y - int(round(foot))

    frame = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    frame.alpha_composite(small, (left, top))
    return frame


# ------------------------------------------------------------------ main ----

# (row, col) of each pose, in the order they play.
SLIDE_CELLS = [(0, 0), (0, 1), (1, 0)]
LAND_CELL = (1, 1)


def build():
    sheet = load_sheet()
    dist = np.abs(sheet - BG).max(axis=2)
    strip_labels(sheet, dist)

    # One scale for the whole sheet, from the tallest slide pose. Measuring
    # each pose against its own height would silently resize him mid-loop.
    heights = []
    for (r, c) in SLIDE_CELLS:
        _, by0, _, by1 = body_box(scenery_cut(dist, r, c)[0])
        heights.append(by1 - by0 + 1)
    scale = float(SLIDE_H) / max(heights)

    frames = [cut(sheet, dist, r, c, scale) for (r, c) in SLIDE_CELLS]
    land = cut(sheet, dist, LAND_CELL[0], LAND_CELL[1], scale)
    return frames, land, scale, heights


def write(frames, land):
    slide_dir = os.path.join(ANIM, "Wall_Slide", "east")
    land_dir = os.path.join(ANIM, "Wall_Land", "east")
    os.makedirs(slide_dir, exist_ok=True)
    os.makedirs(land_dir, exist_ok=True)
    for i, f in enumerate(frames):
        f.save(os.path.join(slide_dir, "frame_%03d.png" % i))
    land.save(os.path.join(land_dir, "frame_000.png"))


def preview(frames, land, path, zoom=6):
    """The frames at 6x on office dark, each with the hitbox and the wall face
    drawn over them — the only question that matters here is whether he is the
    right SIZE and whether his hand is on the wall, and neither is answerable
    from a transparent PNG in an image viewer."""
    cells = frames + [land]
    pad = 6
    w = len(cells) * (CANVAS * zoom + pad) + pad
    out = Image.new("RGBA", (w, CANVAS * zoom + pad * 2), (24, 26, 32, 255))
    for i, cell in enumerate(cells):
        x = pad + i * (CANVAS * zoom + pad)
        out.alpha_composite(cell.resize((CANVAS * zoom, CANVAS * zoom), Image.NEAREST),
                            (x, pad))
        px = out.load()
        for ty in range(CANVAS):
            for tx in range(CANVAS):
                on_box = (abs(tx - CENTRE_X) <= 4 and abs(ty - 51) * 0.39 <= 6.0
                          and (abs(abs(tx - CENTRE_X) - 4) < 1
                               or abs(abs(ty - 51) * 0.39 - 6.0) < 0.4))
                on_wall = tx == WALL_X
                if not (on_box or on_wall):
                    continue
                tint = (90, 200, 120, 255) if on_box else (200, 90, 90, 255)
                for dy in range(zoom):
                    px[x + tx * zoom, pad + ty * zoom + dy] = tint
                    if on_box:
                        for dx in range(zoom):
                            px[x + tx * zoom + dx, pad + ty * zoom] = tint
    out.save(path)


def main():
    frames, land, scale, heights = build()
    write(frames, land)
    for name, f in [("wall_slide %d" % i, fr) for i, fr in enumerate(frames)] + \
                   [("wall_land 0", land)]:
        box = f.getbbox()
        print("%-14s %dx%d  drawn x[%d,%d] y[%d,%d]"
              % (name, f.width, f.height, box[0], box[2] - 1, box[1], box[3] - 1))
    print("scale %.5f (source body heights %s -> %d px)"
          % (scale, heights, SLIDE_H))
    if "--preview" in sys.argv:
        dest = sys.argv[sys.argv.index("--preview") + 1]
        preview(frames, land, dest)
        print("wrote preview %s" % dest)


if __name__ == "__main__":
    main()
