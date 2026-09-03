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
            pixel-by-pixel and found the sun's disc at x 901-1182 of the
            2088px-wide original, centre x=1042, comfortably inside the
            image's own horizontal middle). Placed exactly ONCE per world,
            centred on the world's own horizontal midpoint.
  EXTEND  — a band cut from the source's own LEFT edge (x 0-EXTEND_W), which
            is real painted cloud/sky content but measurably clear of the sun
            (which starts at x=901) — not a flat colour filler. Tiled outward
            from both sides of CENTER as far as the world needs, mirrored on
            alternating copies so it does not read as one stamp repeating
            (the same rule this project's own tiled strip props —
            ConveyorBelt, GlassSpikes, SlideZone's floor — all follow for the
            same reason).

Both pieces are cut from the SAME source image at the SAME scale and the SAME
vertical crop, so their height matches exactly and EXTEND's own right edge
(x=EXTEND_W in the ORIGINAL) sits directly against CENTER's own left edge
(SUN_CENTER_X - CENTER_HALF_W, the same x) with no seam on the very first
copy — only repeats past that first one can show a seam, which mirroring
softens.

Downsampled with LANCZOS, not nearest-neighbour — the one deliberate
exception to this project's pixel-art convention, same exemption
SunShaft/MoonWindow/the archway backdrop test already carry.

VERTICAL CROP EXCLUDES THE MOUNTAINS ENTIRELY, AND PADS WITH FLAT SKY
(2026-09, CLEAR-SKY-AT-THE-FLOOR PASS). Earlier passes cropped the FULL
source height (0 to 2048, mountains and desert reflection included) and
placed it so the mountain ridge lined up with the room's own floor
(act2_sky_backdrop.gd's old GROUND_LINE_Y/ground_offset_y scheme) — on the
theory that the strip of plain sky between the clouds and the ridge would
read as "clear sky at the floor". Measured directly, that strip is real but
THIN and IRREGULAR: scanning every column actually used by CENTER+EXTEND
(x 0-1842) for the tallest mountain peak and the lowest cloud wisp anywhere
in that range, the only row band that is genuinely clear SKY at every single
column is y 928-1058 (130px, in source pixels) — at SCALE 0.25 that is
~32px in-game, nowhere near the "at least 100px from the floor" the room
actually needs, and some individual columns come far closer than the
130px band suggests (a cloud wisp and a mountain peak, at DIFFERENT x
positions, land within single digits of px of each other in row-space —
there is no way to buy a big honest gap just by sliding the crop up or
down).

So this pass stopped trying to find one: the crop's bottom edge is now
CROP_BOTTOM_SRC (1000, comfortably inside the verified 928-1058 all-clear
band, never reaching the mountains at all — they are cropped away and never
rendered, which costs nothing since they were always hidden below the floor
anyway), and PAD_PX rows are appended below that to buy the rest of the
100px+ clear-sky margin the room needs.

THE PAD IS REAL HARVESTED SKY TEXTURE, NOT A FLAT COLOUR (2026-09, GRAIN
PASS). A flat-colour pad was the first attempt here and was rejected on
review: side by side against the source's own paper-grain texture it reads
as visibly, uniformly smoother — a flat card stuck under a watercolor
painting — even though the FLAT COLOUR matched fine (see the two reference
crops that prompted this pass). Mirroring the crop's own bottom rows
downward was tried before THAT and rejected for a different reason: mirror
anything tall enough to cover PAD_PX and it reaches back up into the cloud
wisps, printing a second, upside-down cloud near the floor.

The fix is SWATCH_TOP/SWATCH_BOTTOM: a second, unrelated patch of the same
painting (source rows 100-450), verified clear of any cloud/sun pixel at
every column in x 0-1842 (the topmost real cloud pixel anywhere in that
range is row 491 — checked directly, not assumed) and so also clear of any
directional feature at all, being plain sky. That real grain is (a)
colour-matched to CENTER's own bottom-edge tone with a single flat RGB
offset (a per-pixel additive shift — measured ~21/7/3 warmer needed; the
shift is small because the two regions are already close in tone, and it
preserves the swatch's own relative grain/noise since every pixel moves by
the same amount), computed ONCE from CENTER and reused for EXTEND's swatch
too rather than matched per piece (the two sit edge to edge in-game; two
independently matched offsets could drift apart by a visible amount even if
each looked fine alone), and then (b) TILED downward to fill PAD_PX,
alternating a vertical mirror each copy —
the same "no single stamp repeats" rule this file's own EXTEND tiling and
this project's other repeating strips (ConveyorBelt, GlassSpikes, SlideZone)
already follow, applied on the vertical axis instead of the horizontal one.
Checked at native resolution: no visible seam at either the natural-crop/pad
join or the internal tile-repeat join — grain has no long-range structure
for a repeat to expose, unlike a cloud silhouette.

Re-run after editing: python3 tools/gen_act2_sky_backdrop.py
"""
import os

from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "backdrop", "act2_sky", "source",
                   "act2_sky_watercolor.jpg")
OUT = os.path.join(ROOT, "assets", "backdrop", "act2_sky")

# Measured directly off the source (see header): the sun's disc spans x
# 901-1182 of the 2088px-wide original (diameter 281px), centre 1042.
SUN_CENTER_X = 1042
# Half-width of the CENTER crop, chosen (ZOOM-OUT PASS, 2026-09) so the sun's
# 281px disc lands at ~17.6% of CENTER's fixed 400px in-game width rather
# than the ~31% an earlier, narrower crop (450) produced — see SCALE below,
# which is derived FROM this, so widening the crop is what "zooming out"
# means here. SUN_CENTER_X (1042) is the hard ceiling (EXTEND_W hits 0 at
# 1042, see its own comment).
CENTER_HALF_W = 800
# The EXTEND crop's width in the source, taken from the left edge up to
# (but not past) CENTER's own left edge, so the two abut with no gap. Shrinks
# as CENTER_HALF_W grows (it is the same source pixels either way — widening
# CENTER eats directly into the margin EXTEND used to have) and hits 0 if
# CENTER_HALF_W ever reaches SUN_CENTER_X.
EXTEND_W = SUN_CENTER_X - CENTER_HALF_W  # = 242

# Output scale: downsample by this factor from the source's native pixels.
# Chosen so CENTER lands at 400px wide in-game — wider than one 320px room
# (so it reads as a real presence, not a postage stamp) but not so large the
# EXTEND tiling is doing enormous amounts of work for a small world.
SCALE = 400.0 / (CENTER_HALF_W * 2)

# Where the vertical crop stops, in SOURCE pixels — CLEAR-SKY-AT-THE-FLOOR
# PASS (see header). Verified directly: sampling every column in x 0-1842
# (every column CENTER or EXTEND actually uses) for the lowest cloud pixel
# and the highest mountain pixel, the row band that is genuinely clear sky
# at EVERY column is y 928-1058. 1000 sits well inside that band (72px of
# margin from the cloud side, 58px from the mountain side) without needing
# to be exact — everything below it (mountains, the desert reflection) is
# simply never part of the crop.
CROP_BOTTOM_SRC = 1000

# How many rows to pad onto the bottom of the (now mountain-free) crop, in
# OUTPUT pixels — CLEAR-SKY-AT-THE-FLOOR PASS. The crop itself already ends
# inside the all-clear band, 72px (source) short of where clouds end, which
# is 72 * SCALE = 18 output px of "free" clear sky before any padding. PAD_PX
# adds the rest: 18 + 112 = 130px total clear sky above the floor in a
# standard 192px room, comfortably past the 100px the room actually needs,
# with margin against rounding and against this number drifting if SCALE or
# CROP_BOTTOM_SRC ever change.
PAD_PX = 112

# Where the pad's own source TEXTURE is harvested from, in SOURCE pixels —
# GRAIN PASS (see header). Verified clear of any cloud/sun pixel at every
# column in x 0-1842 (the topmost real cloud pixel anywhere in that range is
# row 491), so this 350px band is plain sky with real paper grain and
# nothing directional to go wrong when it is tiled somewhere else in the
# image.
SWATCH_TOP = 100
SWATCH_BOTTOM = 450

# How many of the crop's own bottom rows (per piece) to average for the
# colour-match target — comfortably inside the all-clear band (see
# CROP_BOTTOM_SRC), so every sampled pixel is guaranteed plain sky.
MATCH_SAMPLE_ROWS = 20


def _avg_color(img: Image.Image, rows: int = None) -> tuple:
    """Average RGB over the image (or just its bottom `rows`, if given)."""
    px = img.load()
    total = [0.0, 0.0, 0.0]
    count = 0
    ys = range(img.height - rows, img.height) if rows else range(img.height)
    for y in ys:
        for x in range(0, img.width, 3):
            r, g, b = px[x, y]
            total[0] += r
            total[1] += g
            total[2] += b
            count += 1
    return tuple(t / count for t in total)


def _shift(img: Image.Image, offset: tuple) -> Image.Image:
    """A flat per-channel additive colour shift, applied to every pixel —
    moves the swatch's overall tone to match the crop it is padding without
    touching its relative grain/noise (every pixel moves by the same
    amount)."""
    px = img.load()
    out = Image.new("RGB", img.size)
    opx = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b = px[x, y]
            opx[x, y] = (
                max(0, min(255, round(r + offset[0]))),
                max(0, min(255, round(g + offset[1]))),
                max(0, min(255, round(b + offset[2]))),
            )
    return out


def _tile_pad(swatch: Image.Image, width: int) -> Image.Image:
    """Stack copies of `swatch` (alternating a vertical mirror each copy, so
    no single stamp repeats — see header) until there is at least PAD_PX rows
    of height, then crop to exactly PAD_PX."""
    tiles = []
    height = 0
    i = 0
    while height < PAD_PX:
        tile = swatch if i % 2 == 0 else ImageOps.flip(swatch)
        tiles.append(tile)
        height += tile.height
        i += 1
    stacked = Image.new("RGB", (width, height))
    y = 0
    for tile in tiles:
        stacked.paste(tile, (0, y))
        y += tile.height
    return stacked.crop((0, 0, width, PAD_PX))


def _pad(img: Image.Image, shifted_swatch: Image.Image) -> Image.Image:
    """Tile `shifted_swatch` (already colour-matched — see main()) to
    PAD_PX and append it below `img`."""
    pad = _tile_pad(shifted_swatch, img.width)
    canvas = Image.new("RGB", (img.width, img.height + PAD_PX))
    canvas.paste(img, (0, 0))
    canvas.paste(pad, (0, img.height))
    return canvas


def main():
    src = Image.open(SRC).convert("RGB")

    center_box = (SUN_CENTER_X - CENTER_HALF_W, 0,
                  SUN_CENTER_X + CENTER_HALF_W, CROP_BOTTOM_SRC)
    extend_box = (0, 0, EXTEND_W, CROP_BOTTOM_SRC)

    center = src.crop(center_box)
    extend = src.crop(extend_box)

    out_h = round(CROP_BOTTOM_SRC * SCALE)
    center_out = center.resize((round(center.width * SCALE), out_h), Image.LANCZOS)
    extend_out = extend.resize((round(extend.width * SCALE), out_h), Image.LANCZOS)

    # Swatches for the pad, cropped from the SAME x-ranges as CENTER/EXTEND
    # themselves (see SWATCH_TOP/SWATCH_BOTTOM) so each piece's pad is real
    # grain from roughly the part of the painting it is standing in for.
    swatch_box = (SUN_CENTER_X - CENTER_HALF_W, SWATCH_TOP,
                  SUN_CENTER_X + CENTER_HALF_W, SWATCH_BOTTOM)
    extend_swatch_box = (0, SWATCH_TOP, EXTEND_W, SWATCH_BOTTOM)
    sw_h = round((SWATCH_BOTTOM - SWATCH_TOP) * SCALE)
    center_swatch = src.crop(swatch_box).resize(
        (round(CENTER_HALF_W * 2 * SCALE), sw_h), Image.LANCZOS)
    extend_swatch = src.crop(extend_swatch_box).resize(
        (round(EXTEND_W * SCALE), sw_h), Image.LANCZOS)

    # ONE shared colour offset (from CENTER's own edge vs. its own swatch),
    # applied to BOTH pieces' pads — not one offset computed per piece. They
    # sit edge to edge in-game, and two independently matched offsets could
    # drift apart by a visible amount even if each looked fine on its own.
    offset_target = _avg_color(center_out, rows=MATCH_SAMPLE_ROWS)
    offset = tuple(offset_target[i] - _avg_color(center_swatch)[i] for i in range(3))

    center_final = _pad(center_out, _shift(center_swatch, offset))
    extend_final = _pad(extend_out, _shift(extend_swatch, offset))

    os.makedirs(OUT, exist_ok=True)
    center_path = os.path.join(OUT, "center.png")
    extend_path = os.path.join(OUT, "extend.png")
    center_final.save(center_path)
    extend_final.save(extend_path)
    print("wrote %s  %dx%d  (sun centred, shown once per world; bottom %dpx is padded real sky texture)"
          % (center_path, center_final.width, center_final.height, PAD_PX))
    print("wrote %s  %dx%d  (tiled outward, mirrored on alternating copies)"
          % (extend_path, extend_final.width, extend_final.height))
    print("pad colour offset (shared, from CENTER's own edge vs. its swatch): %s" % (offset,))


if __name__ == "__main__":
    main()
