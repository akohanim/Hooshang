#!/usr/bin/env python3
"""Rumi's talking-portrait loops: one seven-frame sheet per expression.

Reads   assets/portraits/rumi/raw/<state>.png          the still
        assets/portraits/rumi/frames/<state>_anim/*    a talking pass
        assets/portraits/rumi/frames/<state>_blink.png eyes shut
Writes  assets/portraits/loops/rumi_<state>_sheet.png  7 frames of 256
        assets/portraits/loops/manifest.json           this face's entry

Frame 0 is the still, untouched — the box shows it during silence, and it is
also the portrait shown when a face has no loop at all, so the two can never
disagree. Frames 1-5 are mouth positions, frame 6 is the blink.

ONLY THE MOUTH IS TAKEN FROM THE TALKING PASS, AND ONLY THE EYES FROM THE
BLINK. This is the whole of this file, and it is not a nicety.

The generator does not move a mouth on a fixed head — it REDRAWS the portrait
for every frame. Measured on the first pass: the silhouette centroid moves only
1.6px, so the head is not really going anywhere, but the mean per-pixel
difference from the still is ~20/255 spread evenly over the turban, the beard
and the shoulders alike, and the busiest rows in the whole frame were the TURBAN
(y 56-72), not the mouth. Played back that is not a man talking, it is a
portrait boiling — and at this scale, on flat pixel art, boiling is the most
obvious artifact there is.

So each frame is the still with ONE feathered ellipse composited onto it. The
head cannot drift because there is only ever one head; the turban cannot shimmer
because it is the same turban in all seven frames. gen_portrait_frames.py made
the same call for Hooshang's older rig, for the same reason.

WHERE THE ELLIPSES ARE IS MEASURED, NOT DRAWN BY EYE:
  - the mouth from the motion map of the talking pass, restricted to the lower
    face — its centroid is (136, 162);
  - the eyes from the blink frame's own difference against the still, which
    lands in two clusters (x 100-125 and x 145-172) across y 96-126, so the
    patch is centred (136, 110).
Re-measure both if the portraits are ever re-cut — see tools/gen_rumi_faces.md
is not a thing; the numbers are here and this docstring is the record.

Re-run:  python3 tools/gen_rumi_loops.py
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_rumi_portraits import STATES, flood_background, TOLERANCE

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets/portraits/rumi/raw")
FRAMES = os.path.join(ROOT, "assets/portraits/rumi/frames")
LOOPS = os.path.join(ROOT, "assets/portraits/loops")

SIZE = 256
## Frames per sheet: the still, five mouths, one blink — Hooshang's shape.
TALK = 5
FPS = 8

## (cx, cy, rx, ry) of the patched regions, measured — see the header.
MOUTH = (136, 162, 42, 32)
EYES = (136, 110, 50, 20)
## Pixels the patch fades out over. Without it the ellipse leaves a visible
## rim wherever the two generations shaded the cheek differently.
FEATHER = 7

## The eye band this face's blink lives in, written into the manifest so
## gen_portrait_loops.py measures Rumi where his eyes actually are. Its own
## default is Hooshang's y 40-68, and Rumi wears a turban — his are at 98-122.
EYE_BAND = [98, 124, 96, 178]


def ellipse_alpha(cx, cy, rx, ry, feather):
    """A soft-edged ellipse as a 0..1 alpha map."""
    y, x = np.mgrid[0:SIZE, 0:SIZE]
    # Distance in ellipse units: 1.0 on the rim.
    d = np.sqrt(((x - cx) / float(rx)) ** 2 + ((y - cy) / float(ry)) ** 2)
    # Feather expressed in the same units, taken off the outside.
    inner = 1.0 - feather / float(min(rx, ry))
    a = np.clip((1.0 - d) / max(1.0 - inner, 1e-6), 0.0, 1.0)
    return a[..., None]


def patch(base, src, region):
    """`base` with `src` composited through a feathered ellipse."""
    a = ellipse_alpha(*region, FEATHER)
    out = base.astype(float) * (1.0 - a) + src.astype(float) * a
    return np.clip(out, 0, 255).astype(np.uint8)


def talk_frames(state):
    """The TALK most distinct mouth positions of the talking pass.

    Distinct BY THE MOUTH, not by the frame: every frame differs from the still
    everywhere (that is the boiling this file exists to discard), so ranking on
    whole-frame difference would rank the noise.
    """
    d = os.path.join(FRAMES, "%s_anim" % state)
    paths = [os.path.join(d, "f%d.png" % i) for i in range(9)]
    paths = [p for p in paths if os.path.exists(p)]
    if len(paths) < TALK + 1:
        raise SystemExit("!! %s: only %d animation frames, need %d"
                         % (state, len(paths), TALK + 1))
    base = np.asarray(Image.open(paths[0]).convert("L"), dtype=float)
    cx, cy, rx, ry = MOUTH
    box = (slice(cy - ry, cy + ry), slice(cx - rx, cx + rx))
    scored = []
    for p in paths[1:]:
        f = np.asarray(Image.open(p).convert("L"), dtype=float)
        scored.append((float(np.abs(f - base)[box].mean()), p))
    scored.sort(reverse=True)
    picked = [p for _, p in scored[:TALK]]
    # Back into playing order, so the cycle reads as speech rather than as a
    # ranking: the box steps through `talk` in the order it is given.
    return [p for p in paths[1:] if p in picked]


def build(state):
    still = np.asarray(Image.open(os.path.join(RAW, state + ".png"))
                       .convert("RGB"), dtype=np.uint8)
    frames = [still]
    for p in talk_frames(state):
        src = np.asarray(Image.open(p).convert("RGB"), dtype=np.uint8)
        frames.append(patch(still, src, MOUTH))
    blink = np.asarray(Image.open(os.path.join(FRAMES, state + "_blink.png"))
                       .convert("RGB"), dtype=np.uint8)
    frames.append(patch(still, blink, EYES))

    sheet = Image.new("RGB", (SIZE * len(frames), SIZE))
    for i, f in enumerate(frames):
        img, share = flood_background(Image.fromarray(f), TOLERANCE)
        tight, tshare = flood_background(Image.fromarray(f), TOLERANCE // 2)
        if abs(share - tshare) > 0.01:
            raise SystemExit("!! %s frame %d: background fill is on the cliff "
                             "(%.1f%% vs %.1f%%)" % (state, i, share * 100,
                                                     tshare * 100))
        sheet.paste(img, (i * SIZE, 0))
    name = "rumi_%s" % state
    sheet.save(os.path.join(LOOPS, name + "_sheet.png"))
    return name, len(frames)


def main():
    man_path = os.path.join(LOOPS, "manifest.json")
    man = json.load(open(man_path))
    for state in STATES:
        name, n = build(state)
        entry = man.get(name, {})
        entry.update({
            "sheet": "%s_sheet.png" % name,
            "frames": n,
            "frame_size": [SIZE, SIZE],
            "fps": FPS,
            "loop": True,
            # Roles are assigned by gen_portrait_loops.py, which MEASURES them.
            # They are known here by construction — frame 0 is the still and the
            # last is the blink — but letting the indexer find them anyway means
            # its answer is a check on this one rather than a copy of it.
            "eye": EYE_BAND,
        })
        man[name] = entry
        print("  %-18s %d frames -> %s_sheet.png" % (name, n, name))
    json.dump(man, open(man_path, "w"), indent=2)
    print("\nwrote %d sheets and their manifest entries" % len(STATES))
    print("now run: python3 tools/gen_portrait_loops.py")


if __name__ == "__main__":
    main()
