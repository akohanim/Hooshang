#!/usr/bin/env python3
"""Celeste-style input bubbles, drawn for 320x180: one PNG per prompt.

One sprite per prompt, not a scene of parts. Each says exactly one thing, and
a prompt that never changes has no reason to be assembled at runtime out of a
frame, a label and two glyphs.

DRAWN, not downscaled from any reference. A bubble this size gets 30 rows, so
the word has to be a 3x5 hand-set font and the badge glyph has to be about
seven pixels across. There is no resampling of a larger design that survives
that — every pixel here is placed.

The tail hangs off the BOTTOM, because a prompt points down at the spot the
move is made from and sits above the player's head where it cannot cover
whatever he is being asked to cross.

THREE PROMPTS, ONE SHARED RECIPE. `prompt_dash.png` (unchanged pixel-for-pixel
from before this became a shared function) and the new `prompt_jump_key.png`/
`prompt_jump_pad.png` — the jump lesson's keyboard and controller art, swapped
at runtime by JumpTutorial off InputDevice's last-seen input kind. Jump needs
two versions where dash needed one because a controller has no 'C' key: the
word and the arrow (straight up — jump has no direction to choose) are the
same in both, and only the badge — the little glyph saying which button —
differs.

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

# The word font. 3 columns wide, 5 rows tall, one glyph per letter used across
# every prompt so far.
FONT = {
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "J": [".##", "..#", "..#", "#.#", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "M": ["#.#", "###", "#.#", "#.#", "#.#"],
    "P": ["##.", "#.#", "##.", "#..", "#.."],
}

# Bold badge-glyphs for the keys/buttons that aren't drawn as raw lines below
# (dash's X is — kept exactly as it was rather than rebuilt from a bitmap, so
# that image does not shift by a pixel). 5 wide, 5 tall: bigger than the word
# font because the badge is the one thing in the bubble a player has to read
# at a glance.
BADGES = {
    "C": [".###.", "#....", "#....", "#....", ".###."],
    "A": ["..#..", ".#.#.", "#####", "#...#", "#...#"],
}


def new_canvas():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    return img, img.load()


def put_fn(px):
    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = c
    return put


def draw_box_and_tail(put):
    # The box, with the corners knocked off so it reads as rounded.
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

    # The tail, pointing down at the spot.
    for r in range(TAIL_H):
        half = TAIL_H - r - 1
        for x in range(W // 2 - half, W // 2 + half + 1):
            put(x, BOX_H + r, FILL)
        put(W // 2 - half, BOX_H + r, EDGE)
        put(W // 2 + half, BOX_H + r, EDGE)
    # The box edge under the tail's mouth has to go, or the bubble reads as a
    # box with a triangle stuck to it rather than as one shape.
    for x in range(W // 2 - TAIL_H + 1, W // 2 + TAIL_H):
        put(x, BOX_H - 1, FILL)


def draw_word(put, word):
    ww = len(word) * 4 - 1
    ox = (W - ww) // 2
    for i, ch in enumerate(word):
        for r, line in enumerate(FONT[ch]):
            for c, bit in enumerate(line):
                if bit == "#":
                    put(ox + i * 4 + c, 4 + r, WORD)


def draw_diagonal_arrow(put):
    # A shaft up-right with a head on it — hold this way and dash.
    ax, ay = 9, 13
    for i in range(6):
        put(ax + i, ay + 5 - i, INK)
        put(ax + i + 1, ay + 5 - i, INK)
    for i in range(4):
        put(ax + 5 - i, ay, INK)
        put(ax + 5, ay + i, INK)


def draw_up_arrow(put):
    # A straight shaft with a chevron head, tip at the TOP — jump has one
    # direction, not a held diagonal, so the plus-and-key reads "press", not
    # "hold and press".
    ax, ay = 12, 19
    for i in range(5):                  # shaft, bottom at ay, top at ay-4
        put(ax, ay - i, INK)
        put(ax + 1, ay - i, INK)
    for i in range(3):                  # head: wide beside the shaft (i=0),
        offset = 2 - i                  # narrowing to a point above it (i=2)
        y = ay - 5 - i
        put(ax - offset, y, INK)
        put(ax + 1 + offset, y, INK)


def draw_plus(put):
    for i in range(3):
        put(19 + i, 17, WORD)
        put(20, 16 + i, WORD)


def draw_badge_x(put):
    # The key: a white disc with the letter knocked out of it. Dash's badge
    # is drawn as two literal crossing diagonals rather than through BADGES —
    # kept that way so this image stays pixel-identical to the original.
    kx, ky, kr = 31, 17, 4
    for y in range(-kr, kr + 1):
        for x in range(-kr, kr + 1):
            # +1 rounds the disc out at the cardinals; a bare r^2 test leaves
            # it lumpy at nine pixels across and it reads as a cog.
            if x * x + y * y <= kr * kr + 1:
                put(kx + x, ky + y, KEY_BG)
    for i in range(-2, 3):
        put(kx + i, ky + i, KEY_INK)
        put(kx + i, ky - i, KEY_INK)


def draw_badge_glyph(put, letter, kx, ky, kr):
    # A white disc with one of BADGES stamped into it — the keyboard/
    # controller variants, where the letter is an actual shape rather than
    # two lines and needs a bitmap to say so. Position and size are given
    # rather than fixed, because dash's badge shares the box with an arrow
    # and jump's does not (see below) — one sits off to the side, the other
    # gets to be bigger and centred.
    for y in range(-kr, kr + 1):
        for x in range(-kr, kr + 1):
            if x * x + y * y <= kr * kr + 1:
                put(kx + x, ky + y, KEY_BG)
    glyph = BADGES[letter]
    gh, gw = len(glyph), len(glyph[0])
    for r, row in enumerate(glyph):
        for c, bit in enumerate(row):
            if bit == "#":
                put(kx - gw // 2 + c, ky - gh // 2 + r, KEY_INK)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    img.save(path)
    print("wrote %s  %dx%d" % (path, img.width, img.height))


# ---- prompt_dash.png: hold up-and-forward, press X -------------------------
img, px = new_canvas()
put = put_fn(px)
draw_box_and_tail(put)
draw_word(put, "DASH")
draw_diagonal_arrow(put)
draw_plus(put)
draw_badge_x(put)
save(img, "prompt_dash.png")

# ---- prompt_jump_key.png / prompt_jump_pad.png: press C / press A ----------
#
# NO ARROW. Dash needs one because the move is a held DIRECTION as much as a
# button; jump is not held anywhere, it is just pressed, so an arrow here was
# only ever pointing at the one axis a player is already standing on. Cutting
# it hands the space back to the one thing that matters — the badge — which
# gets to be bigger and dead centre instead of sharing the box with a glyph
# that was not pulling its weight.
for letter, name in (("C", "prompt_jump_key.png"), ("A", "prompt_jump_pad.png")):
    img, px = new_canvas()
    put = put_fn(px)
    draw_box_and_tail(put)
    draw_word(put, "JUMP")
    draw_badge_glyph(put, letter, W // 2, 16, 6)
    save(img, name)
