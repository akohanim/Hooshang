#!/usr/bin/env python3
"""Import the Codex/GPT-generated Hooshang idle-breathing reference sheet
(assets/characters/hooshang/sprites/source/gpt_v1/idle.png — this is the
"hooshang_idle_sprite.png" reference image `prompts.json` names as the sprite-
rendering/consistent-frames anchor for the run/jump/fall/dash/wall_* batch)
into 8 game-ready 88x88 frames, replacing Breathing_Idle's 4.

Unlike the action sheets this one already carries real alpha (no baked
checkerboard) and is laid out as a single row of 8 equal-width columns, with
a numbered caption baked in BELOW the character row that must be cropped out
before slicing. It is also drawn far more consistently than the action
sheets — every frame's silhouette lands in the same few pixels of height and
baseline, measured directly rather than assumed — so frames are placed by
each frame's OWN bounding box (fixed baseline, per-frame horizontal center)
rather than the sheet-cell contract import_hooshang_gpt_v1.py needs for the
noisier action sheets.

Re-run after replacing the source sheet.
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "assets/characters/hooshang/sprites/source/gpt_v1/idle.png"
DEST_DIR = "assets/characters/hooshang/sprites/chubby/Breathing_Idle/east"

# The character row sits in y=[0, CAPTION_TOP); below that is the "1".."8"
# numbering and the "IDLE BREATHING ANIMATION (8 FRAMES)" caption, baked
# into the same image and not wanted in-game.
CAPTION_TOP = 590

TARGET_CANVAS = 88
TARGET_STAND_HEIGHT = 44.0
TARGET_BASELINE_Y = 67.0
TARGET_CENTER_X = 44.0


def decontaminate(im):
    arr = np.array(im.convert("RGBA"))
    alpha = arr[..., 3]
    fg_mask = alpha > 10
    if fg_mask.any() and (~fg_mask).any():
        _, (iy, ix) = ndimage.distance_transform_edt(~fg_mask, return_indices=True)
        filled = arr[..., :3][iy, ix]
        rgb = np.where(fg_mask[..., None], arr[..., :3], filled)
    else:
        rgb = arr[..., :3]
    return Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]))


def find_columns(alpha, band_top, band_bottom):
    band = alpha[band_top:band_bottom, :]
    col_counts = (band > 10).sum(axis=0)
    runs = []
    in_run = False
    start = 0
    for x, c in enumerate(col_counts):
        nz = c > 0
        if nz and not in_run:
            start = x
            in_run = True
        if not nz and in_run:
            runs.append((start, x - 1))
            in_run = False
    if in_run:
        runs.append((start, len(col_counts) - 1))
    return runs


def main():
    im = Image.open(SRC)
    cleaned = decontaminate(im)
    alpha = np.array(cleaned)[..., 3]

    runs = find_columns(alpha, 0, CAPTION_TOP)
    assert len(runs) == 8, f"expected 8 frames, found {len(runs)}: {runs}"

    # A single fixed scale for the whole sheet (from the median bbox height)
    # so per-frame noise in the silhouette's exact extent can't pulse the
    # character's size frame to frame.
    heights = []
    for x0, x1 in runs:
        sub = alpha[0:CAPTION_TOP, x0:x1 + 1]
        ys = np.where(sub.max(axis=1) > 10)[0]
        heights.append(ys.max() - ys.min() + 1)
    stand_height = float(np.median(heights))
    scale_factor = TARGET_STAND_HEIGHT / stand_height

    os.makedirs(DEST_DIR, exist_ok=True)
    for f in os.listdir(DEST_DIR):
        if f.startswith("frame_"):
            os.remove(os.path.join(DEST_DIR, f))

    for i, (x0, x1) in enumerate(runs):
        sub = alpha[0:CAPTION_TOP, x0:x1 + 1]
        ys = np.where(sub.max(axis=1) > 10)[0]
        xs = np.where(sub.max(axis=0) > 10)[0]
        baseline_y = ys.max() + 1  # bottom of the drawn silhouette
        center_x = xs.min() + (xs.max() - xs.min()) / 2.0

        cell = cleaned.crop((x0, 0, x1 + 1, CAPTION_TOP))
        scaled_w = max(1, round(cell.width * scale_factor))
        scaled_h = max(1, round(cell.height * scale_factor))
        scaled_cell = cell.resize((scaled_w, scaled_h), Image.LANCZOS)

        paste_x = round(TARGET_CENTER_X - center_x * scale_factor)
        paste_y = round(TARGET_BASELINE_Y - baseline_y * scale_factor)

        canvas = Image.new("RGBA", (TARGET_CANVAS, TARGET_CANVAS), (0, 0, 0, 0))
        canvas.paste(scaled_cell, (paste_x, paste_y), scaled_cell)
        canvas.save(os.path.join(DEST_DIR, f"frame_{i:03d}.png"))

    print(f"idle -> {DEST_DIR} (8 frames)")


if __name__ == "__main__":
    main()
