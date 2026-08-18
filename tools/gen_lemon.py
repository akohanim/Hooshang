#!/usr/bin/env python3
"""The lemon collectible: eight frames cut from a generated bounce sheet.

Source: assets/props/lemon/source/lemon_sheet.jpeg — eight lemons in a row,
bouncing. Output: frame_000..007.png beside it, ready for lemon_frames.tres.

THE SOURCE IS A JPEG WITH THE TRANSPARENCY CHECKERBOARD BAKED IN, which is the
first problem and the reason this is not a crop-and-resize. There is no alpha to
read; the background is literally two grey squares repeating, and JPEG ringing
smears their edges so a colour-distance key leaves speckle over the whole sheet
(measured: 77% background at the tightest usable tolerance, with noise in every
column). What separates cleanly is SATURATION — the fruit and its leaf are
strongly coloured and the checkerboard is grey — so that is the key. The cost is
the dust puffs and the drop shadows, which were drawn semi-transparent and are
therefore grey once flattened; they go with the background. No loss: at ten
pixels they would be two muddy dots.

THE BOUNCE IS COMPRESSED, NOT DISCARDED. Almost all of the animation in the
sheet is vertical travel — seven of the eight lemons are within 9px of the same
height and shape, and only frame 6 differs, which is the landing squash (236px
tall against ~280, and the widest of the eight). Centring them concentrically the
way tools/gen_lemon.py does would therefore throw the animation away and
leave a near-still sprite. But the travel as drawn is 335 source px against a
280px lemon — well over a body-height of bounce, which at this scale is 40px of
motion on a 10px sprite.

So the offsets are kept and SCALED to TRAVEL. The shape of the motion (the rise,
the hang at the top, the drop, the squash at the bottom) survives; only the
amplitude changes. Frames are aligned by their BOTTOM edge, not their top,
because a thing landing keeps its base on the ground and grows shorter.

Because the bounce is baked in, scenes/props/Lemon.tscn sets `bob_height = 0`.
The prop's own bob tween and this would otherwise hover it twice at two
different rates, and the squash would drift out of step with the bottom of the
bob — the same trap gen_lemon.py's docstring records, arrived at from the
other side.

Re-run after editing:  python3 tools/gen_lemon.py [size]
The shipped sizes are 10 (world) and 20 (dense, Screen.TOKEN_DENSITY x):
    python3 tools/gen_lemon.py 10
    python3 tools/gen_lemon.py 20 dense
    python3 tools/gen_lemon.py 16 icon     # ldtk/art/lemon.png
"""
import os
import sys
import numpy as np
from PIL import Image, ImageEnhance
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "assets", "props", "lemon")
SRC = os.path.join(BASE, "source", "lemon_sheet.jpeg")

SIZE = int(sys.argv[1]) if len(sys.argv) > 1 else 10
MODE = sys.argv[2] if len(sys.argv) > 2 else ""
## `icon` writes ONE frame to ldtk/art/lemon.png — the picture LDtk shows for the
## Lemon entity. Generated from the same source as the sprite so the thing you
## place in the editor is the thing that appears in the room.
ICON = MODE == "icon"
OUT = os.path.join(BASE, "dense") if MODE == "dense" else BASE
## How much of the canvas the bounce is allowed to use. The rest is the lemon.
TRAVEL = max(1, round(SIZE * 0.2))
BODY_H = SIZE - TRAVEL

## Saturation at or above this is fruit; below it is checkerboard, shadow or
## dust. The gap is wide — lemon yellow sits around 0.8 and the two greys under
## 0.1 — so this is not a knife edge.
SAT_KEY = 0.40
## ...and it has to be brighter than this, which drops the near-black JPEG noise
## in the checkerboard's darker squares.
VAL_KEY = 60
PALETTE = 20
ALPHA_CUT = 110


def foreground(img):
    a = np.array(img).astype(float)
    mx = a.max(axis=2)
    mn = a.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0)
    return (sat >= SAT_KEY) & (mx > VAL_KEY)


def frame_columns(fg):
    """The eight lemon bodies, as column ranges.

    Split on column DENSITY rather than on any foreground at all: the motion
    swooshes are foreground too (they are the same yellow), they run between
    neighbouring lemons, and keying on presence merges the eight into three.
    A body fills ~280 rows of its columns; a swoosh fills a handful.
    """
    count = fg.sum(axis=0)
    core = count > 90
    runs, start = [], None
    for x, on in enumerate(core):
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append([start, x])
            start = None
    if start is not None:
        runs.append([start, len(core)])
    merged = []
    for r in runs:
        if merged and r[0] - merged[-1][1] < 40:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    return [r for r in merged if r[1] - r[0] > 80]


def body_box(sub):
    """The lemon and its leaf, without the motion swooshes.

    The largest CONNECTED blob, not the densest rows. Trimming on row density
    was the first attempt and it silently ate the leaf: the leaf is thin, so its
    rows look exactly like a swoosh's to a density test, and the eight frames
    came out as yellow blobs with a dark smudge where the green should be. The
    leaf is attached to the fruit and the swoosh arcs are not, so connectivity
    tells them apart and thickness never comes into it.
    """
    labels, n = ndimage.label(sub)
    if n == 0:
        raise SystemExit("empty frame band")
    sizes = ndimage.sum(sub, labels, range(1, n + 1))
    keep = labels == (int(np.argmax(sizes)) + 1)
    ys = np.where(keep.any(axis=1))[0]
    xs = np.where(keep.any(axis=0))[0]
    return int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1


def pixelate(img, w, h):
    """Down to (w, h) with the edges intact.

    Two steps and a sharpen between, for the reason gen_lemon.py gives: a
    single resample from 280px to 8 averages the shading into one flat yellow.
    """
    small = img.resize((w * 4, h * 4), Image.LANCZOS)
    small = ImageEnhance.Sharpness(small).enhance(2.2)
    small = small.resize((w, h), Image.BOX)
    a = np.array(small)
    # Un-premultiply before the alpha is cut, or the soft rim's dark RGB averages
    # into its neighbours and leaves a black fringe.
    alpha = a[..., 3:4].astype(np.float32) / 255.0
    rgb = a[..., :3].astype(np.float32)
    a[..., :3] = np.where(alpha > 0.02, np.clip(rgb / np.maximum(alpha, 0.02), 0, 255),
                          rgb).astype(np.uint8)
    a[..., 3] = np.where(a[..., 3] >= ALPHA_CUT, 255, 0)
    small = Image.fromarray(a, "RGBA")
    small = ImageEnhance.Sharpness(small).enhance(1.6)
    small = ImageEnhance.Color(small).enhance(1.1)
    flat = small.convert("RGB").quantize(
        colors=PALETTE, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    return Image.fromarray(
        np.dstack([np.array(flat), np.array(small)[..., 3]]).astype(np.uint8), "RGBA")


sheet = Image.open(SRC).convert("RGB")
fg = foreground(sheet)
rgba = Image.fromarray(
    np.dstack([np.array(sheet), (fg * 255).astype(np.uint8)]), "RGBA")

bands = frame_columns(fg)
assert len(bands) == 8, "expected eight lemons, found %d" % len(bands)

boxes = []
for x0, x1 in bands:
    c0, c1, r0, r1 = body_box(fg[:, x0:x1])
    boxes.append((x0 + c0, x0 + c1, r0, r1))

# ONE scale for all eight, off the tallest body, so the squashed frame stays
# squashed. Scaling each frame to fill the canvas would silently undo it.
tallest = max(b[3] - b[2] for b in boxes)
scale = BODY_H / float(tallest)
bottoms = [b[3] for b in boxes]
span = max(bottoms) - min(bottoms)

if ICON:
    OUT = os.path.join(ROOT, "ldtk", "art")
os.makedirs(OUT, exist_ok=True)
for i, (x0, x1, y0, y1) in enumerate(boxes):
    if ICON and i != 0:
        break
    w = max(1, int(round((x1 - x0) * scale)))
    h = max(1, int(round((y1 - y0) * scale)))
    body = pixelate(rgba.crop((x0, y0, x1, y1)), w, h)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    # Lowest bottom sits on the canvas floor; the rest ride above it by their
    # share of the compressed travel.
    lift = 0 if span == 0 else round((max(bottoms) - bottoms[i]) / span * TRAVEL)
    canvas.alpha_composite(body, ((SIZE - w) // 2, SIZE - h - lift))
    canvas.save(os.path.join(OUT, "lemon.png" if ICON else "frame_%03d.png" % i))

print("wrote %s at %dx%d into %s  (body %dpx, travel %dpx)"
      % ("the LDtk icon" if ICON else "8 frames", SIZE, SIZE,
         os.path.relpath(OUT, ROOT), BODY_H, TRAVEL))
