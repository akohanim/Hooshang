#!/usr/bin/env python3
"""Death-burst shards: three 8x8 tiles on one 24x8 sheet.

What Hooshang comes apart into. Three shapes rather than one — a diamond, a
square and a splinter — because a ring of ten identical dots reads as a UI
effect, and a ring of mixed debris reads as something breaking.

Each is drawn with a bright core and a darker rim so it still has form at the
1-2px sizes these end up at after the burst shrinks them, and in white so the
burst can be tinted per Act from a single export.

Re-run after editing: python3 tools/gen_death_shards.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "effects")
CELL = 8
SHAPES = 3

CORE = (255, 255, 255, 255)
RIM = (206, 216, 232, 255)

img = Image.new("RGBA", (CELL * SHAPES, CELL), (0, 0, 0, 0))
px = img.load()


def put(x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        px[x, y] = c


def diamond(ox):
    """Four-point shard: the one that reads as glass."""
    cx = cy = 3.5
    for y in range(CELL):
        for x in range(CELL):
            d = abs(x - cx) + abs(y - cy)
            if d <= 2.0:
                put(ox + x, y, CORE)
            elif d <= 3.5:
                put(ox + x, y, RIM)


def block(ox):
    """A chunk. Kept off-centre so a spinning one is not symmetrical."""
    for y in range(2, 6):
        for x in range(2, 7):
            put(ox + x, y, CORE if 3 <= x <= 5 and 3 <= y <= 4 else RIM)


def splinter(ox):
    """A long sliver, for the ones that fly furthest."""
    for x in range(1, 7):
        put(ox + x, 4, RIM if x in (1, 6) else CORE)
    for x in range(2, 6):
        put(ox + x, 3, RIM)


for i, draw in enumerate((diamond, block, splinter)):
    draw(i * CELL)

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, "death_shard.png")
img.save(path)
print("wrote %s  %dx%d" % (path, img.width, img.height))
