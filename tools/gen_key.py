#!/usr/bin/env python3
"""One quest-key sprite: a small ornate key, gold with a jewelled bow.

Procedural, same flat-shaded-geometry technique as tools/gen_cone_spikes.py —
there is no source render for this prop. One 10x14 sprite: a round bow (the
loop you'd hold) with a small gem in it, a shaft, and two teeth at the bottom.

ONE SHARED DESIGN for all four keys — the brief calls for "one shared design
(or a subtle per-id palette variant)"; this uses the SAME shape for a simpler
first pass, since Act2Quest tracks keys by id, not by appearance, and a level
author placing four visually-identical keys is not a source of confusion the
way four identically-coloured hazards with different behaviour would be.

WATERCOLOR PASS (2026-09). PALETTE ONLY — THE BOW/SHAFT/TEETH GEOMETRY IS
UNCHANGED. At 10x14 this is the smallest asset in the whole watercolor batch;
per experiments/act2_watercolor/README.md's conclusion (and
gen_act2_cone_spikes.py's own precedent for exactly this problem) a
generative image reduced this far turns to mush rather than reading as "a
key", so the silhouette stays hand-drawn and only the colour ramp is read
from a Pixellab source.

Source: assets/props/key/source/act2_key.png (Pixellab
create_image_pixflux, prompt "ornate small gold key with a rose pink jewel
set in the bow, Persian engraved shaft... detailed pixel art with
watercolor-influenced soft gradient shading, clean crisp pixel edges,
restrained painterly bleed... warm palette of gold amber and rose", seed
2205).

Re-run after editing: python3 tools/gen_key.py
"""
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "key")
LDTK_ART = os.path.join(ROOT, "ldtk", "art")
SOURCE = os.path.join(OUT, "source", "act2_key.png")

W, H = 10, 14


def _ramp_from_source(path, n=14):
    """Top-N most common opaque colours in a Pixellab source, sorted
    brightest to darkest. Same technique as the sibling generators; kept as
    its own copy per this project's self-contained-script convention."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


_RAMP = _ramp_from_source(SOURCE)
# Rose/pink gem stops separate from the gold ones by hue: a warm gold/amber
# always has blue as its LOWEST channel (green sits above blue), while a
# rose/magenta has blue ABOVE green — a red-minus-green threshold alone
# still let several golds (e.g. (211,159,67), R-G=52) through as "gem",
# which is what shipped a brownish gem before this comment was added.
_GEM = [c for c in _RAMP if c[2] > c[1]]
_GOLD_STOPS = [c for c in _RAMP if c not in _GEM]

GOLD_HI = _GOLD_STOPS[0] + (255,)
GOLD = _GOLD_STOPS[len(_GOLD_STOPS) // 2] + (255,)
GOLD_DARK = _GOLD_STOPS[-1] + (255,)
GEM_HI = _GEM[0] + (255,)
GEM = _GEM[-1] + (255,)


def put(px, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c


def draw() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    # Bow: a ring, drawn as two concentric circles (outer gold, inner empty).
    cx, cy, ro, ri = 4.5, 3.5, 3.4, 1.6
    for x in range(W):
        for y in range(8):
            d2 = (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2
            if ri * ri <= d2 <= ro * ro:
                put(px, x, y, GOLD_HI if x < cx else GOLD)

    # Gem set in the bow's centre.
    for x in range(W):
        for y in range(8):
            d2 = (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2
            if d2 <= 1.3 * 1.3:
                put(px, x, y, GEM_HI if (x + y) % 2 == 0 else GEM)

    # Shaft, straight down from the bow.
    for y in range(7, 11):
        put(px, 4, y, GOLD_HI)
        put(px, 5, y, GOLD_DARK)

    # Two teeth at the bottom, offset so it reads as a key and not a nail.
    put(px, 5, 10, GOLD_DARK)
    put(px, 6, 10, GOLD)
    put(px, 5, 11, GOLD_DARK)
    put(px, 3, 11, GOLD_DARK)
    put(px, 4, 11, GOLD_HI)

    return img


os.makedirs(OUT, exist_ok=True)
os.makedirs(LDTK_ART, exist_ok=True)

key = draw()
key.save(os.path.join(OUT, "key.png"))
icon = key.resize((16, 16 * H // W), Image.NEAREST)
# Square LDtk icon, padded onto a transparent 16x16 canvas.
square = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
square.paste(icon, (0, max(0, (16 - icon.height) // 2)))
square.save(os.path.join(LDTK_ART, "key.png"))

print("wrote %s  %dx%d" % (os.path.join(OUT, "key.png"), key.width, key.height))
print("wrote %s" % os.path.join(LDTK_ART, "key.png"))
