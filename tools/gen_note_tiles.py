#!/usr/bin/env python3
"""Generates the five musical-note tiles -> assets/notes/note_1..5.png

PLACEHOLDER ART. These were meant to come from Pixellab, but its MCP server
was unavailable, so they're drawn procedurally here. They are deliberately
simple and regenerable: swap in Pixellab output at the same paths/size and
nothing else needs to change.

One tile = one game cell = 16x16 px (the LDtk grid). Each is a coloured pad
with a lit rim and an eighth-note glyph, sized to read against the dark Act I
palette. Colours ascend the same way the pitches do (see gen_note_audio.py).

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


def build(base, rim):
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
    # note glyph, with a 1px dark drop shadow for contrast on any hue
    for (x, y) in NOTE_PIXELS:
        if 0 <= x + 1 < SIZE and 0 <= y + 1 < SIZE:
            px[x + 1, y + 1] = shade(base, 0.3) + (255,)
    for (x, y) in NOTE_PIXELS:
        px[x, y] = (250, 250, 245, 255)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, base, rim in COLORS:
        img = build(base, rim)
        path = os.path.join(OUT, "note_%s.png" % name)
        img.save(path)
        print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
