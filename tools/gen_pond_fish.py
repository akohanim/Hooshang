#!/usr/bin/env python3
"""A tiny ambient pond fish: a 3-frame swim-wiggle sheet for
scenes/props/Fish.tscn. Purely decorative — no hazard, no collision, just
something alive drifting inside a Pond.

Output: assets/props/pond_fish/fish.png, three 12x8 frames side by side
(36x8 total), facing EAST (west is flip_h in fish.gd, the same convention
every other sprite in this project follows).

GEOMETRY IS PROCEDURAL; only the colour ramp is read from a Pixellab source —
the same rule gen_pond_water.py documents at more length, and for the same
reason: at a 12px canvas there is no room for a generated fish's fins or
scales to survive the reduction. What the source is good for is a plausible
warm koi palette rather than a guessed hex.

Source: assets/props/pond_fish/source/act2_koi.png (Pixellab
create_image_pixflux, "small koi pond fish swimming sideways... watercolor-
influenced soft gradient shading... warm orange gold and cream palette with a
hint of turquoise fin", seed 2027).

The wiggle is the TAIL, not the body: three frames flick it up, straight and
down while the oval body stays put, the cheapest read of "swimming" at a
size with no room for a body flex.

Re-run after editing: python3 tools/gen_pond_fish.py
"""
import os
from collections import Counter

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "pond_fish")
SOURCE = os.path.join(OUT, "source", "act2_koi.png")

W, H = 12, 8


def _ramp_from_source(path, n=20):
    """Top-N most common opaque colours in a Pixellab source, sorted
    brightest to darkest. Same technique as every sibling generator."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


_RAMP = _ramp_from_source(SOURCE)
# Explicit indices, printed and checked against this exact source when this
# was written — same convention gen_magic_carpet.py's own note explains.
_BELLY = _RAMP[0]    # (250, 234, 220) pale cream underside
_BODY = _RAMP[2]     # (246, 182, 89) warm gold-orange
_SHADE = _RAMP[10]   # (251, 112, 53) deeper orange, the body's shaded half
_EYE = _RAMP[19]     # (34, 51, 44) near-black


def _frame(tail_dy):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Body: a small oval, belly pale, back shaded, nose toward +x (east) —
    # kept clear of both canvas edges so the tail (below) has room to swing.
    draw.ellipse([3, 2, 10, 6], fill=_BODY)
    draw.point([(4, 5), (5, 5), (6, 5), (7, 5)], fill=_BELLY)  # pale belly line
    draw.point([(4, 2), (5, 2), (6, 2), (7, 2), (8, 2)], fill=_SHADE)  # shaded back
    # Tail: a small triangle trailing off the back (-x) of the body, flicked
    # up/straight/down by tail_dy — the whole of the "swimming" read at a
    # size with no room for the body itself to flex.
    base_y = H // 2
    draw.polygon([(3, base_y - 1), (3, base_y + 1),
                  (0, base_y + tail_dy)], fill=_SHADE)
    # Eye, toward the nose.
    draw.point([(9, 3)], fill=_EYE)
    return img


os.makedirs(OUT, exist_ok=True)
frames = [_frame(dy) for dy in (-2, 0, 2)]

sheet = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.alpha_composite(f, (i * W, 0))

path = os.path.join(OUT, "fish.png")
sheet.save(path)
print("wrote %s  %dx%d (%d frames)" % (path, sheet.width, sheet.height, len(frames)))
