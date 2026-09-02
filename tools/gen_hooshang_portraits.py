#!/usr/bin/env python3
"""Hooshang's dialogue portraits, second pass: cut from PixelLab CONTACT SHEETS
instead of one raw generation per state.

Reads   assets/portraits/hooshang/raw/<sheet>.jpg   an 11-pose reference grid
Writes  assets/portraits/hooshang_<state>.png        what the game uses

WHY A CONTACT SHEET AND NOT A RAW GENERATION. Rumi's raw/ holds one pose per
file because gen_rumi_loops.py builds every talking FRAME itself, by patching
a mouth or a pair of eyes onto a still. This art arrived differently — six
JPEGs, each a 4x3 grid of eleven whole-face poses for one state plus a text
label cell — so the job here is just PICKING one cell per state to be the
face the game shows at rest. Which cell is recorded in POSES rather than
re-derived by eye on every run, for reproducibility.

THIS ONLY PICKS THE REST FACE. The talking/blinking ANIMATION is a separate
pass, tools/gen_hooshang_rig.py, which reads the files this script writes —
see that script's docstring for why the two are split and why it does NOT
also pick a "talking" or "blinking" cell from these sheets the way an earlier
version of this file did: swapping between whole independent cells (rather
than patching a small fixed region of ONE cell) measurably flickers, because
each cell is its own generation with its own head tilt and shading, not a
re-render of one fixed head.

NO HANDS IN THE PICK. Several cells pose Hooshang with a hand on his face
(arms crossed, palm on cheek, chin-stroke) — fine for a single rest portrait,
but gen_hooshang_rig.py's blink patch pulls a SECOND cell's eye region onto
this one, and a couple of those hand poses are also the sheets' only
genuinely-closed-eyes cell. Where a state's rest pick and its blink source
(gen_hooshang_rig.BLINK_SOURCE) are different cells, the rest pick itself
still avoids hands so the un-patched portrait — the one act1_beats.gd FACES
preloads directly — never shows one.

THE "normal" SHEET COVERS THE "hesitant" STATE, NOT A NEW ONE. Hooshang's six
existing painted states are dazed / hesitant / skeptical / annoyed /
vulnerable / shocked (see act1_beats.gd's FACES); the six files handed over
here are normal / dazed / skeptical / annoyed / vulnerable / shocked — five
names match exactly, and "normal" is the only one left with no home. Five
states losing their art and one keeping an old painted face while its five
siblings switch styles would read as a mistake on screen, so "normal" fills
the "hesitant" slot rather than becoming a seventh state nothing points at.
The state NAME in FACES is unchanged — acting is still described as
"hesitant" in the beats that use it — only the drawing underneath moved.

Re-run after replacing any raw sheet:  python3 tools/gen_hooshang_portraits.py
Then rebuild the talk/blink rig:        python3 tools/gen_hooshang_rig.py
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_rumi_portraits import flood_background, TOLERANCE

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets/portraits/hooshang/raw")
OUT = os.path.join(ROOT, "assets/portraits")

SIZE = (256, 256)
## A few pixels shaved off each cropped cell before the flood fill, so the
## gutter's own grey border (~3px, antialiased into the cream) is never mistaken
## for background inside a single cell — it would fill fine either way, but this
## keeps the fill's seed a clean read of the cell's actual backdrop.
INSET = 4

## gen_rumi_portraits.MAX_DRIFT (0.01) is tuned for its raw PNGs, which are flat,
## noiseless fills. These sheets are JPEGs — every cell carries a faint
## compression gradient across the cream background — so the same stability
## check (same tolerance/half-tolerance split, 45 vs 22) needs a wider plateau
## to sit in here. Measured across every cell either this script or
## gen_hooshang_rig.py actually uses: drift tops out at 1.65 points (shocked
## cell 7), and every one of them was visually confirmed clean (no bleed into
## hair, teeth or collar) before this number was picked. A real leak reads
## very differently — Rumi's own documented one moved the fill 3.2 points
## crossing a tolerance jump (60->90) well past where this script's TOLERANCE
## (45) and its half (22) sit — so this stays far short of masking one.
MAX_DRIFT = 0.02

## state -> (source jpg stem in raw/, rest cell). Cell numbers are row-major
## across the 4x3 grid, 0 at top-left, chosen by hand.
POSES = {
    "hesitant":   ("normal",     0),
    "dazed":      ("dazed",      0),
    "skeptical":  ("skeptical",  0),
    "annoyed":    ("annoyed",    1),
    "vulnerable": ("vulnerable", 0),
    "shocked":    ("shocked",    0),
}


def cell_rects(img):
    """The 4x3 grid's cell boxes, found from the grey gutter between them
    rather than assumed fixed — measured per sheet, it drifts a few px from one
    JPEG to the next.
    """
    a = np.asarray(img.convert("RGB")).astype(int)
    diff_rg = np.abs(a[:, :, 0] - a[:, :, 1])
    diff_gb = np.abs(a[:, :, 1] - a[:, :, 2])
    greyish = (diff_rg < 6) & (diff_gb < 12) & (a[:, :, 0] > 180) & (a[:, :, 0] < 235)

    def runs(frac, thresh=0.5):
        hi = frac > thresh
        out, start = [], None
        for i, v in enumerate(hi):
            if v and start is None:
                start = i
            if not v and start is not None:
                out.append((start, i - 1))
                start = None
        if start is not None:
            out.append((start, len(hi) - 1))
        return out

    row_gutters = runs(greyish.mean(axis=1))
    col_gutters = runs(greyish.mean(axis=0))
    rows = [(row_gutters[i][1] + 1, row_gutters[i + 1][0] - 1)
            for i in range(len(row_gutters) - 1)]
    cols = [(col_gutters[i][1] + 1, col_gutters[i + 1][0] - 1)
            for i in range(len(col_gutters) - 1)]
    if len(rows) != 3 or len(cols) != 4:
        raise SystemExit("!! grid detection found %dx%d cells, expected 3x4"
                         % (len(rows), len(cols)))
    return [(x0, y0, x1, y1) for y0, y1 in rows for x0, x1 in cols]


def cut_cell(img, rects, index):
    """One cell, flood-filled onto the office backdrop and resized to 256x256
    — the shared building block gen_hooshang_rig.py also uses, so a patch cut
    from a different cell of the same sheet lines up on the same head
    position and backdrop colour as the still it gets composited onto."""
    x0, y0, x1, y1 = rects[index]
    crop = img.crop((x0 + INSET, y0 + INSET, x1 - INSET, y1 - INSET))
    tight, tight_share = flood_background(crop.copy(), TOLERANCE // 2)
    filled, share = flood_background(crop.copy(), TOLERANCE)
    if abs(share - tight_share) > MAX_DRIFT:
        raise SystemExit(
            "!! cell %d: fill covers %.1f%% at tolerance %d but %.1f%% at %d "
            "— on the cliff, not the plateau; lower TOLERANCE or re-pick the cell."
            % (index, share * 100, TOLERANCE, tight_share * 100, TOLERANCE // 2))
    if filled.size != SIZE:
        filled = filled.resize(SIZE, Image.LANCZOS)
    return filled.convert("RGBA")


def sheet_cell(sheet_name, index):
    """cut_cell, opening the sheet by name — what gen_hooshang_rig.py calls to
    pull a patch source cell that isn't necessarily any state's rest pick."""
    img = Image.open(os.path.join(RAW, sheet_name + "_sheet.jpg"))
    return cut_cell(img, cell_rects(img), index)


def main():
    for state, (sheet_name, rest) in POSES.items():
        portrait = sheet_cell(sheet_name, rest)
        portrait.convert("RGB").save(os.path.join(OUT, "hooshang_%s.png" % state))
        print("wrote hooshang_%s.png" % state)


if __name__ == "__main__":
    main()
