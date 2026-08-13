#!/usr/bin/env python3
"""Bring hand-drawn dialogue portraits into the game at the size and framing it
needs.

  <source folder>/hooshang_*.png  ->  assets/portraits/hooshang_*.png
  <source folder>/rumi_*.png      ->  assets/portraits/rumi_*.png

The delivered art is a 7-15 MB painted illustration. Three things have to happen
to it before it is a dialogue portrait, and all three are easy to get wrong by
hand across a dozen files.

SQUARE. DialogueBox's portrait frame is square (172x172 inside a 184x184
border). A non-square image dropped in unchanged is letterboxed by
`stretch_mode = KEEP_ASPECT_CENTERED` and sits in the frame with bars beside it.

FRAMED SO THE TWO CHARACTERS MATCH. Hooshang and Rumi speak one line apart in
the same banner, so their faces have to be the same size in it — otherwise one
of them reads as standing further away, which is a thing the scene never says.
The two source sets are nothing alike (Hooshang is a 4:5 bust, Rumi a 16:9
landscape with a lot of room around him), so each gets its own crop rule below,
both tuned to the same measured target.

512 PIXELS. The banner is deliberately NOT part of the 320x180 pixel-art
viewport: it is drawn on the window's own surface (systems/screen.gd), where the
frame is 172 real pixels at a 1280x720 window, 344 at 1440p and 516 fullscreen on
a 4K panel. 512 is crisp at every one of those, and ~0.5 MB instead of 13.

LANCZOS, because these are paintings and not pixel art. The halftone dot patterns
in both backgrounds are exactly the kind of high-frequency detail a box or
nearest downscale turns into moire.

Usage:  python3 tools/import_portraits.py "/path/to/portrait folder"
        (any folder holding hooshang_*.png and/or rumi_*.png)

The Portrait node's `texture_filter` must be LINEAR_WITH_MIPMAPS and the
portraits imported with mipmaps for this to resolve cleanly — the project default
is Nearest, which is right for the world and wrong for a painting minified 3x.
See scenes/ui/DialogueBox.tscn.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "portraits")

SIZE = 512

# --- the shared target ----------------------------------------------------
#
# Measured off Hooshang's crop, normalised to the 512px output. Everything else
# here exists to land Rumi on the same three numbers.
#
# Pupil-to-pupil is the anchor rather than head height, because the two of them
# are not the same shape: Rumi's turban and beard fill a frame while his FACE
# stays small, and matching silhouettes left him looking half a room further
# back. The face is what the player reads.
TARGET_EYE_SPAN = 95.0    # px between pupils
TARGET_EYE_Y = 250.0      # px from the top of the frame to the eye line
TARGET_FACE_X = 252.0     # px from the left of the frame to the face's centre

# --- Rumi -----------------------------------------------------------------
#
# Measured off assets 2816x1536 (all five share a framing — verified by
# cross-correlating the eye band, they agree within 1px). Re-measure these if the
# art is ever re-posed; everything below is derived.
RUMI_SRC = (2816, 1536)
RUMI_EYE_SPAN = 222.0     # source px between pupils
RUMI_EYE_Y = 648.0        # source y of the eye line
RUMI_FACE_X = 1339.0      # source x of the face's centre


def hooshang_crop(img: Image.Image) -> Image.Image:
    """The largest square, top-aligned.

    His art is already framed as a tight bust, and this lands within a few px of
    the target on its own: taking the square from the TOP keeps hair, face and
    collar — the part carrying the acting — and loses only the lower chest.
    """
    side = min(img.width, img.height)
    return img.crop((0, 0, side, side))


def rumi_crop(img: Image.Image) -> Image.Image:
    """A square around the face, sized so his eyes match Hooshang's.

    Zooms in about 2.3x on the delivered landscape. Some of the beard runs off
    the bottom edge at this distance, which is correct and not a loss: Hooshang's
    cardigan runs off his in exactly the same way, and a portrait that keeps the
    whole beard in frame is the one that looked like a different shot.
    """
    if (img.width, img.height) != RUMI_SRC:
        raise SystemExit("rumi source is %dx%d, expected %dx%d — re-measure the "
                         "constants at the top of this file"
                         % (img.width, img.height, *RUMI_SRC))
    side = RUMI_EYE_SPAN * SIZE / TARGET_EYE_SPAN
    left = RUMI_FACE_X - side * (TARGET_FACE_X / SIZE)
    top = RUMI_EYE_Y - side * (TARGET_EYE_Y / SIZE)
    box = (round(left), round(top), round(left + side), round(top + side))
    if box[0] < 0 or box[1] < 0 or box[2] > img.width or box[3] > img.height:
        raise SystemExit("the matched crop %s falls outside the source" % (box,))
    return img.crop(box)


RULES = {"hooshang_": hooshang_crop, "rumi_": rumi_crop}


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        raise SystemExit(2)
    src = sys.argv[1]
    names = sorted(f for f in os.listdir(src) if f.endswith(".png")
                   and any(f.startswith(p) for p in RULES))
    if not names:
        print("no hooshang_*.png or rumi_*.png in %s" % src)
        raise SystemExit(1)

    os.makedirs(OUT, exist_ok=True)
    for name in names:
        crop = next(fn for p, fn in RULES.items() if name.startswith(p))
        img = Image.open(os.path.join(src, name)).convert("RGBA")
        out = crop(img).resize((SIZE, SIZE), Image.LANCZOS)
        path = os.path.join(OUT, name)
        out.save(path, optimize=True)
        print("%-26s %4dx%-4d -> %dx%d  %.2fMB" % (
            name, img.width, img.height, SIZE, SIZE,
            os.path.getsize(path) / 1e6))


if __name__ == "__main__":
    main()
