#!/usr/bin/env python3
"""The "+1000" that pops off a lemon: neon pixel digits with a glow and sparks.

Drawn at GAME resolution — 48x17, so it is about a seventh of the 320px screen
— and blown up 4x by the HUD layer it lives on, with nearest filtering. That
layer is authored at 1280x720 and can carry fine art (the counter's lemon uses
the dense frame, the dialogue box gets real type), but this is not fine art: the
reference is chunky neon pixel numerals, and drawing them at 4x would smooth
them into something that belongs to the UI rather than to the game.

ELEVEN GLYPHS, on a sheet the popup composes at runtime: 0-9 and a plus. It was
three — a plus, a one and a zero, enough to spell "+1000" — and that was right
while a lemon was the only thing that awarded anything. It is wrong the moment a
second award is worth a different number, because a fixed picture of "+1000"
over a 500-point pickup is a lie the code cannot even see it is telling.

Each glyph gets its own cell WITH its glow margin, and the popup lays them out
one stroke-width apart so the halos overlap the way they would in one drawing.

FOUR PASSES, and the order is what makes it read as neon rather than as green
text:

  1. the GLOW — the glyph mask blurred and tinted, laid down first so everything
     else sits on top of it
  2. the OUTLINE — dark green, one pixel around every glyph, which is what stops
     the fill dissolving into its own glow
  3. the RIM — a pale edge one pixel inside the glyph, all the way round
  4. the FILL — bright yellow-green, everything the rim did not take

Dark outside, pale edge, green middle. That order is the whole look, and it is
why the strokes have to be three pixels: two leaves no middle.

...then sparks: small four-pointed stars scattered around it, at hand-placed
positions rather than random ones, so re-running the tool cannot quietly produce
a different picture.

Usage:  python3 tools/gen_points_popup.py
"""
import os

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/ui")

## Glyph cell, and the gap between them. NINE by eleven with three-pixel
## strokes, and the thickness is the point: the reference's numerals are a dark
## outline, a pale inner edge and a green fill, which needs a stroke wide enough
## to hold all three. At 7x9 with two-pixel strokes every pixel was an edge, so
## the rim ate the fill and the digits came out as hollow rings.
GW, GH, GAP = 9, 11, 1
MARGIN = 4

OUTLINE = (44, 92, 18, 255)
FILL = (150, 224, 46, 255)
RIM = (232, 255, 150, 255)
GLOW = (150, 226, 40)
SPARK = (250, 255, 190, 255)

## 1 = stroke, 0 = empty. Seven wide and nine tall: thick enough that the rim
## and the outline both fit inside a stroke without closing it up.
GLYPHS = {
    "+": [
        "000000000",
        "000000000",
        "000111000",
        "000111000",
        "011111110",
        "011111110",
        "011111110",
        "000111000",
        "000111000",
        "000000000",
        "000000000",
    ],
    "0": [
        "001111100",
        "011111110",
        "111000111",
        "111000111",
        "111000111",
        "111000111",
        "111000111",
        "111000111",
        "111000111",
        "011111110",
        "001111100",
    ],
    "1": [
        "000111000",
        "001111000",
        "011111000",
        "000111000",
        "000111000",
        "000111000",
        "000111000",
        "000111000",
        "000111000",
        "001111100",
        "001111100",
    ],
    "2": [
        "001111100",
        "011111110",
        "111000111",
        "000000111",
        "000001110",
        "000011100",
        "000111000",
        "001110000",
        "011100000",
        "111111111",
        "111111111",
    ],
    "3": [
        "011111110",
        "111111111",
        "000000111",
        "000000111",
        "000111110",
        "000111110",
        "000000111",
        "000000111",
        "111000111",
        "111111110",
        "011111100",
    ],
    "4": [
        "000011110",
        "000111110",
        "001110110",
        "011100110",
        "111000110",
        "111111111",
        "111111111",
        "000000110",
        "000000110",
        "000000110",
        "000000110",
    ],
    "5": [
        "111111111",
        "111111111",
        "111000000",
        "111000000",
        "111111100",
        "011111110",
        "000000111",
        "000000111",
        "111000111",
        "111111110",
        "011111100",
    ],
    "6": [
        "001111100",
        "011111110",
        "111000000",
        "111000000",
        "111111100",
        "111111110",
        "111000111",
        "111000111",
        "111000111",
        "011111110",
        "001111100",
    ],
    "7": [
        "111111111",
        "111111111",
        "000000111",
        "000001110",
        "000011100",
        "000111000",
        "000111000",
        "000111000",
        "000111000",
        "000111000",
        "000111000",
    ],
    "8": [
        "001111100",
        "011111110",
        "111000111",
        "111000111",
        "011111110",
        "011111110",
        "111000111",
        "111000111",
        "111000111",
        "011111110",
        "001111100",
    ],
    "9": [
        "001111100",
        "011111110",
        "111000111",
        "111000111",
        "111000111",
        "011111111",
        "001111111",
        "000000111",
        "000000111",
        "011111110",
        "001111100",
    ],
}

## The order they sit on the sheet. The popup indexes by this, so do not reorder.
ORDER = "+0123456789"

def draw_glyph(rows):
    """One glyph in its own cell, glow margin included."""
    w, h = GW + MARGIN * 2, GH + MARGIN * 2
    on = set()
    for y, row in enumerate(rows):
        for x, bit in enumerate(row):
            if bit == "1":
                on.add((MARGIN + x, MARGIN + y))

    # 1. the glow: the mask, blurred, tinted.
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for x, y in on:
        px[x, y] = GLOW + (255,)
    img = img.filter(ImageFilter.GaussianBlur(2.2))
    px = img.load()
    for x in range(w):
        for y in range(h):
            a = px[x, y][3]
            # Blur dims the colour as well as the alpha; put the colour back and
            # keep only the falloff, or the halo comes out grey.
            px[x, y] = GLOW + (min(255, int(a * 1.7)),)

    # 2. the outline, one pixel around every stroke.
    for x, y in on:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if n not in on and 0 <= n[0] < w and 0 <= n[1] < h:
                    px[n] = OUTLINE

    # 3. the rim and 4. the fill — one pass, because the same test decides
    # which a pixel gets. A stroke pixel with all four neighbours inside the
    # glyph is interior and takes the fill; anything on the edge takes the pale
    # rim, which is the tube catching light.
    for x, y in on:
        edge = any((x + dx, y + dy) not in on
                   for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)))
        px[x, y] = RIM if edge else FILL
    return img


def spark():
    """One four-pointed star, for the popup to scatter around a tag."""
    img = Image.new("RGBA", (5, 5), (0, 0, 0, 0))
    px = img.load()
    px[2, 2] = SPARK
    for d in (1, 2):
        for x, y in ((2 - d, 2), (2 + d, 2), (2, 2 - d), (2, 2 + d)):
            px[x, y] = SPARK[:3] + (200 if d == 1 else 90,)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    cw, ch = GW + MARGIN * 2, GH + MARGIN * 2
    sheet = Image.new("RGBA", (cw * len(ORDER), ch), (0, 0, 0, 0))
    for i, ch_ in enumerate(ORDER):
        sheet.paste(draw_glyph(GLYPHS[ch_]), (i * cw, 0))
    for name, img in (("points_digits.png", sheet), ("points_spark.png", spark())):
        path = os.path.join(OUT, name)
        img.save(path)
        print("wrote %s  (%dx%d)" % (os.path.relpath(path, ROOT), *img.size))
    print("  cell %dx%d, %d glyphs, order %r" % (cw, ch, len(ORDER), ORDER))


if __name__ == "__main__":
    main()
