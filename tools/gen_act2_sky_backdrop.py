#!/usr/bin/env python3
"""Act 2's world-spanning sky backdrop, cut from the user-supplied watercolor
landscape (assets/backdrop/act2_sky/source/act2_sky_watercolor.jpg).

ONE-OFF, NON-TILED SET-PIECE BACKDROP, in the sense LIGHTING.md and
experiments/act2_watercolor/README.md both already use that phrase for
SunShaft/WallPattern/the archway backdrop test: this is shown at (or near) its
own native resolution and never squeezed onto the 8px tile grid the rest of
the game is drawn on, so it keeps the source's soft watercolor bleed and
paper-grain texture — a nearest-neighbour pixel-art reduction is exactly what
would turn that softness to mud (see the README's own read on its "hard
bleed" experiment).

TWO PIECES, not one image, because the actual requirement ("extend the
background if a level stretches past it, but there is only one sun") cannot
be satisfied by a single static image or a naively repeating tile — a repeat
would repeat the sun. So the source is cut into:

  CENTER  — a band centred on the sun (measured directly: sampled the source
            pixel-by-pixel and found the sun's disc at x 956-1156 of the
            2088px-wide original, centre x=1056, comfortably inside the
            image's own horizontal middle). Placed exactly ONCE per world,
            centred on the world's own horizontal midpoint.
  EXTEND  — a band cut from the source's own LEFT edge (x 0-606), which is
            real painted cloud/mountain/foreground content but measurably
            clear of the sun (which starts at x=956) — not a flat colour
            filler. Tiled outward from both sides of CENTER as far as the
            world needs, mirrored on alternating copies so it does not read
            as one stamp repeating (the same rule this project's own tiled
            strip props — ConveyorBelt, GlassSpikes, SlideZone's floor — all
            follow for the same reason).

Both pieces are cut from the SAME source image at the SAME scale, so their
height matches exactly and EXTEND's own right edge (x=606, i.e. its right
edge in the ORIGINAL) sits directly against CENTER's left edge (x=606) with
no seam on the very first copy — only repeats past that first one can show a
seam, which mirroring softens.

Downsampled with LANCZOS, not nearest-neighbour — the one deliberate
exception to this project's pixel-art convention, same exemption
SunShaft/MoonWindow/the archway backdrop test already carry.

Re-run after editing: python3 tools/gen_act2_sky_backdrop.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "backdrop", "act2_sky", "source",
                   "act2_sky_watercolor.jpg")
OUT = os.path.join(ROOT, "assets", "backdrop", "act2_sky")

# Measured directly off the source (see header): the sun's disc spans x
# 956-1156 of the 2088px-wide original, centre 1056.
SUN_CENTER_X = 1056
# Half-width of the CENTER crop — wide enough to keep the sun comfortably
# framed by cloud on both sides rather than cropped tight to its edge.
CENTER_HALF_W = 450
# The EXTEND crop's width in the source, taken from the left edge up to
# (but not past) CENTER's own left edge, so the two abut with no gap.
EXTEND_W = SUN_CENTER_X - CENTER_HALF_W  # = 606

# Output scale: downsample by this factor from the source's native pixels.
# Chosen so CENTER lands at 400px wide in-game — wider than one 320px room
# (so it reads as a real presence, not a postage stamp) but not so large the
# EXTEND tiling is doing enormous amounts of work for a small world.
SCALE = 400.0 / (CENTER_HALF_W * 2)


def main():
    src = Image.open(SRC).convert("RGB")
    w, h = src.size

    center_box = (SUN_CENTER_X - CENTER_HALF_W, 0, SUN_CENTER_X + CENTER_HALF_W, h)
    extend_box = (0, 0, EXTEND_W, h)

    center = src.crop(center_box)
    extend = src.crop(extend_box)

    out_h = round(h * SCALE)
    center_out = center.resize((round(center.width * SCALE), out_h), Image.LANCZOS)
    extend_out = extend.resize((round(extend.width * SCALE), out_h), Image.LANCZOS)

    os.makedirs(OUT, exist_ok=True)
    center_path = os.path.join(OUT, "center.png")
    extend_path = os.path.join(OUT, "extend.png")
    center_out.save(center_path)
    extend_out.save(extend_path)
    print("wrote %s  %dx%d  (sun centred, shown once per world)"
          % (center_path, center_out.width, center_out.height))
    print("wrote %s  %dx%d  (tiled outward, mirrored on alternating copies)"
          % (extend_path, extend_out.width, extend_out.height))


if __name__ == "__main__":
    main()
