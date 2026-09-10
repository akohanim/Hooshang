#!/usr/bin/env python3
"""Import the Codex/GPT-generated Hooshang animation sheets
(output/hooshang_act1_gpt_v1/, see that folder's README.md and prompts.json)
into game-ready 88x88 frames under assets/characters/hooshang/sprites/chubby/.

Each raw sheet is 1774x887 RGB, 4 cols x 2 rows (8 poses, row-major reading
order), with a baked-in light-gray checkerboard "transparent" background —
the generator did not honor the transparent-background request. This:

  1. Keys out the checkerboard via flood fill from the SHEET'S OWN BORDER, not
     a global color threshold — a global threshold would also kill an
     isolated near-white pixel INSIDE the silhouette (an eye highlight), since
     the checker tone (~246-254, desaturated) sits right next to skin/cloth
     highlights in brightness. A flood fill from the border only ever reaches
     background because nothing on the border is ever part of the character.
  2. Color-decontaminates the newly-transparent background (nearest-opaque-
     neighbor fill via a distance transform) before downscaling — feeding the
     checker gray straight into a LANCZOS resize haloes every edge in light
     gray, since PIL's resize is not alpha-premultiplied.
  3. Slices into 8 cells and places each one against a FIXED scale/baseline/
     center contract — not each frame's own bounding box — so a stride or a
     jump arc doesn't get independently re-centered frame to frame. The
     contract comes from the sheet's own generation prompt (2048x1024 canvas,
     512x512 cells, ~390px standing height, 450px baseline, centered), scaled
     down by the sheet's actual/requested size ratio (the generator did not
     return the requested canvas size, but did return a uniformly-scaled one).

Per-clip curation (see CLAUDE.md's note on this for the reasoning): `climb` is
skipped outright (the generated cycle doesn't actually alternate arms — a
static hang pose repeated, worse than the existing cycle it would replace);
`jump` and `fall` are trimmed to the 4 of 8 frames that hold a consistent
scale/orientation (the other 4 drift, fine for a one-shot, not for a loop);
`dash` lands in its own new `chubby/Dash/` folder rather than overwriting
`chubby/Slide/`, since `dash` no longer needs to borrow Slide's art.

Re-run after replacing any raw sheet in output/hooshang_act1_gpt_v1/. This
only writes frame PNGs — it does not touch hooshang_frames.tres (frame counts
and ping-pong ordering there were hand-tuned per clip and would need re-review
if a curation choice above changes).
"""
import os
import shutil

import numpy as np
from PIL import Image
from scipy import ndimage

SRC_DIR = "assets/characters/hooshang/sprites/source/gpt_v1"
DEST_BASE = "assets/characters/hooshang/sprites/chubby"

# Authored contract from prompts.json: 2048x1024 canvas, 512x512 cells,
# character standing height ~390px, baseline 450px, centered horizontally.
REQUESTED_CANVAS_W = 2048.0
REQUESTED_STAND_HEIGHT = 390.0
REQUESTED_BASELINE_Y = 450.0

TARGET_CANVAS = 88
TARGET_STAND_HEIGHT = 44.0
TARGET_BASELINE_Y = 67.0
TARGET_CENTER_X = 44.0

# name -> (dest clip folder, frame indices to keep from the generated 8, in order)
CLIPS = {
    "run": ("Running", list(range(8))),
    "jump": ("Jumping", [0, 1, 2, 3]),
    "fall": ("Falling", [0, 1, 2, 3]),
    "dash": ("Dash", list(range(8))),
    "wall_jump": ("Wall_Jump", list(range(8))),
    "wall_land": ("Wall_Land", list(range(8))),
    "wall_slide": ("Wall_Slide", list(range(8))),
    # "climb" deliberately omitted — see module docstring.
}


def is_bg(arr):
    r = arr[..., 0].astype(np.int16)
    g = arr[..., 1].astype(np.int16)
    b = arr[..., 2].astype(np.int16)
    maxc = np.maximum(np.maximum(r, g), b)
    minc = np.minimum(np.minimum(r, g), b)
    sat = maxc - minc
    bright = (r + g + b) / 3.0
    return (sat <= 8) & (bright >= 225)


def dechecker(im):
    arr = np.array(im.convert("RGB"))
    bgcolor_mask = is_bg(arr)
    labeled, _ = ndimage.label(bgcolor_mask, structure=np.ones((3, 3)))
    border_labels = set()
    border_labels.update(np.unique(labeled[0, :]).tolist())
    border_labels.update(np.unique(labeled[-1, :]).tolist())
    border_labels.update(np.unique(labeled[:, 0]).tolist())
    border_labels.update(np.unique(labeled[:, -1]).tolist())
    border_labels.discard(0)
    bg_mask = np.isin(labeled, list(border_labels))
    alpha = np.where(bg_mask, 0, 255).astype(np.uint8)

    fg_mask = alpha > 0
    if fg_mask.any() and (~fg_mask).any():
        _, (iy, ix) = ndimage.distance_transform_edt(~fg_mask, return_indices=True)
        filled = arr[iy, ix]
        out_rgb = np.where(fg_mask[..., None], arr, filled)
    else:
        out_rgb = arr
    return Image.fromarray(np.dstack([out_rgb.astype(np.uint8), alpha]))


def process_sheet(name):
    im = Image.open(os.path.join(SRC_DIR, f"{name}.png"))
    w, h = im.size
    actual_scale = w / REQUESTED_CANVAS_W

    cleaned = dechecker(im)

    cell_w = w / 4.0
    cell_h = h / 2.0
    source_stand_height = REQUESTED_STAND_HEIGHT * actual_scale
    source_baseline_y = REQUESTED_BASELINE_Y * actual_scale
    source_center_x = cell_w / 2.0

    scale_factor = TARGET_STAND_HEIGHT / source_stand_height

    frames = []
    for row in range(2):
        for col in range(4):
            x0, x1 = round(col * cell_w), round((col + 1) * cell_w)
            y0, y1 = round(row * cell_h), round((row + 1) * cell_h)
            cell = cleaned.crop((x0, y0, x1, y1))

            scaled_w = max(1, round(cell.width * scale_factor))
            scaled_h = max(1, round(cell.height * scale_factor))
            scaled_cell = cell.resize((scaled_w, scaled_h), Image.LANCZOS)

            paste_x = round(TARGET_CENTER_X - source_center_x * scale_factor)
            paste_y = round(TARGET_BASELINE_Y - source_baseline_y * scale_factor)

            canvas = Image.new("RGBA", (TARGET_CANVAS, TARGET_CANVAS), (0, 0, 0, 0))
            canvas.paste(scaled_cell, (paste_x, paste_y), scaled_cell)
            frames.append(canvas)
    return frames


def main():
    for name, (dest_clip, keep) in CLIPS.items():
        frames = process_sheet(name)
        dest_dir = os.path.join(DEST_BASE, dest_clip, "east")
        os.makedirs(dest_dir, exist_ok=True)
        # Clear any stale frames beyond what this run writes (e.g. a previous
        # longer clip trimmed down), so nothing orphaned lingers unreferenced.
        for f in os.listdir(dest_dir):
            if f.startswith("frame_"):
                os.remove(os.path.join(dest_dir, f))
        for out_i, src_i in enumerate(keep):
            frames[src_i].save(os.path.join(dest_dir, f"frame_{out_i:03d}.png"))
        print(f"{name} -> {dest_dir} ({len(keep)} frames)")


if __name__ == "__main__":
    main()
