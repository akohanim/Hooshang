#!/usr/bin/env python3
"""The dash prompt: a Celeste-style input bubble, drawn for 320x180.

One sprite, not a scene of parts. It says exactly one thing — hold a diagonal
and press X — and a prompt that never changes has no reason to be assembled at
runtime out of a frame, a label and two glyphs.

DRAWN, not downscaled from the reference. The reference shot is a bubble roughly
220px wide in a game with far more than 180 scanlines; at our height the whole
thing gets 30 rows, so the word has to be a 3x5 hand-set font and the key glyph
has to be nine pixels across. There is no resampling of a larger design that
survives that — every pixel here is placed.

The tail hangs off the BOTTOM, because the prompt points down at the spot the
move is made from and sits above the player's head where it cannot cover the
gap he is being asked to cross.

Re-run after editing: python3 tools/gen_input_prompt.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui")

W, BOX_H, TAIL_H = 46, 24, 5
H = BOX_H + TAIL_H

FILL = (24, 30, 48, 235)
EDGE = (206, 222, 245, 255)
WORD = (150, 168, 232, 255)
INK = (255, 255, 255, 255)
KEY_BG = (255, 255, 255, 255)
KEY_INK = (24, 30, 48, 255)

FONT = {
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
}

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c


# ---- the box, with the corners knocked off so it reads as rounded ----------
for y in range(BOX_H):
    for x in range(W):
        corner = (x < 2 and y < 2) or (x >= W - 2 and y < 2) \
            or (x < 2 and y >= BOX_H - 2) or (x >= W - 2 and y >= BOX_H - 2)
        if corner and (x in (0, W - 1)) and (y in (0, BOX_H - 1)):
            continue
        put(x, y, FILL)
for x in range(1, W - 1):
    put(x, 0, EDGE)
    put(x, BOX_H - 1, EDGE)
for y in range(1, BOX_H - 1):
    put(0, y, EDGE)
    put(W - 1, y, EDGE)

# ---- the word -------------------------------------------------------------
word = "DASH"
ww = len(word) * 4 - 1
ox = (W - ww) // 2
for i, ch in enumerate(word):
    for r, line in enumerate(FONT[ch]):
        for c, bit in enumerate(line):
            if bit == "#":
                put(ox + i * 4 + c, 4 + r, WORD)

# ---- the diagonal arrow: a shaft up-right with a head on it ----------------
AX, AY = 9, 13
for i in range(6):                      # shaft, bottom-left to top-right
    put(AX + i, AY + 5 - i, INK)
    put(AX + i + 1, AY + 5 - i, INK)
for i in range(4):                      # head, two edges off the tip
    put(AX + 5 - i, AY, INK)
    put(AX + 5, AY + i, INK)

# ---- the plus -------------------------------------------------------------
for i in range(3):
    put(19 + i, 17, WORD)
    put(20, 16 + i, WORD)

# ---- the key: a white disc with the letter knocked out of it --------------
KX, KY, KR = 31, 17, 4
for y in range(-KR, KR + 1):
    for x in range(-KR, KR + 1):
        # +1 rounds the disc out at the cardinals; a bare r^2 test leaves it
        # lumpy at nine pixels across and it reads as a cog, not a key.
        if x * x + y * y <= KR * KR + 1:
            put(KX + x, KY + y, KEY_BG)
for i in range(-2, 3):                  # the X itself
    put(KX + i, KY + i, KEY_INK)
    put(KX + i, KY - i, KEY_INK)

# ---- the tail, pointing down at the spot ----------------------------------
for r in range(TAIL_H):
    half = TAIL_H - r - 1
    for x in range(W // 2 - half, W // 2 + half + 1):
        put(x, BOX_H + r, FILL)
    put(W // 2 - half, BOX_H + r, EDGE)
    put(W // 2 + half, BOX_H + r, EDGE)
# The box edge under the tail's mouth has to go, or the bubble reads as a box
# with a triangle stuck to it rather than as one shape.
for x in range(W // 2 - TAIL_H + 1, W // 2 + TAIL_H):
    put(x, BOX_H - 1, FILL)

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, "prompt_dash.png")
img.save(path)
print("wrote %s  %dx%d" % (path, img.width, img.height))
