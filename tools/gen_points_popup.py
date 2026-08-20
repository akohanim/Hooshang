#!/usr/bin/env python3
"""The "+1000" that pops off a lemon: neon pixel digits with a glow and sparks.

Drawn at GAME resolution — 48x17, so it is about a seventh of the 320px screen
— and blown up 4x by the HUD layer it lives on, with nearest filtering. That
layer is authored at 1280x720 and can carry fine art (the counter's lemon uses
the dense frame, the dialogue box gets real type), but this is not fine art: the
reference is chunky neon pixel numerals, and drawing them at 4x would smooth
them into something that belongs to the UI rather than to the game.

Three glyphs is the whole font. "+1000" needs a plus, a one and a zero, so this
hand-sets those and nothing else, the way tools/gen_input_prompt.py hand-sets
the five letters of "DASH". A general font would be five times the code for
glyphs nothing draws.

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
}

TEXT = "+1000"

## Four-pointed stars, at (x, y) in the finished canvas. Placed by hand: a
## random scatter re-rolls every time the tool runs, and art that changes when
## you regenerate it is art nobody can review.
SPARKS = [(7, 2), (21, 0), (32, 3), (43, 1), (52, 4),
          (12, 17), (27, 18), (40, 17), (50, 14)]
## The bigger ones get arms; the rest are single pixels.
BIG_SPARKS = {(21, 0), (32, 3), (40, 17)}


def mask():
    """Where the strokes are, as a set of (x, y)."""
    on = set()
    for i, ch in enumerate(TEXT):
        ox = MARGIN + i * (GW + GAP)
        for y, row in enumerate(GLYPHS[ch]):
            for x, bit in enumerate(row):
                if bit == "1":
                    on.add((ox + x, MARGIN + y))
    return on


def main():
    os.makedirs(OUT, exist_ok=True)
    w = MARGIN * 2 + len(TEXT) * GW + (len(TEXT) - 1) * GAP
    h = MARGIN * 2 + GH
    on = mask()

    # 1. the glow: the mask, blurred, tinted.
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gp = glow.load()
    for x, y in on:
        gp[x, y] = GLOW + (255,)
    glow = glow.filter(ImageFilter.GaussianBlur(2.2))
    gp = glow.load()
    for x in range(w):
        for y in range(h):
            r, g, b, a = gp[x, y]
            # Blur dims the colour as well as the alpha; put the colour back and
            # keep only the falloff, or the halo comes out grey.
            gp[x, y] = GLOW + (min(255, int(a * 1.7)),)

    img = glow
    px = img.load()

    # 2. the outline, one pixel around every stroke.
    for x, y in list(on):
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if n not in on and 0 <= n[0] < w and 0 <= n[1] < h:
                    px[n] = OUTLINE

    # 3. the fill, and 4. the rim — in one pass, because which a pixel gets
    # depends on the same test. A stroke pixel with all four neighbours inside
    # the glyph is interior and takes the fill; anything on the edge takes the
    # pale rim, which is the tube catching light and the single thing that says
    # "neon" rather than "bright green".
    for x, y in on:
        edge = any((x + dx, y + dy) not in on
                   for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)))
        px[x, y] = RIM if edge else FILL

    # ...and the sparks.
    for x, y in SPARKS:
        if not (0 <= x < w and 0 <= y < h):
            continue
        px[x, y] = SPARK
        if (x, y) in BIG_SPARKS:
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                n = (x + dx, y + dy)
                if 0 <= n[0] < w and 0 <= n[1] < h:
                    r, g, b, a = px[n]
                    px[n] = SPARK[:3] + (max(a, 150),)

    path = os.path.join(OUT, "points_1000.png")
    img.save(path)
    print("wrote %s  (%dx%d)" % (os.path.relpath(path, ROOT), w, h))


if __name__ == "__main__":
    main()
