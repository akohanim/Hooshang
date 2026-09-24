#!/usr/bin/env python3
"""Generates the five musical-note tiles -> assets/notes/note_1..5.png

Regenerates the existing beveled 16x16 pads, with a numbered upper-left
corner and a smaller musical glyph in the lower-right. The world uses an 8px
grid; each entity spans two cells. Godot's individual textures and LDtk's
shared strip are generated together so both editors show identical artwork.

Run from the repo root:  python3 tools/gen_note_tiles.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "notes")
SIZE = 16

# (name, base, rim/highlight) — five clearly distinct hues that stay readable
# once the level's CanvasModulate darkens them.
COLORS = [
    ("1", (196, 62, 62), (255, 138, 128)),    # red
    ("2", (214, 132, 42), (255, 198, 110)),   # amber
    ("3", (86, 170, 78), (166, 240, 150)),    # green
    ("4", (62, 128, 208), (140, 200, 255)),   # blue
    ("5", (150, 88, 200), (214, 160, 255)),   # violet
]

# Eighth note, drawn as (x, y) pixels on the 16x16 pad.
NOTE_PIXELS = [
    # stem
    (9, 4), (9, 5), (9, 6), (9, 7), (9, 8), (9, 9), (9, 10),
    # flag
    (10, 4), (11, 5), (11, 6), (10, 7),
    # note head
    (6, 9), (7, 9), (8, 9),
    (5, 10), (6, 10), (7, 10), (8, 10),
    (5, 11), (6, 11), (7, 11), (8, 11),
    (6, 12), (7, 12), (8, 12),
]


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


DIGITS = {
    "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"],
    "3": ["110", "001", "010", "001", "110"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "110", "001", "110"],
}


def build(number, base, rim):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for y in range(SIZE):
        # subtle top-to-bottom gradient so the pad isn't a flat block
        f = 1.06 - (y / SIZE) * 0.32
        for x in range(SIZE):
            px[x, y] = shade(base, f) + (255,)
    # dark outer border
    edge = shade(base, 0.42) + (255,)
    for i in range(SIZE):
        px[i, 0] = px[i, SIZE - 1] = px[0, i] = px[SIZE - 1, i] = edge
    # lit inner rim along the top/left, so it reads as a raised pad
    for i in range(1, SIZE - 1):
        px[i, 1] = rim + (255,)
        px[1, i] = shade(rim, 0.8) + (255,)
    # Quantize the original glyph to 80% on the native pixel grid: its 7x9
    # footprint becomes 6x7, with no filtered/half-transparent edge pixels.
    music = {(8 + round((x - 5) * .8), 7 + round((y - 4) * .8))
             for x, y in NOTE_PIXELS}
    digit = {(3 + x, 3 + y) for y, row in enumerate(DIGITS[number])
             for x, bit in enumerate(row) if bit == "1"}
    marks = music | digit
    for x, y in marks:
        px[x + 1, y + 1] = shade(base, .3) + (255,)
    for x, y in marks:
        px[x, y] = (250, 250, 245, 255)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    strip = Image.new("RGBA", (SIZE * 5, SIZE))
    for i, (name, base, rim) in enumerate(COLORS):
        img = build(name, base, rim)
        strip.paste(img, (i * SIZE, 0))
        path = os.path.join(OUT, "note_%s.png" % name)
        img.save(path)
        print("wrote", os.path.relpath(path, ROOT))

    strip.save(os.path.join(ROOT, "ldtk", "art", "note_strip.png"))
    print("wrote ldtk/art/note_strip.png")


if __name__ == "__main__":
    main()
