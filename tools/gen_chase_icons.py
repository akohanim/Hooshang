#!/usr/bin/env python3
"""Editor icons for the Darkshang chase entities.

Writes three 16x16 tiles into ldtk/art/ — one per entity definition, so the
chase reads at a glance in the LDtk world view next to the spikes and belts:

    darkshang_spawn.png   where he appears: a hooded figure, eyes lit
    surge_point.png       where he lunges: a double chevron with speed streaks
    safe_zone.png         where the chase ends: a lit doorway

These are EDITOR art. The game never loads them (the importer's
`use_entity_placeholders` is off) — they exist so a level author can tell the
three apart on the LDtk canvas, which is the same job `note_strip.png` and
`conveyor_belt_*.png` do.

House style follows tools/gen_glass_spikes.py: fixed pixel positions so a
re-run is byte-identical, one light in the upper left, and soft shading via an
ordered (Bayer) dither between palette steps rather than flat retro fills — the
project's art direction is detailed pixel art, NOT 8-bit.

Re-run after editing: python3 tools/gen_chase_icons.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ldtk", "art")
SIZE = 16

# Ordered dither matrix. Shading picks between two neighbouring palette steps
# per pixel, so a 16px icon gets a gradient without needing 30 colours.
BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]

# The light, in pixel coordinates: upper left, same as the glass spikes.
LIGHT = (3.0, 2.0)


def ramp(colors, t, x, y):
    """Colour `t` (0 = darkest step, 1 = lightest) along `colors`, dithered."""
    t = min(max(t, 0.0), 1.0)
    f = t * (len(colors) - 1)
    i = int(f)
    if i >= len(colors) - 1:
        return colors[-1]
    threshold = (BAYER[y % 4][x % 4] + 0.5) / 16.0
    return colors[i + 1] if (f - i) > threshold else colors[i]


class Icon:
    """A 16x16 canvas with the passes every one of these icons wants."""

    def __init__(self):
        self.img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        self.px = self.img.load()

    def put(self, x, y, c):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.px[x, y] = c

    def glow(self, cx, cy, radius, color, strength=110):
        """Soft halo UNDER the subject, so the icon holds together against
        LDtk's grey canvas instead of floating as loose pixels."""
        r, g, b = color
        for y in range(SIZE):
            for x in range(SIZE):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                a = int(strength * max(0.0, 1.0 - d / radius) ** 2)
                if a > 0 and self.px[x, y][3] == 0:
                    self.put(x, y, (r, g, b, a))

    def shade(self, mask, colors, light=LIGHT, falloff=13.0):
        """Fill `mask` (a set of (x, y)) lit from `light`, dark end first."""
        lx, ly = light
        for (x, y) in sorted(mask):
            d = ((x - lx) ** 2 + (y - ly) ** 2) ** 0.5
            self.put(x, y, ramp(colors, 1.0 - d / falloff, x, y))

    def outline(self, mask, color):
        """Dark lip around the shape — what stops a 16px sprite dissolving
        into whatever is behind it."""
        for (x, y) in sorted(mask):
            for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in mask:
                    self.put(x, y, color)
                    break

    def save(self, name):
        self.img.save(os.path.join(OUT, name))
        print("wrote %s  %dx%d" % (name, SIZE, SIZE))


# --------------------------------------------------------------------------
# DarkshangSpawn — the hooded double of Hooshang, one step behind you.
# --------------------------------------------------------------------------
# Body silhouette. Deliberately hunched and narrow-shouldered: he is Hooshang,
# not a monster, and at 16px the read comes entirely from the posture.
FIGURE = [
    "................",
    ".......bb.......",
    "......bbbb......",
    "......bbbb......",   # eyes are punched in after shading
    "......bbbb......",
    ".....bbbbbb.....",
    "....bbbbbbbb....",
    "...bbbbbbbbbb...",
    "...bbbbbbbbbb...",
    "...bbbbbbbbbb...",
    "....bbbbbbbb....",
    ".....bbbbbb.....",
    ".....bb..bb.....",
    ".....bb..bb.....",
    "....bbb..bbb....",
    "................",
]
VIOLET = [(16, 9, 24, 255), (26, 15, 38, 255), (38, 22, 54, 255),
          (50, 29, 70, 255), (63, 36, 90, 255), (78, 46, 110, 255),
          (95, 57, 133, 255), (114, 71, 158, 255), (134, 88, 182, 255)]
EYE = (226, 196, 255, 255)
EYE_CORE = (255, 255, 255, 255)


def darkshang_spawn():
    icon = Icon()
    icon.glow(8, 8, 9.0, (123, 60, 200), 96)
    mask = {(x, y) for y, row in enumerate(FIGURE)
            for x, ch in enumerate(row) if ch == "b"}
    icon.shade(mask, VIOLET, falloff=22.0)
    icon.outline(mask, VIOLET[0])
    # Eyes last: the one thing on him that is brighter than the room.
    for x in (6, 9):
        icon.put(x, 4, EYE_CORE if x == 6 else EYE)
        icon.put(x, 5, VIOLET[3])
    icon.save("darkshang_spawn.png")


# --------------------------------------------------------------------------
# SurgePoint — where he closes the gap. A double chevron, aimed the way the
# room runs (left to right), with the streaks trailing behind it.
# --------------------------------------------------------------------------
FIRE = [(58, 12, 8, 255), (120, 28, 14, 255), (194, 66, 22, 255),
        (238, 126, 40, 255), (255, 196, 96, 255), (255, 246, 214, 255)]
STREAK = [(96, 26, 14, 255), (170, 58, 22, 255), (226, 108, 36, 255)]


def surge_point():
    """Chevrons pointing LEFT, with the motion trail off their right edge.

    The chase runs right to left — Hooshang is retracing his steps back to his
    own cubicle — so an icon pointing the other way tells the designer placing
    it the opposite of the truth about which way the lunge goes.
    """
    icon = Icon()
    icon.glow(SIZE - 1 - 9, 8, 9.5, (255, 110, 40), 92)
    mask = set()
    for apex in (8, 13):
        for dy in range(-5, 6):
            x0 = apex - abs(dy)
            for t in range(3):
                mask.add((SIZE - 1 - (x0 + t), 8 + dy))
    mask = {(x, y) for (x, y) in mask if 0 <= x < SIZE and 0 <= y < SIZE}
    icon.shade(mask, FIRE, falloff=17.0)
    icon.outline(mask, FIRE[0])
    # Motion trailing off the back edge — now the RIGHT edge, since he travels
    # left. Three fixed rows, brightest at the centre, so the chevrons read as
    # travelling rather than as arrows.
    for (y, run, shade) in ((5, 3, 0), (8, 5, 2), (11, 3, 0)):
        for x in range(run):
            px = SIZE - 1 - x
            if (px, y) not in mask:
                icon.put(px, y, STREAK[shade if x < run - 1 else min(shade + 1, 2)])
    icon.save("surge_point.png")


# --------------------------------------------------------------------------
# SafeZone — the cubicle he is running for. A lit doorway: frame, warm inside.
# --------------------------------------------------------------------------
TEAL = [(6, 38, 40, 255), (9, 52, 54, 255), (12, 66, 68, 255),
        (15, 85, 85, 255), (18, 104, 102, 255), (23, 126, 120, 255),
        (28, 150, 140, 255), (37, 174, 158, 255), (48, 200, 178, 255)]
INSIDE = [(24, 62, 60, 255), (29, 79, 74, 255), (34, 96, 88, 255),
          (43, 117, 104, 255), (52, 138, 120, 255), (73, 163, 140, 255),
          (96, 188, 160, 255), (132, 210, 184, 255), (170, 232, 208, 255)]
FLOOR = (10, 52, 54, 255)


def safe_zone():
    icon = Icon()
    icon.glow(8, 9, 10.0, (30, 200, 176), 88)
    frame, inside = set(), set()
    for y in range(SIZE):
        for x in range(SIZE):
            if y > 13:
                continue
            d = ((x - 7.5) / 6.4) ** 2 + ((y - 13.0) / 11.0) ** 2
            if d <= 1.0:
                (frame if d > 0.62 else inside).add((x, y))
    icon.shade(inside, INSIDE, light=(6.0, 6.0), falloff=12.0)
    icon.shade(frame, TEAL, falloff=15.0)
    icon.outline(frame, TEAL[0])
    for x in range(2, 14):
        icon.put(x, 14, FLOOR)
    icon.save("safe_zone.png")


def darkshang_trigger():
    """The threshold: a vertical line with the shadow's eyes waiting behind it.

    Reads as a LINE first — that is what the designer is placing — with just
    enough of him on the far side to say what crossing it summons. Purple, the
    same as DarkshangSpawn, because the two entities are halves of one event.
    """
    icon = Icon()
    icon.glow(11, 8, 8.0, (155, 77, 255), 70)
    # The line itself, down the left third, brightest in the middle.
    mask = {(4, y) for y in range(1, 15)} | {(5, y) for y in range(1, 15)}
    icon.shade(mask, VIOLET, falloff=15.0)
    icon.outline(mask, VIOLET[0])
    for y in (0, 15):
        icon.put(4, y, VIOLET[2])
        icon.put(5, y, VIOLET[2])
    # A hint of him beyond it: shoulders and two eyes, cut off by the frame so
    # he reads as still arriving rather than as standing there posed.
    body = set()
    for y in range(6, 15):
        half = 3 if y < 8 else 4
        for x in range(11 - half, min(11 + half + 1, SIZE)):
            body.add((x, y))
    icon.shade(body, VIOLET, falloff=13.0)
    icon.outline(body, VIOLET[0])
    for x in (9, 10, 12, 13):
        icon.put(x, 8, EYE_CORE if x in (10, 12) else EYE)
    icon.save("darkshang_trigger.png")


if __name__ == "__main__":
    darkshang_spawn()
    surge_point()
    darkshang_trigger()
    safe_zone()
