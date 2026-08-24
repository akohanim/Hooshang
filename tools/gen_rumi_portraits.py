#!/usr/bin/env python3
"""Rumi's dialogue portraits: normalise the raw generations into the set the
dialogue box loads.

Reads   assets/portraits/rumi/raw/<state>.png   (what Pixellab returned)
Writes  assets/portraits/rumi_<state>.png       (what the game uses)

WHAT THIS HAS TO FIX, and why it is a script rather than five hand edits.

  - THE BACKGROUND. Pixellab returns the bust on a light grey field; every
    Hooshang portrait sits on the office's warm near-black (55, 50, 46). A
    portrait on the wrong ground does not read as "a different character", it
    reads as a different GAME — the two faces appear in the same banner, often
    on consecutive lines. So the ground is replaced with Hooshang's exact
    colour, measured off his sheet rather than picked by eye.

  - REPLACED BY FLOOD FILL FROM THE EDGE, not by colour match. The turban is
    cream and the undershirt is near-white, and both come within a few steps of
    the background grey; a plain "recolour everything near this value" pass eats
    holes in the cloth. Filling inward from the border only touches pixels the
    background is actually connected to, which is the definition of background
    the image can be asked for.

  - THE TOLERANCE IS MEASURED, AND SO IS THE CHECK ON IT. Swept over the first
    portrait, the fill covers a flat 43.0% of the canvas at EVERY tolerance from
    6 to 60 — the generated ground is one hard-edged colour with no soft skirt —
    and then jumps to 46.2% at 90, where it has climbed into the shadowed side
    of the cream undershirt and taken 60% of it. So the safe range is a wide
    plateau ending in a cliff, and TOLERANCE sits in the middle of the plateau.

    That first pass shipped at 90 and ate the shirt, which is worth recording
    because of how it got through: the guard was a cap on the fill FRACTION, and
    a leak that swallows the shirt only moves that number from 43% to 46%. A
    threshold cannot separate those. What does separate them is the plateau
    itself — so the check runs the fill TWICE, at the tolerance and at half of
    it, and fails if the two disagree. On the plateau they are identical; near
    the cliff they are not. A stability test, not a size test.

Sizes: 256x256, opaque, matching every Hooshang portrait exactly. The dialogue
box identifies a face by its TEXTURE PATH (see scenes/ui/dialogue_box.gd), so
the file names here are the contract — rumi_<state>.png, and `state` is what a
beat names.

Re-run after re-generating any raw:  python3 tools/gen_rumi_portraits.py
"""
import os
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets", "portraits", "rumi", "raw")
OUT = os.path.join(ROOT, "assets", "portraits")

## The states the dialogue asks for. `serene` and `warm_open` are used by
## scripts/dash_tutorial.gd today; the rest exist so a beat has somewhere to go
## without a new art pass. Adding one here means adding a raw of the same name.
STATES = ["serene", "warm_open", "urgent", "wistful", "sorrowful"]

## Hooshang's own portrait ground, sampled from his sheet's border (it is 615 of
## the 1024 edge pixels, far and away the mode). Both faces share a banner, so
## they share a backdrop.
BACKDROP = (55, 50, 46)

SIZE = (256, 256)
## How far from the seed colour still counts as background, as a per-channel
## sum-of-differences. The middle of the measured plateau — see the header.
TOLERANCE = 45
## The fill is also run at half TOLERANCE. If the two disagree by more than this
## fraction of the canvas, the tolerance is not on the plateau any more and the
## fill is eating the figure. Measured: on the plateau the two agree exactly, so
## anything above a rounding margin is a real divergence.
MAX_DRIFT = 0.01


def flood_background(img, tolerance):
    """Replace the edge-connected background with BACKDROP.

    Returns (image, filled_fraction).
    """
    img = img.convert("RGB")
    w, h = img.size
    px = img.load()
    # Seed from the border's most common colour rather than from one corner: a
    # corner can land on the shoulder.
    ring = [px[x, y] for x in range(w) for y in (0, h - 1)]
    ring += [px[x, y] for y in range(h) for x in (0, w - 1)]
    seed = max(set(ring), key=ring.count)

    def near(c):
        return sum(abs(c[i] - seed[i]) for i in range(3)) <= tolerance

    seen = [[False] * h for _ in range(w)]
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near(px[x, y]) and not seen[x][y]:
                seen[x][y] = True
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if near(px[x, y]) and not seen[x][y]:
                seen[x][y] = True
                queue.append((x, y))

    filled = 0
    while queue:
        x, y = queue.popleft()
        px[x, y] = BACKDROP
        filled += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[nx][ny] and near(px[nx, ny]):
                seen[nx][ny] = True
                queue.append((nx, ny))
    return img, filled / float(w * h)


def main():
    missing = [s for s in STATES
               if not os.path.exists(os.path.join(RAW, s + ".png"))]
    if missing:
        raise SystemExit("!! no raw for: %s (expected in assets/portraits/rumi/raw/)"
                         % ", ".join(missing))
    for state in STATES:
        img = Image.open(os.path.join(RAW, state + ".png"))
        if img.size != SIZE:
            img = img.resize(SIZE, Image.NEAREST)
        tight, tight_share = flood_background(img.copy(), TOLERANCE // 2)
        img, share = flood_background(img, TOLERANCE)
        if abs(share - tight_share) > MAX_DRIFT:
            raise SystemExit(
                "!! %s: the fill covers %.1f%% at tolerance %d but %.1f%% at "
                "%d — that is not the plateau, it is the cliff, and the wider "
                "one is eating the figure. Lower TOLERANCE."
                % (state, share * 100, TOLERANCE, tight_share * 100,
                   TOLERANCE // 2))
        path = os.path.join(OUT, "rumi_%s.png" % state)
        img.save(path)
        print("wrote rumi_%s.png  %dx%d, ground %d%% of the frame"
              % (state, img.width, img.height, round(share * 100)))


if __name__ == "__main__":
    main()
