#!/usr/bin/env python3
"""Rig the painted dialogue portraits so they blink and talk, Celeste-style.

  assets/portraits/hooshang_*.png  ->  assets/portraits/anim/hooshang_*_{mouth,eyes}.png
                                       assets/portraits/anim/manifest.json

Celeste's talking heads are not a drawn animation per line: they are a face with
a handful of mouth positions and a blink, cycled while the typewriter runs. That
is what this builds, except the faces here are 512px PAINTINGS rather than pixel
art, so the frames are WARPED out of the existing art instead of drawn. Nothing
new is illustrated and no portrait file is touched — this only adds overlays.

PATCHES, NOT WHOLE FACES. Each frame is cropped to just the region that moves
(a jaw box, an eye box) and drawn on top of the unchanged portrait by
DialogueBox. Baking whole 512px frames instead would be ~9 MB of near-identical
paintings, and every one of them would have to be re-exported the next time a
portrait is re-cut. The rects live in manifest.json so the box can place them.

THE JAW DROPS, THE FACE DOES NOT. `_open_mouth` slides the jaw down and fills
the gap it leaves with a mouth cavity. The slide is composited through a
FEATHERED OVAL over the chin, which is the whole trick: the first pass shifted
the full-width band under the lip line and took the shirt collar and both cheeks
with it, leaving a hard seam straight across the face. The oval also has to stop
BELOW the moustache (its top edge sits under the lip line, and the blur is
budgeted for) or his moustache slides down his chin as he speaks.

THE LID IS STRETCHED FROM A SIX-PIXEL STRIP. `_blink` covers the eye with skin
taken from just above it. There is very little to take: on these paintings the
brow sits ~6px over the eye opening, and a taller source strip pulls the eyebrow
down over the eye — which reads as a scowl building through every blink rather
than a blink.

FRAME 0 IS ALWAYS THE UNCHANGED ART. Both strips start on a rest frame that is
a straight crop of the portrait, so DialogueBox can leave an overlay showing at
frame 0 rather than having to hide and show it.

Usage:  python3 tools/gen_portrait_frames.py
"""
import json
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORTRAITS = os.path.join(ROOT, "assets", "portraits")
OUT = os.path.join(PORTRAITS, "anim")

SIZE = 512

# How far the jaw travels on each mouth frame, in source pixels. Four positions
# is what Celeste-scale lip flap needs: a rest and three openings, picked at
# random while typing. More positions are not more readable at the size the
# banner draws this (172px) — they just cost frames.
MOUTH_DROPS = [0, 7, 14, 21]
# How shut the eye is on each blink frame. Three is enough for a blink that
# lands: it is over in about a tenth of a second either way.
BLINK_STEPS = [0.0, 0.55, 1.0]


# --- landmarks -------------------------------------------------------------
#
# Measured off each painting. Five of the six portraits were delivered in the
# same framing and share their numbers; the two that do not are the interesting
# ones, and both are commented where they differ.
#
#   lip_y    the closed-mouth seam — everything below it is jaw
#   mouth_x  the corners of the mouth
#   teeth    draw an upper tooth row into the cavity (see `shocked`)
#   eyes     the eye OPENING of each eye, as x0, y0, x1, y1
FACE = {
    "lip_y": 386,
    "mouth_x": (205, 312),
    "teeth": True,
    "eyes": [(186, 247, 247, 264), (274, 247, 337, 264)],
}

LANDMARKS = {
    "hooshang_annoyed": FACE,
    "hooshang_hesitant": FACE,
    "hooshang_skeptical": FACE,
    "hooshang_vulnerable": FACE,
    # Already drawn mid-gasp, mouth open on a full set of teeth. The seam is
    # therefore taken UNDER the lower teeth, so speaking drags those down with
    # the jaw and opens dark between the two rows — which is what a jaw does.
    # `teeth` is off for the same reason: painting a tooth row into the cavity
    # would put a second one over the pair already in the art.
    "hooshang_shocked": {
        "lip_y": 390,
        "mouth_x": (210, 305),
        "teeth": False,
        "eyes": [(178, 238, 250, 263), (278, 238, 345, 263)],
    },
    # `hooshang_dazed` IS DELIBERATELY NOT RIGGED, and should stay that way
    # unless it is repainted. It is the waking shot: a 3/4 view with his hand at
    # his head, framed so tightly that the mouth runs off the edge of the picture
    # and only one eye is in frame — and that eye is TILTED, sloping up toward
    # the temple. Both warps here are axis-aligned, so the stretched lid crosses
    # the eye line at an angle instead of following it: it leaves sclera showing
    # under a lid that is nominally shut, and pulls a hard-edged bright patch of
    # temple skin down beside the brow. A face with no blink reads as stillness;
    # a face with a broken one reads as a bug, so this one is left alone.
    #
    # Nothing else has to know: DialogueBox treats "no manifest entry" as "hold
    # the painting still", which is the same path every un-rigged portrait
    # (all of Rumi's) already takes.
}


def _jaw_mask(lip_y, cx):
    """The oval the jaw is allowed to move inside — feathered, so there is no
    seam where moved pixels meet still ones."""
    m = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(m).ellipse([cx - 100, lip_y + 4, cx + 100, lip_y + 112], fill=255)
    return m.filter(ImageFilter.GaussianBlur(18))


def _open_mouth(im, lm, drop):
    if drop <= 0:
        return im.copy()
    lip_y = lm["lip_y"]
    x0, x1 = lm["mouth_x"]
    cx = (x0 + x1) / 2.0
    half = (x1 - x0) / 2.0

    # 1. the jaw slides down, inside the oval and nowhere else
    shifted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shifted.paste(im.crop((0, lip_y - 2, SIZE, SIZE)), (0, lip_y - 2 + drop))
    out = Image.composite(shifted, im.copy(), _jaw_mask(lip_y, cx))

    # 2. the cavity it opened up, only ever as tall as the jaw actually moved
    cav = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(cav)
    d.ellipse([cx - half * 0.94, lip_y - drop * 0.15,
               cx + half * 0.94, lip_y + drop * 0.95], fill=(48, 20, 24, 255))
    if lm.get("teeth", True):
        d.ellipse([cx - half * 0.80, lip_y - drop * 0.10,
                   cx + half * 0.80, lip_y + drop * 0.30], fill=(196, 180, 170, 255))
    out.alpha_composite(cav.filter(ImageFilter.GaussianBlur(2.0)))

    # 3. the lower lip, put back on top so it rides the new jaw line rather
    #    than being swallowed by the cavity drawn over it
    lip = im.crop((x0 - 34, lip_y - 1, x1 + 34, lip_y + 22))
    lm_mask = Image.new("L", lip.size, 0)
    ImageDraw.Draw(lm_mask).ellipse([0, -8, lip.size[0], lip.size[1] + 4], fill=255)
    out.paste(lip, (x0 - 34, lip_y - 1 + drop), lm_mask.filter(ImageFilter.GaussianBlur(4)))
    return out


def _blink(im, eyes, t):
    if t <= 0:
        return im.copy()
    out = im.copy()
    for x0, y0, x1, y1 in eyes:
        w, h = x1 - x0, y1 - y0
        lid_h = max(1, int(round(t * h)))
        # Six pixels of lid skin, stretched down over the opening. Taking more
        # takes eyebrow with it — see the module docstring.
        lid = im.crop((x0 - 4, y0 - 6, x1 + 4, y0 + 1)).resize((w + 8, lid_h + 3), Image.LANCZOS)
        m = Image.new("L", lid.size, 0)
        ImageDraw.Draw(m).ellipse([-6, -lid_h, lid.size[0] + 6, lid.size[1]], fill=255)
        out.paste(lid, (x0 - 4, y0), m.filter(ImageFilter.GaussianBlur(1.6)))
        # the lash line closing over it, fading in with the lid
        lash = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        ly = y0 + lid_h
        ImageDraw.Draw(lash).arc([x0 - 3, ly - 7, x1 + 3, ly + 5],
                                 start=185, end=355, fill=(52, 32, 28, int(235 * t)), width=3)
        out.alpha_composite(lash.filter(ImageFilter.GaussianBlur(0.8)))
    return out


def _clamp_rect(x0, y0, x1, y1):
    return (max(0, int(x0)), max(0, int(y0)), min(SIZE, int(x1)), min(SIZE, int(y1)))


# Godot's import settings for an overlay, matching what the portraits
# themselves are imported with (see tools/import_portraits.py).
#
# MIPMAPS ARE THE POINT. An overlay sits directly on top of a mipmapped painting
# minified to a third of its size; imported at the project default — Nearest, no
# mipmaps, which is right for the 8px world and wrong for this — the patch
# aliases into sparkle while the face under it stays smooth, and the join is
# visible as a rectangle around his mouth. These are written by the tool rather
# than set by hand in the editor so a fresh checkout gets them.
IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://%s"
path="res://.godot/imported/%s-%s.ctex"
metadata={
"vram_texture": false
}

[deps]

source_file="res://assets/portraits/anim/%s"
dest_files=["res://.godot/imported/%s-%s.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def _write_import(filename):
    """Write `<file>.png.import` unless one is already there.

    Left alone if it exists: Godot rewrites these on import with a real uid and
    content hash, and clobbering that on every run would dirty the repo and
    force a re-import of art that has not changed.
    """
    path = os.path.join(OUT, filename + ".import")
    if os.path.exists(path):
        return
    import hashlib
    digest = hashlib.md5(filename.encode()).hexdigest()
    uid = "z" + digest[:12]
    with open(path, "w") as fh:
        fh.write(IMPORT_TEMPLATE % (uid, filename, digest, filename, filename, digest))


def _strip(frames, rect):
    """Crop every frame to `rect` and lay them out left to right."""
    x0, y0, x1, y1 = rect
    w, h = x1 - x0, y1 - y0
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f.crop(rect), (i * w, 0))
    return sheet, (x0, y0, w, h)


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = {}
    for name, lm in sorted(LANDMARKS.items()):
        src = os.path.join(PORTRAITS, name + ".png")
        if not os.path.exists(src):
            print("  skip %s (no portrait)" % name)
            continue
        im = Image.open(src).convert("RGBA")
        entry = {}

        if "lip_y" in lm:
            lip_y, (mx0, mx1) = lm["lip_y"], lm["mouth_x"]
            cx = (mx0 + mx1) / 2.0
            # Wider than the feathered oval actually reaches (its blur carries
            # ~36px past its edge), and tall enough for the lowest jaw position.
            # The margin is not slack: it means every frame's BORDER pixels are
            # untouched crop, identical across the strip, so the mipmaps below
            # can bleed one frame into the next without it showing.
            rect = _clamp_rect(cx - 152, lip_y - 12, cx + 152, lip_y + 135 + max(MOUTH_DROPS))
            sheet, place = _strip([_open_mouth(im, lm, d) for d in MOUTH_DROPS], rect)
            sheet.save(os.path.join(OUT, "%s_mouth.png" % name))
            _write_import("%s_mouth.png" % name)
            entry["mouth"] = {"rect": list(place), "frames": len(MOUTH_DROPS)}

        eyes = lm["eyes"]
        rect = _clamp_rect(min(e[0] for e in eyes) - 14, min(e[1] for e in eyes) - 16,
                           max(e[2] for e in eyes) + 14, max(e[3] for e in eyes) + 16)
        sheet, place = _strip([_blink(im, eyes, t) for t in BLINK_STEPS], rect)
        sheet.save(os.path.join(OUT, "%s_eyes.png" % name))
        _write_import("%s_eyes.png" % name)
        entry["eyes"] = {"rect": list(place), "frames": len(BLINK_STEPS)}

        manifest[name] = entry
        print("  %-22s mouth=%s eyes=%s" % (name, "yes" if "mouth" in entry else "-", "yes"))

    with open(os.path.join(OUT, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)
    print("wrote %d rigs to %s" % (len(manifest), OUT))


if __name__ == "__main__":
    main()
