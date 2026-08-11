#!/usr/bin/env python3
"""The pomegranate collectible: four frames cut from the painted reference.

Source: assets/props/pomegranate/source/pomegranate_hooshang.png — four painted
pomegranates in a row on transparency. Output: frame_000..003.png next to it,
square, transparent, ready for pomegranate_frames.tres.

Two things this does that a plain resize does not:

- **Centres each frame on its own fruit.** The four in the source sit at
  different heights (their tops run 548, 461, 390, 544), which is a bob baked
  into the sheet. The prop already bobs on a tween of its own
  (scenes/props/pomegranate.gd, `bob_height`), so keeping the source's offsets
  would hover it twice, at two different rates. The frames are cut concentric
  and the tween does the floating.
- **Quantises after the downscale.** Straight LANCZOS off a painted 455px fruit
  gives a smooth photographic blur that reads as a low-res photo, not as art —
  which is exactly what the "NOT 8-bit, but still pixel art" line in CLAUDE.md
  is about. Reducing to a small palette afterwards puts the edges back.

Re-run after editing: python3 tools/gen_pomegranate.py [size]
"""
import os
import sys
import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "pomegranate")
SRC = os.path.join(OUT, "source", "pomegranate_hooshang.png")

## Edge of the sprite, in px, at 1x. The tile grid is 16 and the old fruit was
## 16x16, but this art is painted at 455px and carries arils, a crown and a cut
## face — at 16 all three turn to mush. A collectible is allowed to be bigger
## than a tile; the pickup radius is unchanged either way.
SIZE = int(sys.argv[1]) if len(sys.argv) > 1 else 24
## Colours kept after the downscale. Low enough to read as pixel art, high
## enough to keep the aril highlights and the rind's gradient apart.
PALETTE = 28
## Alpha below this is cut away entirely: a painted edge fades out over several
## source pixels, and at this scale that becomes a halo of half-transparent
## grey. Above it, alpha is forced solid, so every edge is a hard pixel edge.
ALPHA_CUT = 110


def frames(img):
    """The four fruit, as their own tight boxes, left to right."""
    a = np.array(img)
    solid = a[..., 3] > 8
    cols = solid.any(axis=0)
    runs, start = [], None
    for x, on in enumerate(cols):
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append((start, x))
            start = None
    if start is not None:
        runs.append((start, len(cols)))
    runs = [r for r in runs if r[1] - r[0] > 40]
    out = []
    for (x0, x1) in runs:
        ys = np.where(solid[:, x0:x1].any(axis=1))[0]
        out.append(img.crop((x0, int(ys.min()), x1, int(ys.max()) + 1)))
    return out


def square(fruit):
    """Centre it on a square canvas, so the four are concentric.

    The canvas is the fruit's LONGEST side and nothing more. Every pixel of
    padding here is a pixel not spent on the fruit, and at 16px across there are
    only 256 of them — the difference between arils you can count and a red
    smudge is largely this.
    """
    side = max(fruit.size)
    pad = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    pad.alpha_composite(fruit, ((side - fruit.width) // 2, (side - fruit.height) // 2))
    return pad


def pixelate(fruit):
    # Two steps, not one. A single 455 -> 16 resample averages a dozen source
    # pixels per output pixel and the arils vanish into the rind's average. Going
    # via 4x the target and sharpening in between keeps the structure that
    # survives to the last step — the smaller the target, the more this matters.
    mid = SIZE * 4
    small = fruit.resize((mid, mid), Image.LANCZOS)
    small = ImageEnhance.Sharpness(small).enhance(2.2)
    small = small.resize((SIZE, SIZE), Image.BOX)
    a = np.array(small)
    # Un-premultiply the painted edge before anything else: the source's soft
    # rim carries dark RGB at low alpha, and averaging that into neighbours on
    # the way down is what puts a black fringe around the fruit.
    alpha = a[..., 3:4].astype(np.float32) / 255.0
    rgb = a[..., :3].astype(np.float32)
    lift = np.where(alpha > 0.02, np.clip(rgb / np.maximum(alpha, 0.02), 0, 255), rgb)
    a[..., :3] = lift.astype(np.uint8)
    a[..., 3] = np.where(a[..., 3] >= ALPHA_CUT, 255, 0)
    small = Image.fromarray(a, "RGBA")
    # A touch of contrast and bite, then a small palette. In that order: sharpen
    # first and the quantiser has real edges to snap to.
    small = ImageEnhance.Sharpness(small).enhance(1.6)
    small = ImageEnhance.Color(small).enhance(1.12)
    rgb_only = small.convert("RGB").quantize(
        colors=PALETTE, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    keyed = np.dstack([np.array(rgb_only), np.array(small)[..., 3]])
    return Image.fromarray(keyed.astype(np.uint8), "RGBA")


src = Image.open(SRC).convert("RGBA")
cut = frames(src)
assert len(cut) == 4, "expected four pomegranates, found %d" % len(cut)
for i, fruit in enumerate(cut):
    pixelate(square(fruit)).save(os.path.join(OUT, "frame_%03d.png" % i))
print("wrote 4 frames at %dx%d" % (SIZE, SIZE))
