#!/usr/bin/env python3
"""The mystery box: a 16px block with a "?" on it, Mario-style. Bump it from
underneath and it gives up a mushroom (see scenes/props/mystery_box.gd).

Two frames on one 32x16 sheet — IDLE (question mark, warm brass) and SPENT
(flat, dull, no mark) — the same two-state read Mario's block uses so a player
who has never seen this game still knows a used block when they see one.

Hand-drawn, not a photo cut like the platform art: at 16px there is nothing to
crop that would read as "block" rather than as noise, so every pixel here is
placed on purpose — brass bevel (soft top-left highlight, bottom-right shadow,
so it reads as "modern detailed pixel art" and not a flat retro swatch), four
corner rivets, and a 5x7 glyph with its own one-pixel drop shadow for pop.

The SPENT frame inverts the bevel (light bottom-right, dark top-left) rather
than just dimming the same art — a block that has given up its prize reads as
PRESSED IN, not merely darker, which is the same "sunken vs. proud" cue the
bevel already carries.

Re-run after editing: python3 tools/gen_mystery_box.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 16

# Brass, lit top-left. Four tones: highlight, base, shade, deep shade — enough
# for a soft bevel without flattening into two-tone retro.
BRASS_HI = (0xF2, 0xC9, 0x5A, 255)
BRASS = (0xD6, 0xA3, 0x32, 255)
BRASS_LO = (0xA8, 0x77, 0x1E, 255)
BRASS_DEEP = (0x7C, 0x54, 0x14, 255)
OUTLINE = (0x3A, 0x24, 0x0A, 255)
RIVET = (0x5E, 0x3E, 0x12, 255)
RIVET_HI = (0x8A, 0x5F, 0x22, 255)

# Spent: dull office-brick brown, well below the brass in both saturation and
# value — the block reads as used from across a dim room, not just up close.
DULL_HI = (0x8A, 0x7C, 0x68, 255)
DULL = (0x6E, 0x62, 0x51, 255)
DULL_LO = (0x54, 0x4A, 0x3C, 255)
DULL_DEEP = (0x3E, 0x36, 0x2C, 255)

# A compact 5x7 "?" — a common pixel-font shape, not traced from any real
# typeface. `.` empty, `#` ink.
GLYPH = [
    ".###.",
    "#...#",
    "....#",
    "...#.",
    "..#..",
    ".....",
    "..#..",
]
GLYPH_INK = (0xFA, 0xF3, 0xDE, 255)
GLYPH_SHADOW = (0x5A, 0x3C, 0x10, 255)


def bevel(px, hi, base, lo, deep, invert):
    """Fill the 16x16 body with a soft brass bevel: proud (default) or
    pressed-in (invert=True, the spent block)."""
    top_left, bottom_right = (deep, hi) if invert else (hi, deep)
    for y in range(CELL):
        for x in range(CELL):
            if x == 0 or y == 0:
                c = top_left
            elif x == CELL - 1 or y == CELL - 1:
                c = bottom_right
            elif x == 1 or y == 1:
                c = lo if invert else hi
            elif x == CELL - 2 or y == CELL - 2:
                c = hi if invert else lo
            else:
                # A gentle diagonal gradient across the face, base -> a touch
                # darker toward the bottom-right corner — the "soft shading"
                # the art direction asks for, not a flat fill.
                t = (x + y) / float(2 * (CELL - 5))
                c = base if t < 0.6 else lo
            px[x, y] = c
    for x in range(CELL):
        px[x, 0] = OUTLINE if not invert else OUTLINE
        px[x, CELL - 1] = OUTLINE
    for y in range(CELL):
        px[0, y] = OUTLINE
        px[CELL - 1, y] = OUTLINE


def rivets(px):
    for cx, cy in ((3, 3), (CELL - 4, 3), (3, CELL - 4), (CELL - 4, CELL - 4)):
        px[cx, cy] = RIVET
        px[cx - 1, cy] = RIVET_HI
        px[cx, cy - 1] = RIVET_HI


def glyph(px):
    ox = (CELL - len(GLYPH[0])) // 2
    oy = (CELL - len(GLYPH)) // 2
    for row, line in enumerate(GLYPH):
        for col, ch in enumerate(line):
            if ch != "#":
                continue
            x, y = ox + col, oy + row
            px[x + 1, y + 1] = GLYPH_SHADOW
    for row, line in enumerate(GLYPH):
        for col, ch in enumerate(line):
            if ch != "#":
                continue
            x, y = ox + col, oy + row
            px[x, y] = GLYPH_INK


def idle_frame():
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()
    bevel(px, BRASS_HI, BRASS, BRASS_LO, BRASS_DEEP, invert=False)
    rivets(px)
    glyph(px)
    return img


def spent_frame():
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()
    bevel(px, DULL_HI, DULL, DULL_LO, DULL_DEEP, invert=True)
    rivets(px)
    return img


idle = idle_frame()
spent = spent_frame()
sheet = Image.new("RGBA", (CELL * 2, CELL), (0, 0, 0, 0))
sheet.paste(idle, (0, 0))
sheet.paste(spent, (CELL, 0))

for folder in ("assets/props/mystery_box", "ldtk/art"):
    out_dir = os.path.join(ROOT, folder)
    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, "mystery_box.png"))
print("wrote mystery_box.png  %dx%d  (idle, spent)" % (sheet.width, sheet.height))
