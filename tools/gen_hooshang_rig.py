#!/usr/bin/env python3
"""Rig Hooshang's SECOND portrait pass (the one cut from PixelLab contact
sheets by gen_hooshang_portraits.py) so it blinks and talks WITHOUT swapping
in a different picture per frame — same idea as the original
gen_portrait_frames.py, ported to this art's 256px canvas.

  assets/portraits/hooshang_*.png  ->  assets/portraits/anim/hooshang_*_{mouth,eyes}.png
                                       assets/portraits/anim/manifest.json

WHY THIS EXISTS INSTEAD OF THE LOOP SYSTEM THIS PROJECT ALSO HAS. The loop
system (gen_portrait_loops.py, assets/portraits/loops/) drives a face by
swapping in a DIFFERENT whole-frame picture per mouth position. That is fine
when every frame comes from one animation pass over a fixed head (Rumi's
loops, made by Pixellab's animate_image on a single portrait). It is NOT fine
when the frames are independent contact-sheet cells: measured directly, two
cells of the same sheet differ by a mean of 25-145/255 EVERYWHERE in the
frame, not just at the mouth — the forehead and collar move almost as much as
the lips do, because each cell is its own generation with its own head tilt
and shading, not a re-render of one fixed head. Swapping between them plays
back as the whole portrait flickering, not a face talking. That is what this
script replaces: a face built from exactly ONE rest picture per state, with
the mouth and eyes patched only within a small, fixed region of it — so
nothing outside those two small windows can ever move.

TWO DIFFERENT PATCHES FOR TWO DIFFERENT PROBLEMS. The mouth is DRAWN — a
growing cavity+teeth ellipse composited straight onto the rest still (see
_open_mouth) — because no cell on any sheet draws a clean, hand-free, matched-
lighting open mouth for every state, and a drawn oval is cheap and reads fine
at the ~172px this box actually renders a portrait at. The eyes are PATCHED
from a different cell of the SAME sheet (see _closed_face) — because unlike
the mouth, several sheets DO draw a genuinely lowered or shut pair of eyes
already, in a completely different pose, and that patch is small enough
(bounded on every side by dark eyebrow/lash linework) to hide the kind of
lighting mismatch that made whole-frame swapping look like flickering. A first
pass tried to WARP the eyes shut too — stretch a sliver of skin down over the
opening, gen_portrait_frames.py's technique — and it read as a smear rather
than a blink: there is only ~4-5px of clear skin above the eye on this art
(measured), not enough to stretch over a ~20px-tall opening without visible
distortion. Patched-in real art has no such floor.

THE MOUTH GEOMETRY IS gen_portrait_frames.py's, HALVED AND RE-MEASURED. That
script's paintings were 512px; these portraits are 256px, roughly the same
head-fill ratio, so its rough proportions were a starting point — but the
LANDMARKS (lip_y, mouth_x, eyes) are measured fresh on this art, not assumed,
because they do not match: the first measurement of `lip_y` used the
moustache's own top edge and was wrong (see FACE's comment for the doubled-
seam bug that produced), and this face's eyes run noticeably bigger relative
to the canvas than the old paintings' did. Measured once, off
hooshang_hesitant.png, and shared by all six states: every one of
gen_hooshang_portraits.py's rest frames comes off the same crop pipeline, so
they land on the same head position (checked: the sclera clusters at y
112-127 across all six).

CAVITY AND TEETH COLOURS ARE SAMPLED FROM THIS ART, NOT COPIED FROM THE OLD
ONE. The old script's mouth cavity (48, 20, 24) and teeth (196, 180, 170) were
picked for painterly warm-toned faces; this style's actual open-mouth pixels
(sampled off the contact sheets' own open-mouth cells before this script
existed) run darker and cooler in the cavity (~35, 8, 8) and greyer in the
teeth (~148, 147, 150) — using the old warm colours here would paint a mouth
that visibly does not match the ink linework this art uses everywhere else.

Every one of the six states shares one FACE landmark set (unlike
gen_portrait_frames.py's, which needed a `hooshang_shocked` exception because
that face was painted mid-gasp with the mouth already open): this pass's
`shocked` rest frame was deliberately picked with a closed mouth — see
gen_hooshang_portraits.py's POSES table — precisely so it would not need one.

Usage:  python3 tools/gen_hooshang_rig.py
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_hooshang_portraits import sheet_cell

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORTRAITS = os.path.join(ROOT, "assets", "portraits")
OUT = os.path.join(PORTRAITS, "anim")

SIZE = 256

STATES = ["hesitant", "dazed", "skeptical", "annoyed", "vulnerable", "shocked"]

## How open the mouth cavity is on each frame — no longer a literal jaw-slide
## distance (see _open_mouth), just the value its two ellipses scale from.
## Picked by rendering and looking, same as gen_portrait_frames.py's original
## [0, 7, 14, 21] was.
MOUTH_DROPS = [0, 6, 11, 16]
## How shut the eye is on each blink frame — a fraction, so this is
## resolution-independent and kept identical to the original.
BLINK_STEPS = [0.0, 0.55, 1.0]

## Measured off assets/portraits/hooshang_hesitant.png and shared by all six
## states (see the module docstring for why one set is enough). `lip_y` is the
## closed-mouth seam BELOW the moustache, not the moustache itself — the first
## measurement here used the moustache's own top edge (the obvious dark band)
## and it was wrong: the moustache sits on the upper lip and does not move
## when a jaw drops, so sliding it down along with the chin doubled it,
## smearing a grey band across the mouth. A gridded close-up crop found the
## real seam at y 188, a good 30px below where the moustache starts (158) and
## a few px below where it ends (~182) — same rule gen_portrait_frames.py's
## docstring states for the old paintings ("the oval also has to stop BELOW
## the moustache"), just not followed the first time through here. `eyes`
## gives each eye opening its own box, unlike an eyebrow-to-eyebrow span,
## because the two eyes do not sit close enough together here to share one
## useful lid patch.
FACE = {
    "lip_y": 188,
    "mouth_x": (82, 178),
    "eyes": [(74, 106, 108, 126), (152, 106, 186, 126)],
}

## Sampled by hand from this art's own open-mouth contact-sheet cells (dazed
## cell 1, shocked cell 1) rather than reused from the old painted portraits'
## warm palette — see the module docstring.
CAVITY_COLOR = (35, 8, 8, 255)
TEETH_COLOR = (148, 147, 150, 255)

## state -> (raw contact-sheet stem, cell index) of a pose with the eyes
## genuinely lowered, or None. Three of six sheets (hesitant's "normal" source,
## dazed, annoyed) draw the eyes fully SHUT somewhere in their 11 cells — the
## same cells gen_hooshang_portraits.py once used as the loop system's "blink"
## frame, before this file replaced that system for the reason the module
## docstring gives. Two more (skeptical, vulnerable) never draw the eyes fully
## closed, but do have a genuinely heavy-lidded squint (checked against every
## other cell on their sheets) that reads as a soft blink rather than a
## fully-open stare. `shocked` gets neither: its own heaviest-lidded cell (10)
## looks down and to the side instead of just lowering the lids, so patching
## it in put a blank, rolled-back-looking eye where a closed one should be —
## and a startled face not blinking is in character anyway, so it is left
## with no eyes rig at all (dialogue_box.gd already treats a missing "eyes"
## entry as "this face holds still," the same as a missing "blink" in the
## loop manifest).
BLINK_SOURCE = {
    "hesitant": ("normal", 6),
    "dazed": ("dazed", 4),
    "skeptical": ("skeptical", 6),
    "annoyed": ("annoyed", 2),
    "vulnerable": ("vulnerable", 8),
    "shocked": None,
}
## The region patched from the source cell onto the rest still, big enough to
## comfortably contain both eyes plus the strip crop rect `main()` derives
## from FACE["eyes"] (measured: that rect is x[67,193] y[98,134], so this
## patch overhangs it several px on every side rather than lining up exactly,
## which would leave a sliver of the ORIGINAL open eye showing at the rect's
## own edge in the "closed" frame).
EYE_PATCH_RECT = (55, 85, 205, 140)


def _open_mouth(im, lm, drop):
    """Draw a growing mouth cavity directly over the closed-mouth seam.

    gen_portrait_frames.py SLID the jaw — cropped everything below the lip
    line and pasted it back lower, so the chin visibly drops. That reads fine
    on a detailed painting with real lower-lip shading to carry along, but
    this art is flat cel-shading with a single one-pixel seam line standing in
    for "mouth closed": sliding it produced a doubled/smeared seam (the first
    attempt at this file), and the "put the lower lip back on top" step
    designed to hide that seam ended up re-drawing the CLOSED line on top of
    the open cavity, hiding the opening instead. Simpler and correct for this
    style: leave the chin alone and just grow an oval cavity — cheap, and
    exactly what a small 172px-tall dialogue portrait needs to read as
    "talking" at 8fps.
    """
    if drop <= 0:
        return im.copy()
    lip_y = lm["lip_y"]
    x0, x1 = lm["mouth_x"]
    cx = (x0 + x1) / 2.0
    half = (x1 - x0) / 2.0

    out = im.copy()
    cav = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(cav)
    d.ellipse([cx - half * 0.92, lip_y - drop * 0.35,
               cx + half * 0.92, lip_y + drop * 1.15], fill=CAVITY_COLOR)
    d.ellipse([cx - half * 0.74, lip_y - drop * 0.15,
               cx + half * 0.74, lip_y + drop * 0.55], fill=TEETH_COLOR)
    out.alpha_composite(cav.filter(ImageFilter.GaussianBlur(0.6)))
    return out


def _closed_face(im, source):
    """`im` with its eyes replaced by a genuinely lowered pair, patched in
    from a DIFFERENT cell of the same contact sheet rather than warped out of
    `im` itself.

    A stretched sliver of skin (the first attempt at this function) has almost
    nothing to work with — measured, the gap between eyebrow and lash line is
    only 4-5px — and stretching that thin a strip over a 20px-tall eye opening
    smears rather than closes it. This sheet already drew a genuinely
    lowered-lid pose in one of its other ten cells; patching THAT in, through
    the same feathered-rectangle technique gen_rumi_loops.py uses for Rumi's
    mouth/eye patches, reads as real art because it is real art. The two cells
    come from the same sheet and the same crop pipeline, so they share a head
    position and a backdrop colour — the risk gen_hooshang_portraits.py's own
    docstring raises about cross-cell jitter is a whole-face problem; a patch
    this small, bounded by dark eyebrow/lash silhouette on every side, hides
    the kind of small lighting mismatch that sank whole-frame swapping.
    """
    if source is None:
        return im.copy()
    sheet, index = source
    cell = sheet_cell(sheet, index)
    x0, y0, x1, y1 = EYE_PATCH_RECT
    patch = cell.crop((x0, y0, x1, y1))
    mask = Image.new("L", patch.size, 0)
    ImageDraw.Draw(mask).rectangle([6, 6, patch.size[0] - 6, patch.size[1] - 6], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(6))
    out = im.copy()
    out.paste(patch, (x0, y0), mask)
    return out


def _blink_frames(im, source):
    """rest -> partly-lowered -> closed, as a CROSSFADE between the unmodified
    still and _closed_face's patched version rather than an animated warp.
    Since the two images are identical everywhere outside the patched eye
    region, blending the whole frame is a no-op everywhere else — this is
    simpler than a partial-blend mask and gives the same result."""
    closed = _closed_face(im, source)
    return [Image.blend(im, closed, t) for t in BLINK_STEPS]


def _clamp_rect(x0, y0, x1, y1):
    return (max(0, int(x0)), max(0, int(y0)), min(SIZE, int(x1)), min(SIZE, int(y1)))


## Same import template gen_portrait_frames.py writes — see that file for why
## these settings (mipmaps on) matter for an overlay sitting on a minified
## portrait, and why this is written by the tool rather than by hand.
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
    path = os.path.join(OUT, filename + ".import")
    if os.path.exists(path):
        return
    import hashlib
    digest = hashlib.md5(filename.encode()).hexdigest()
    uid = "z" + digest[:12]
    with open(path, "w") as fh:
        fh.write(IMPORT_TEMPLATE % (uid, filename, digest, filename, filename, digest))


def _strip(frames, rect):
    x0, y0, x1, y1 = rect
    w, h = x1 - x0, y1 - y0
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f.crop(rect), (i * w, 0))
    return sheet, (x0, y0, w, h)


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = {}
    for state in STATES:
        name = "hooshang_%s" % state
        src = os.path.join(PORTRAITS, name + ".png")
        if not os.path.exists(src):
            print("  skip %s (no portrait)" % name)
            continue
        im = Image.open(src).convert("RGBA")
        lm = FACE
        entry = {}

        lip_y, (mx0, mx1) = lm["lip_y"], lm["mouth_x"]
        cx = (mx0 + mx1) / 2.0
        rect = _clamp_rect(cx - 76, lip_y - 6, cx + 76, lip_y + 50 + max(MOUTH_DROPS))
        sheet, place = _strip([_open_mouth(im, lm, d) for d in MOUTH_DROPS], rect)
        sheet.save(os.path.join(OUT, "%s_mouth.png" % name))
        _write_import("%s_mouth.png" % name)
        entry["mouth"] = {"rect": list(place), "frames": len(MOUTH_DROPS)}

        source = BLINK_SOURCE.get(state)
        if source is not None:
            eyes = lm["eyes"]
            rect = _clamp_rect(min(e[0] for e in eyes) - 7, min(e[1] for e in eyes) - 8,
                               max(e[2] for e in eyes) + 7, max(e[3] for e in eyes) + 8)
            sheet, place = _strip(_blink_frames(im, source), rect)
            sheet.save(os.path.join(OUT, "%s_eyes.png" % name))
            _write_import("%s_eyes.png" % name)
            entry["eyes"] = {"rect": list(place), "frames": len(BLINK_STEPS)}

        manifest[name] = entry
        print("  %-22s mouth rect=%s eyes=%s" % (
            name, entry["mouth"]["rect"], entry["eyes"]["rect"] if "eyes" in entry else "-"))

    man_path = os.path.join(OUT, "manifest.json")
    existing = {}
    if os.path.exists(man_path):
        existing = json.load(open(man_path))
    existing.update(manifest)
    with open(man_path, "w") as fh:
        json.dump(existing, fh, indent=2, sort_keys=True)
    print("wrote %d rigs to %s" % (len(manifest), OUT))


if __name__ == "__main__":
    main()
