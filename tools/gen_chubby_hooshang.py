#!/usr/bin/env python3
"""Hooshang, thickened: the sprite pack warped into a heavier man.

Source: assets/hooshang_sprites/animations/<Clip>/east/frame_*.png — the thin
pack, which is itself part generated (see gen_wall_slide.py).
Output: assets/hooshang_sprites/chubby/<Clip>/east/frame_*.png, same names,
same 88x88 canvas, same palette. assets/hooshang_frames.tres points at THESE.

Why a warp and not a redraw. There are 40 frames across eight clips in the
.tres and every one of them is a pose of the same man; regenerating them would
mean 40 independent generations agreeing with each other about how fat he is,
frame to frame, in poses that already exist and already read. A deterministic
warp cannot disagree with itself. It also means the day the thin pack is
re-cut, one command puts the weight back on — which is the reason the thin
frames are left in place as the source rather than being overwritten.

**Run this after gen_wall_slide.py**, which writes into the thin pack and knows
nothing about this one.

Four things here are not a horizontal resize, and each is a way he goes wrong:

- **Weight is added in PIXELS, not in percent.** A flat 1.6x on every row is
  right for the belly of a standing frame and absurd four rows later in a
  running one, where the row also contains a thrown-out arm and a trailing leg
  — the same multiplier then flings the limbs half a body-width off him and he
  reads as melting rather than as heavy. The profile below is an ADDED WIDTH
  per row (WEIGHT), converted to a per-row scale against that row's own drawn
  width, so a 6px belly row and a 24px stride row both gain the same handful of
  pixels of fat. MAX_GAIN then catches the other end: a 3px row of fingertips
  must not double because 3px is small.

- **The anchor is the body's own centreline, smoothed down the sprite.** Each
  row is scaled about its own middle, so nothing drifts sideways and his boots
  stay over the hitbox — but a raw per-row middle jumps by a pixel or two
  wherever an arm enters the silhouette, and scaling neighbouring rows about
  anchors two pixels apart shears his outline into a staircase. The centres are
  averaged over CENTRE_SMOOTH rows first, which costs nothing and makes the
  edge continuous.

- **The belly leans FORWARD.** He is drawn in profile facing +x, so a purely
  symmetric bulge puts as much of him behind his spine as in front of it, which
  is a barrel, not a gut. BELLY_LEAN shifts the anchor backwards through the
  torso band only — the growth then goes mostly out the front — and returns to
  zero at the head and the feet, where a lean would move his face and his
  boots off the box.

- **The resample is NEAREST and row-wise.** Anything smoother invents colours
  between two flat pixel-art shades, and at 0.39 scale a fringe of invented
  midtones is exactly the mush the project's art direction rules out. Nearest
  duplicates columns instead, which is what a pixel artist widening a sprite
  does by hand. It is also why the palette count is unchanged, which is the
  cheapest check that this did not quietly resample him.

The bands are placed by NORMALISED height (crown = 0, lowest boot = 1) rather
than by texture row, because the pack's poses are not the same height: he
measures 43-45 rows standing and 34 crouched in Wall_Land, so a fixed row for
"belly" lands on the crouch's shoulders. Normalising makes one profile fit
every clip, which is the only reason a single table can cover eight of them.

Re-run after editing:
    python3 tools/gen_chubby_hooshang.py [--preview OUT.png] [--all-directions]
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "hooshang_sprites")
THIN = os.path.join(SPRITES, "animations")
FAT = os.path.join(SPRITES, "chubby")

## The clips assets/hooshang_frames.tres actually plays. Two more sit in the
## thin pack (Dash, Two-Footed_Jump) and nothing references them: "dash" in the
## .tres is the Slide clip. They are warped anyway when --all-directions is
## passed, so the folder never half-matches.
##
## Climb/east is the one clip in this list that is NOT actually east-facing —
## it holds a BACK view (Pixellab's "north" rotation, generated via
## animate_character), because climbing a ladder means facing INTO it, away
## from the camera, and a side profile cannot show that. It lives under
## "east" anyway rather than a "north" folder of its own, so this scanner and
## the .tres path scheme need no special case for one clip out of nine.
CLIPS = ["Breathing_Idle", "Falling", "Jumping", "Running", "Slide",
         "Wall_Jump", "Wall_Land", "Wall_Slide", "Climb"]

## A pixel is "him" at or above this alpha. The pack is hard-cut already
## (gen_wall_slide.py's ALPHA_CUT), so this only has to ignore stray dust.
OPAQUE = 16

## Added drawn width, in SOURCE px, by normalised height down the body.
##
## Read it as a tape measure: at the belly he gains BELLY px across, which on
## Breathing_Idle's 11px waist is a 65% widening and on Running's 24px stride
## row is 27%. The face is deliberately the cheapest band — a jaw and a neck,
## not a wider skull — because the head is the one part a viewer measures him
## against, and widening it makes him a different man rather than a heavier one.
##
## Landmarks measured on Breathing_Idle/east/frame_000 (drawn rows 23..66):
## crown 0.00, eyes 0.14, jaw 0.25, shoulders 0.32, chest 0.40, waist 0.52,
## hips 0.63, thigh 0.74, calf 0.86, boot 1.00.
WEIGHT = [
    (0.00, 0.3),   # crown — the hair silhouette barely moves
    (0.14, 0.7),   # cheeks
    (0.25, 1.3),   # jaw and jowls
    (0.32, 1.8),   # neck into the collar
    (0.40, 3.8),   # chest
    (0.52, 7.2),   # the belly, and the widest he gets
    (0.63, 5.6),   # hips
    (0.74, 3.2),   # thighs
    (0.86, 1.3),   # calves
    (1.00, 0.5),   # boots, which must stay under him
]

## Ceiling on the per-row scale. Without it a 3px row of fingers or a 2px row
## of hair takes the full added width and triples.
MAX_GAIN = 1.75

## How far the anchor slides BACKWARDS (against facing) per band, source px, so
## the growth comes out the front. Zero at both ends on purpose: a lean at the
## crown swings his face off the hitbox and a lean at the boots walks him off it.
BELLY_LEAN = [
    (0.00, 0.0),
    (0.32, 0.4),
    (0.52, 1.5),   # peak, and the same row the belly peaks on
    (0.74, 0.7),
    (1.00, 0.0),
]

## Rows averaged into each row's centreline. Five is two either side: enough to
## swallow an arm entering the silhouette, short enough that a real lean (the
## wall-slide tuck) still bends the anchor with him.
CENTRE_SMOOTH = 5

## Clips registered by their FRONT edge instead of by the centreline.
##
## Wall_Slide is drawn with his palm on the wall — gen_wall_slide.py pins those
## frames to WALL_X for exactly that reason — so a bulge spread evenly about his
## middle pushes the hand three source px past the wall face and his fingers
## come out inside the brick. Pinning the right edge puts every added pixel on
## the other side of him, which is also what a heavy man against a wall does.
PIN_RIGHT = {"Wall_Slide"}


def _ramp(table, t):
    """Linear interpolation through a (position, value) table."""
    ts = [p for p, _ in table]
    vs = [v for _, v in table]
    return float(np.interp(t, ts, vs))


def _smooth(values, valid, span):
    """Moving average of `values` over the rows flagged in `valid`."""
    out = values.copy()
    half = span // 2
    idx = np.where(valid)[0]
    for i in idx:
        lo, hi = max(0, i - half), min(len(values), i + half + 1)
        window = [values[j] for j in range(lo, hi) if valid[j]]
        out[i] = float(np.mean(window))
    return out


def _pin_right(thin, fat):
    """Slide `fat` so its rightmost drawn column sits where `thin`'s did."""
    a = np.array(thin.convert("RGBA"))[..., 3] >= OPAQUE
    b = np.array(fat)[..., 3] >= OPAQUE
    if not a.any() or not b.any():
        return fat
    shift = int(np.where(a.any(axis=0))[0][-1] - np.where(b.any(axis=0))[0][-1])
    if shift == 0:
        return fat
    out = np.zeros_like(np.array(fat))
    src = np.array(fat)
    if shift < 0:
        out[:, :shift] = src[:, -shift:]
    else:
        out[:, shift:] = src[:, :-shift]
    return Image.fromarray(out)


def chubbify(img):
    """One frame -> the same frame with the weight on. 88x88 in, 88x88 out."""
    src = np.array(img.convert("RGBA"))
    h, w = src.shape[:2]
    solid = src[..., 3] >= OPAQUE
    rows = np.where(solid.any(axis=1))[0]
    if len(rows) == 0:
        return img.copy(), 0.0
    top, bot = int(rows[0]), int(rows[-1])
    span = max(1, bot - top)

    # Per-row drawn extent, centreline and the scale that band asks for.
    centre = np.zeros(h)
    gain = np.ones(h)
    lean = np.zeros(h)
    valid = np.zeros(h, dtype=bool)
    for y in rows:
        xs = np.where(solid[y])[0]
        x0, x1 = int(xs[0]), int(xs[-1])
        width = x1 - x0 + 1
        t = (y - top) / span
        centre[y] = (x0 + x1) * 0.5
        gain[y] = min(MAX_GAIN, 1.0 + _ramp(WEIGHT, t) / width)
        lean[y] = _ramp(BELLY_LEAN, t)
        valid[y] = True
    centre = _smooth(centre, valid, CENTRE_SMOOTH)
    gain = _smooth(gain, valid, 3)

    out = np.zeros_like(src)
    grown = 0.0
    for y in rows:
        anchor = centre[y] - lean[y]
        g = gain[y]
        # Where each OUTPUT column reads from. Columns whose source lands off
        # the row are left transparent, which they already are.
        cols = np.arange(w, dtype=np.float32)
        srcx = np.rint(anchor + (cols - anchor) / g).astype(np.int32)
        keep = (srcx >= 0) & (srcx < w)
        out[y, keep] = src[y, srcx[keep]]
        xs = np.where(solid[y])[0]
        grown = max(grown, (xs[-1] - xs[0] + 1) * (g - 1.0))

    kept = np.where(out[..., 3] >= OPAQUE)[1]
    if len(kept) and (kept.min() < 1 or kept.max() > w - 2):
        raise SystemExit("warped body reached the canvas edge — widen CANVAS")
    return Image.fromarray(out), grown


def _drawn_width(img):
    a = np.array(img.convert("RGBA"))[..., 3] >= OPAQUE
    if not a.any():
        return 0
    xs = np.where(a.any(axis=0))[0]
    return int(xs[-1] - xs[0] + 1)


def directions(clip, all_dirs):
    root = os.path.join(THIN, clip)
    if not os.path.isdir(root):
        return []
    names = sorted(d for d in os.listdir(root)
                   if os.path.isdir(os.path.join(root, d)))
    return names if all_dirs else [d for d in names if d == "east"]


def build(all_dirs=False):
    """Warp every frame. Returns [(relative path, thin, fat)] in play order."""
    made = []
    clips = CLIPS + (["Dash", "Two-Footed_Jump"] if all_dirs else [])
    for clip in clips:
        for face in directions(clip, all_dirs):
            src_dir = os.path.join(THIN, clip, face)
            dst_dir = os.path.join(FAT, clip, face)
            os.makedirs(dst_dir, exist_ok=True)
            for name in sorted(f for f in os.listdir(src_dir)
                               if f.endswith(".png")):
                thin = Image.open(os.path.join(src_dir, name))
                fat, _ = chubbify(thin)
                if clip in PIN_RIGHT:
                    fat = _pin_right(thin, fat)
                fat.save(os.path.join(dst_dir, name))
                made.append((os.path.join(clip, face, name), thin, fat))
    return made


def preview(made, path, zoom=6):
    """Thin over fat, at 6x on office dark, with the hitbox drawn on both.

    The only questions worth asking of this pass are whether he reads as a
    heavier man and whether his boots still stand over his box, and neither is
    answerable from a transparent PNG in an image viewer. One column per frame,
    the thin pack on the top row and the warped one under it.
    """
    cells = [(t, f) for _, t, f in made]
    size = 88 * zoom
    pad = 4
    out = Image.new("RGBA", (len(cells) * (size + pad) + pad,
                             size * 2 + pad * 3), (24, 26, 32, 255))
    for i, pair in enumerate(cells):
        x = pad + i * (size + pad)
        for row, im in enumerate(pair):
            y = pad + row * (size + pad)
            out.alpha_composite(im.convert("RGBA").resize(
                (size, size), Image.NEAREST), (x, y))
            px = out.load()
            for ty in range(88):
                for tx in range(88):
                    # Hooshang.tscn: offset (0,-7), scale 0.39, box 8x12 ->
                    # world (0.39*(tx-44), 0.39*(ty-51)).
                    dx, dy = abs(tx - 44) * 0.39, abs(ty - 51) * 0.39
                    if dx > 4.6 or dy > 6.4:
                        continue
                    if abs(dx - 4.5) > 0.25 and abs(dy - 6.0) > 0.25:
                        continue
                    for k in range(zoom):
                        px[x + tx * zoom + k, y + ty * zoom] = (90, 200, 120, 255)
                        px[x + tx * zoom, y + ty * zoom + k] = (90, 200, 120, 255)
    out.save(path)


def main():
    all_dirs = "--all-directions" in sys.argv
    made = build(all_dirs)
    for rel, thin, fat in made:
        tw, fw = _drawn_width(thin), _drawn_width(fat)
        print("%-38s %2d -> %2d px  (+%d)" % (rel, tw, fw, fw - tw))
    widest = max(_drawn_width(f) for _, _, f in made)
    print("%d frames, widest drawn %d px (= %.2f px on screen at 0.39)"
          % (len(made), widest, widest * 0.39))
    if "--preview" in sys.argv:
        dest = sys.argv[sys.argv.index("--preview") + 1]
        preview(made, dest)
        print("wrote preview %s" % dest)


if __name__ == "__main__":
    main()
