#!/usr/bin/env python3
"""The props of Act III's last scene, THE VINE (SCRIPT.md THIRTEEN): the vine
Hooshang hangs from, the black and the white mouse that gnaw at it, and the
lemon growing out of the cliff within reach of his hand.

Hand-placed pixels in the adult rig's scale and outline weight, written as
strings so a change is a change of one character. Writes, into
assets/act3/vine/:
  vine.png    3 frames of 48x122, left to right: whole, gnawed, fraying: the
              vine DRAPED from its roots on the cliff top over the edge and down
              the face (draped_vine; the older straight strip, vine_frame, is
              kept but unused).
  mice.png    2 rows (black, white) x 3 gnawing frames of 9x6, facing right.
  lemon.png   4 frames of 10x10: on its sprig, then three bites gone.

    python3 tools/gen_vine_scene.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/act3/vine'

PAL = {
    'a': '#22150f',   # outline
    'r': '#5a3f2c', 'R': '#3d2a20', 'q': '#7d5a3c',            # root and stem wood
    'v': '#4f7f34', 'V': '#2f5523', 'u': '#7fae4a',            # vine
    'l': '#6fa84a', 'L': '#3f7a3a', 'h': '#a9cf62',            # leaves
    'f': '#c9b98e',                                            # chewed fibre
    # mice
    'k': '#2c2b33', 'K': '#5d5c6b', 'w': '#f3f0e8', 'W': '#bdb7ad', 'p': '#e4a2a8', 'e': '#16141a',
    'E': '#c0303a',
    # lemon
    'y': '#f6d43c', 'Y': '#fff08a', 'o': '#d0a52a', 'g': '#5f9a3f',
}

# The root clump and the first few px of vine are the same in every state;
# what changes is the band the mice work at (rows 6-9) and the leaves below.
ROOT_ROWS = [
    "....aaaaaa....",
    "..aarRrRqraa..",
    ".arRrqRrRrRra.",
    "..aaarvVraaa..",
    "....aavVa.....",
    ".....avVa.....",
]
WHOLE_BITE = [
    ".....avVa.....",
    ".....avVa.....",
    ".....avVa.....",
    ".....avVa.....",
]
GNAWED_BITE = [
    ".....avVa.....",
    "......aVfa....",
    ".....afVa.....",
    ".....avVa.....",
]
FRAYING_BITE = [
    ".....avfa.....",
    "......afa.....",
    ".....afa......",
    ".....avfa.....",
]
# Below the bite: the vine hangs, a leaf every few px, alternating sides.
LEAF_L = ["..aLla.avVa...", ".alhla.avVa...", "..aaa..avVa..."]
LEAF_R = ["......avVa.ala", "......avVaalha", "......avVa.aa."]
PLAIN = ".....avVa....."
PLAIN2 = "......avVa...."


# ---------------------------------------------------------------- the vine --
# The vine is DRAPED: rooted in the soil of the cliff top a little back from its
# corner (the LIP), lying along the grass to the edge, over it, and down the
# face IN FRONT of the rock to where he hangs. Hanging straight beside the face
# from a root in mid-air (the first version) it read as a rope from nowhere,
# and the mice gnawing at that root had nothing to stand on. Drawn as a path in
# room pixels measured from the lip, so the beats can place it on the cliff:
# Act3Beats.VINE_ORIGIN / VINE_GRIP / VINE_GNAW are these same numbers.
VW, VH = 48, 122
ORIGIN = (-44, -12)          # the frame's top-left, from the lip
GRIP = (-3, 93)              # where his hands close, from the lip
GNAW = -15                   # x of the bite, on the stem lying on the grass
# The centre line, on pixel BOUNDARIES so the stem is two pixels of green with
# a one-pixel outline: along the grass, over the corner, down the face (the
# face's own edge is at x -2; the stem's core is the two columns inside it).
PATH = [(-32, -2), (-4, -2), (-2, -1.5), (-1, 0), (-0.6, 2), (-1, 5), (-2, 8), (-3, 11),
        (-3, 36), (-4, 42), (-4, 66), (-3, 72), (-3, GRIP[1])]
# The lemon's twig, out of a crack in the face just above where it hangs (the
# collectible lemon itself, Act3Beats.LEMON_AT, is drawn by the game).
TWIG = [(-23, 100, 'a'), (-23, 101, 'a'), (-22, 101, 'q'), (-21, 102, 'q'), (-20, 102, 'R'),
        (-19, 103, 'q'), (-18, 104, 'R'), (-22, 100, 'L'), (-21, 99, 'l'), (-20, 99, 'h'), (-21, 100, 'a')]


def _path_x(y):
    """The centre line's x at height y on the drop down the face."""
    for (ax, ay), (bx, by) in zip(PATH, PATH[1:]):
        if ay <= y <= by and by > ay:
            return ax + (bx - ax) * (y - ay) / (by - ay)
    return PATH[-1][0]
ROOT_KNOT = [
    "..aaaaa..",
    ".arRqRra.",
    "arRrRqRra",
    "aRrRrRrRa",
    ".aRraRRa.",
]
ROOTS = [[(-39, 0), (-40, 1), (-41, 2), (-41, 3), (-42, 4)],
         [(-36, 0), (-36, 1), (-35, 2), (-36, 3), (-36, 4), (-35, 5)],
         [(-33, 0), (-32, 1), (-31, 2), (-30, 3)]]
LEAF_LEFT = [[(-4, 'a'), (-3, 'L'), (-2, 'l'), (-1, 'a')],
             [(-5, 'a'), (-4, 'l'), (-3, 'h'), (-2, 'l'), (-1, 'a')],
             [(-4, 'a'), (-3, 'a'), (-2, 'a')]]
LEAF_UP = [[(-1, 'a'), (0, 'a')], [(-2, 'a'), (-1, 'l'), (0, 'h'), (1, 'a')], [(-1, 'a'), (0, 'L'), (1, 'a')]]


def _segment_distance(px, py, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    cx, cy = ax + t * dx, ay + t * dy
    return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5, (px - cx, py - cy)


def draped_vine(state):
    """One frame: 0 whole, 1 gnawed, 2 fraying (the bite is at GNAW)."""
    grid = {}
    for by in range(VH):
        for bx in range(VW):
            x, y = bx + ORIGIN[0], by + ORIGIN[1]
            best = min(_segment_distance(x + 0.5, y + 0.5, PATH[i], PATH[i + 1]) for i in range(len(PATH) - 1))
            d, (ox, oy) = best
            if d <= 0.75:
                lit = (-ox - oy) > 0          # the side toward the light, up and to the left
                grid[(x, y)] = 'v' if lit else 'V'
                if lit and (x * 3 + y * 5) % 11 == 0:
                    grid[(x, y)] = 'u'
            elif d <= 1.75:
                grid[(x, y)] = 'a'
    # The bite, worked by the mice on either side of it.
    if state >= 1:
        grid[(GNAW, -4)] = None
        grid[(GNAW - 1, -3)] = 'f'
        grid[(GNAW, -3)] = 'f'
    if state >= 2:
        grid[(GNAW - 1, -4)] = None
        grid[(GNAW - 1, -3)] = None
        grid[(GNAW, -3)] = None
        grid[(GNAW - 1, -2)] = 'f'
        grid[(GNAW, -2)] = 'f'
    # Leaves down the face, alternating sides, and two standing up on the grass.
    for i, y in enumerate(range(20, GRIP[1] - 6, 11)):
        stem = round(_path_x(y + 1))          # the left core column there
        for r, row in enumerate(LEAF_LEFT):
            for dx, ch in row:
                x = stem - 2 + dx if i % 2 == 0 else stem + 1 - dx
                grid.setdefault((x, y + r), ch)
    for x, y, ch in TWIG:
        grid[(x, y)] = ch
    for x0 in (-26, -9):
        for r, row in enumerate(LEAF_UP):
            for dx, ch in row:
                grid.setdefault((x0 + dx, -7 + r), ch)
    # The root knot, sitting on the soil at the vine's far end, and its roots
    # going down into the ground.
    for r, row in enumerate(ROOT_KNOT):
        for c, ch in enumerate(row):
            if ch != '.':
                grid[(-40 + c, -5 + r)] = ch
    for root in ROOTS:
        for x, y in root:
            grid[(x, y)] = 'R'
    im = Image.new('RGBA', (VW, VH), (0, 0, 0, 0))
    for (x, y), ch in grid.items():
        bx, by = x - ORIGIN[0], y - ORIGIN[1]
        if ch and 0 <= bx < VW and 0 <= by < VH:
            c = PAL[ch]
            im.putpixel((bx, by), (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255))
    return im


def vine_frame(bite, droop=0):
    rows = list(ROOT_ROWS) + list(bite)
    body = []
    side = 0
    for i in range(72 - len(rows)):
        if i % 9 == 3:
            leaf = LEAF_L if side % 2 == 0 else LEAF_R
            body.extend(leaf)
            side += 1
        elif len(body) < 72 - len(rows):
            body.append(PLAIN if (i // 9) % 2 == 0 else PLAIN2)
        if len(body) >= 72 - len(rows):
            break
    rows += body[:72 - len(rows)]
    while len(rows) < 72:
        rows.append(PLAIN)
    return rows


MICE = {
    # black mouse, gnawing: head down, head up, head down with teeth on the vine
    'black': [
        [".........",
         "...aa....",
         ".aakkaa..",
         "akKkkkea.",
         "akkkkkkpa",
         ".aaaaaaa."],
        [".........",
         "..aa.....",
         ".akkaaa..",
         "akKkkkeaa",
         "akkkkkkkp",
         ".aaaaaaa."],
        ["...aa....",
         ".aakkaaa.",
         "akKkkkkea",
         "akkkkkkpa",
         "akkkkkaa.",
         ".aaaaa..."],
    ],
    'white': [
        [".........",
         "...aa....",
         ".aawpaa..",
         "awWwwwEa.",
         "awwwwwwpa",
         ".aaaaaaa."],
        [".........",
         "..aa.....",
         ".awpaaa..",
         "awWwwwEaa",
         "awwwwwwwp",
         ".aaaaaaa."],
        ["...aa....",
         ".aawpaaa.",
         "awWwwwwEa",
         "awwwwwwpa",
         "awwwwwaa.",
         ".aaaaa..."],
    ],
}
TAIL = "p"  # each mouse trails a tail off its left side, added below

LEMON = [
    # on its sprig
    ["....ag....",
     "...aga....",
     "..aagaal..",
     ".ayYYyaLa.",
     "ayYyyyya..",
     "ayyyyyyoa.",
     "ayyyyyyoa.",
     ".ayyyyoa..",
     "..aaaaa...",
     ".........."],
    # one bite
    ["..........",
     "..........",
     "...aaal...",
     ".ayYYa....",
     "ayYyya....",
     "ayyyya....",
     "ayyyyyyoa.",
     ".ayyyyoa..",
     "..aaaaa...",
     ".........."],
    # two bites
    ["..........",
     "..........",
     "..........",
     "..........",
     "..aa......",
     ".ayya.....",
     "ayyya.....",
     ".ayyya....",
     "..aaa.....",
     ".........."],
    # the last of it
    ["..........",
     "..........",
     "..........",
     "..........",
     "..........",
     "..........",
     "..aa......",
     ".ayya.....",
     "..aa......",
     ".........."],
]


def paint(rows):
    w = len(rows[0])
    assert all(len(r) == w for r in rows), [len(r) for r in rows]
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.':
                c = PAL[ch]
                im.putpixel((x, y), (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255))
    return im


def strip(frames):
    ims = [paint(f) for f in frames]
    w, h = ims[0].size
    out = Image.new('RGBA', (w * len(ims), h), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        out.alpha_composite(im, (i * w, 0))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    frames = [draped_vine(state) for state in range(3)]
    vine = Image.new('RGBA', (VW * 3, VH), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        vine.alpha_composite(im, (i * VW, 0))
    vine.save(OUT / 'vine.png')
    mice = Image.new('RGBA', (9 * 3, 6 * 2), (0, 0, 0, 0))
    for row, name in enumerate(['black', 'white']):
        mice.alpha_composite(strip(MICE[name]), (0, row * 6))
    mice.save(OUT / 'mice.png')
    strip(LEMON).save(OUT / 'lemon.png')
    print('vine scene props written to', OUT)


if __name__ == '__main__':
    main()
