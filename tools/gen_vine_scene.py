#!/usr/bin/env python3
"""The props of Act III's last scene, THE VINE (SCRIPT.md THIRTEEN): the vine
Hooshang hangs from, the black and the white mouse that gnaw at it, and the
lemon growing out of the cliff within reach of his hand.

Hand-placed pixels in the adult rig's scale and outline weight, written as
strings so a change is a change of one character. Writes, into
assets/act3/vine/:
  vine.png    3 frames of 14x72, left to right: whole, gnawed, fraying. The root
              clump is at the top; he hangs from the bottom.
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
    strip([vine_frame(WHOLE_BITE), vine_frame(GNAWED_BITE), vine_frame(FRAYING_BITE)]).save(OUT / 'vine.png')
    mice = Image.new('RGBA', (9 * 3, 6 * 2), (0, 0, 0, 0))
    for row, name in enumerate(['black', 'white']):
        mice.alpha_composite(strip(MICE[name]), (0, row * 6))
    mice.save(OUT / 'mice.png')
    strip(LEMON).save(OUT / 'lemon.png')
    print('vine scene props written to', OUT)


if __name__ == '__main__':
    main()
