#!/usr/bin/env python3
"""The thought sprites: a small cloud with a hot red rim, four frames, in
three tones — a black one, a pale one, and a neutral grey between them.

Writes three 64x16 sheets of four 16x16 frames each, into assets/hazards/
(what the game draws) and ldtk/art/ (what the LDtk editor previews):

    dark_thought.png    64x16, four frames left to right, looping
    light_thought.png   the same four frames, body ramped pale instead of black
    grey_thought.png    the same four frames again, body ramped neutral grey

ONE SCRIPT, THREE PALETTES. The pale and grey thoughts are the black one
recoloured and nothing else — same source, same cut, same reduction, same
breath, same rim — so all three are generated together from one pipeline
rather than by separate scripts that would be free to drift out of step with
each other. See TONES.

Source: assets/hazards/dark_thought/source/dark_thought_strip.png — Pixellab
(create_image_pixflux, job 7e72c25f-2c08-42d3-87a5-678c300f2a2e), asked for a
five-frame strip of a roiling black smoke cloud with a hot red rim light, in
detailed pixel art with soft shading and dynamic lighting, explicitly NOT
8-bit/NES. It came back 320x64 with EIGHT stamps rather than five, at 31x24
each. That is fine — the frames are cut by what is actually in the image, not
by dividing the canvas by the number asked for.

Three things this file does that a crop and resize does not, each of them a
thing that went wrong first:

  - CUT BY CONNECTIVITY, not by slicing the canvas into equal columns. The
    stamps are not on the pitch that was asked for (40px, not 64) and the two on
    the ends are clipped by the canvas edge. Slicing into fifths lands a seam
    through the middle of two clouds; flood-filling finds eight whole ones and
    the clipped pair identify themselves by being narrower than the rest. Same
    lesson as gen_lemon.py, for the same reason: the image is the authority on
    where the frames are.

  - RECOLOUR, don't tint. What came back is a plum-and-pink cloud: body around
    (45,28,51), edges around (161,81,83). The brief is BLACK with a RED rim, and
    those are two different remaps of the same pixel — an overall hue shift can
    only do one of them and takes the other with it. So the body is crushed
    towards black along its own luminance (the lobes survive as shading) and the
    RIM — every opaque pixel with a transparent neighbour — is repainted hot
    red. Which matters more than it looks: see RIM_LIT below.

  - A BREATH, not a slide. The eight stamps do differ, but by a pixel of shading
    here and there; measured, a stamp differs from its neighbour by about 0.2 of
    one channel per pixel, and half of even that is lost in the reduction to
    16px. So the loop's motion is the BREATH heights below — the cloud swells
    and settles inside a fixed cell — on top of whatever roil survives. It has
    to be a swell rather than an offset: the prop is already travelling a path,
    and art that also shifts sideways reads as the sprite lagging the hitbox.

MUSH IS THE POINT HERE, unlike gen_cone_spikes.py. That file redraws rather than
downsamples because five pixels of cone cannot keep an apex through a resampler.
A cloud has no apex to lose — softening the 31x24 source into 16x12 is what
makes it read as smoke rather than as a small brick, so this one resamples
happily, with LANCZOS, and the only edge that has to stay crisp is the rim,
which is repainted after the reduction and not resampled at all.

Re-run after editing:  python3 tools/gen_dark_thought.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "hazards", "dark_thought",
                   "source", "dark_thought_strip.png")

## One grid cell square. The prop is placed on the 8px grid but occupies two
## cells across and two down, which is the smallest a cloud can be and still
## have an inside — at 8px it is a rim with nothing in it.
CELL = 16
FRAMES = 4

## How tall the cloud is drawn in each frame, in px, over the CELL. The loop is
## up-and-back-down rather than a sawtooth, so it breathes instead of ticking:
## 12, 13, 12, 11 returns to 12 on the way round.
##
## Kept BELOW the cell on every frame. The kill box is derived from a fixed
## `size` in dark_thought.gd, and art that swelled past it would put lethal-
## looking cloud outside the lethal region — leniency is meant to run the other
## way.
BREATH = [12, 13, 12, 11]

## Alpha at or under which a pixel is nothing. The reduction leaves a haze of
## 1-30 alpha around the cloud; treated as cloud it doubles the silhouette and
## the rim ends up drawn around the haze instead of around the shape.
CUTOFF = 96

## The body, dark end to light end, ramped along the source's own luminance so
## the lobes it drew still read. Near-black on purpose: Act I runs CanvasModulate
## 0.05 and the DarkThought carries its own red PointLight2D, and a 2D light in
## Godot MULTIPLIES the surface it falls on — so a black body stays a silhouette
## inside its own glow, which is exactly what a shadow should do.
BODY_DARK = (10, 7, 13)
BODY_LIT = (38, 22, 34)

## The LIGHT thought's body, the same ramp inverted: a pale cloud instead of a
## black one, with the rim left exactly as it is. Same hazard, different colour,
## which is the whole of the difference.
##
## Kept OFF pure white at the shadow end. The lobes are the only thing that says
## "cloud" rather than "blob", and they only survive if the ramp has somewhere
## to travel — a body drawn 250..255 comes back as a white pill. The shadow end
## is faintly cool so the red rim has something to sit against; warm shadows
## under a red rim turn the whole sprite pink.
##
## WHY THIS CAN BE BRIGHT AT ALL — and it is the one thing about the pale
## version that is not just a palette. Act I runs CanvasModulate 0.05 and the
## prop carries its own RED PointLight2D, and a 2D light MULTIPLIES what it
## falls on. Measured, a white body under that light renders (1.00, 0.32, 0.23):
## a red cloud, not a white one, because red light times white is red. So the
## pale sprite is drawn UNSHADED (see dark_thought.gd's `tone`), which takes it
## out of both the light and the modulate and shows these values as painted.
## That is why the numbers here are the finished colours and not a starting
## point the room lighting finishes — the opposite of the dark body, which is
## drawn near-black precisely so its own glow leaves it a silhouette.
BODY_PALE_DARK = (186, 182, 202)
BODY_PALE_LIT = (255, 253, 248)

## The rim, same ramp. Bright on purpose, and for the opposite reason to the
## body: this is the part the red light has something to multiply, so this is
## the part that glows. A rim as dark as the body would leave the prop lighting
## an empty patch of air.
##
## It is also the answer to LIGHTING.md's one recorded case where a light was
## not enough — Rumi's gift needed a drawn core because the office walls are
## already at 255 in the red channel and a warm glow on them reads as nothing.
## A red light on a red wall has the same problem; the drawn rim is this prop's
## core, and it is why the cloud is legible against the brick rather than only
## against the dark.
RIM_DARK = (122, 20, 18)
RIM_LIT = (236, 60, 42)

## The GREY thought's body: the NEUTRAL feeling-tone, between the unpleasant
## (dark) and the pleasant (light). A desaturated mid-grey, kept faintly cool at
## the shadow end for the same reason the pale body is — so the red rim has
## something to sit against, rather than turning the whole sprite pink.
BODY_GREY_DARK = (72, 70, 82)
BODY_GREY_LIT = (150, 146, 158)

## Sheet name -> body ramp. The rim is deliberately NOT in here: "the same red
## outline" is the point of every variant, so there is only one rim palette and
## no way to change one without changing all three.
TONES = {
    "dark_thought": (BODY_DARK, BODY_LIT),
    "light_thought": (BODY_PALE_DARK, BODY_PALE_LIT),
    "grey_thought": (BODY_GREY_DARK, BODY_GREY_LIT),
}


def stamps(img):
    """Every whole cloud in the source, left to right.

    Flood-filled 8-connected, then the ones clipped by the canvas edge are
    dropped: they identify themselves by being narrower than the modal width,
    which is a measurement rather than a guess about which ends got cut.
    """
    w, h = img.size
    px = img.load()
    seen = [[False] * h for _ in range(w)]
    found = []
    for x in range(w):
        for y in range(h):
            if px[x, y][3] <= CUTOFF or seen[x][y]:
                continue
            stack, pts = [(x, y)], []
            seen[x][y] = True
            while stack:
                cx, cy = stack.pop()
                pts.append((cx, cy))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[nx][ny] \
                                and px[nx, ny][3] > CUTOFF:
                            seen[nx][ny] = True
                            stack.append((nx, ny))
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            found.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    found.sort()
    widths = [b[2] - b[0] for b in found]
    full = max(set(widths), key=widths.count)
    return [b for b in found if b[2] - b[0] == full]


def luminance(rgb):
    return (rgb[0] * 0.299 + rgb[1] * 0.587 + rgb[2] * 0.114) / 255.0


def ramp(dark, lit, t):
    return tuple(int(round(dark[i] + (lit[i] - dark[i]) * t)) for i in range(3))


def recolour(cell, body_dark, body_lit):
    """Body in the palette given, hot red rim — the rim is the same either way.

    The rim is found AFTER the reduction and painted flat, so it is one crisp
    pixel wide however soft the shape behind it came out. Found by asking each
    opaque pixel whether any of its four neighbours is empty — the cloud's own
    outline, rather than a dilate-and-subtract, which on a 16px sprite eats the
    thin part of every lobe.
    """
    w, h = cell.size
    src = cell.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    solid = [[src[x, y][3] > CUTOFF for y in range(h)] for x in range(w)]

    ## The source's own luminance range, so the ramps use all of both palettes
    ## whatever the crop happens to contain. A fixed 0..1 assumption washed the
    ## whole cloud to one colour: nothing in it is brighter than 0.4.
    lums = [luminance(src[x, y]) for x in range(w) for y in range(h)
            if solid[x][y]]
    lo, hi = min(lums), max(lums)
    span = max(hi - lo, 0.001)

    for x in range(w):
        for y in range(h):
            if not solid[x][y]:
                continue
            edge = any(
                not (0 <= x + dx < w and 0 <= y + dy < h and solid[x + dx][y + dy])
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            t = (luminance(src[x, y]) - lo) / span
            rgb = ramp(RIM_DARK, RIM_LIT, t) if edge \
                else ramp(body_dark, body_lit, t)
            dst[x, y] = rgb + (255,)
    return out


def main():
    img = Image.open(SRC).convert("RGBA")
    boxes = stamps(img)
    if len(boxes) < FRAMES:
        raise SystemExit("!! only %d whole clouds in the source, need %d"
                         % (len(boxes), FRAMES))
    print("source %dx%d, %d whole clouds at %dx%d"
          % (img.width, img.height, len(boxes),
             boxes[0][2] - boxes[0][0], boxes[0][3] - boxes[0][1]))

    # All three tones come off the SAME cut and the same reduction, and differ
    # by nothing but the body ramp. Separate scripts would let them drift — a
    # breath retimed in one and not the others is hazards that no longer read
    # as the same object, which is the one thing they have to keep doing.
    for name, (body_dark, body_lit) in TONES.items():
        sheet = Image.new("RGBA", (CELL * FRAMES, CELL), (0, 0, 0, 0))
        for i in range(FRAMES):
            tall = BREATH[i]
            cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            # LANCZOS, and the softness it leaves is wanted — see the header.
            shrunk = img.crop(boxes[i]).resize((CELL, tall), Image.LANCZOS)
            cell.paste(shrunk, (0, (CELL - tall) // 2))
            sheet.paste(recolour(cell, body_dark, body_lit), (i * CELL, 0))
            if name == "dark_thought":
                print("  frame %d  from x%d, drawn %dx%d"
                      % (i, boxes[i][0], CELL, tall))
        for folder in ("assets/hazards", "ldtk/art"):
            path = os.path.join(ROOT, folder, name + ".png")
            sheet.save(path)
            print("wrote %s  %dx%d" % (path, sheet.width, sheet.height))

    verify_rim_identity()


def verify_rim_identity():
    """Every rim pixel must be byte-identical across every pair of sheets, and
    the vast majority of body pixels must differ — the contract that makes
    three tones read as the same hazard in three moods, not three props.

    A handful of coincidentally identical body pixels is allowed (two ramps CAN
    land on the same RGB at one luminance by chance) but 95%+ must differ.
    """
    sheets = {}
    for name in TONES:
        p = os.path.join(ROOT, "assets", "hazards", name + ".png")
        sheets[name] = Image.open(p).convert("RGBA").load()
    w, h = CELL * FRAMES, CELL

    names = list(TONES)
    for i, a_name in enumerate(names):
        for b_name in names[i + 1:]:
            apx, bpx = sheets[a_name], sheets[b_name]
            rim_ok = rim_total = body_changed = body_total = 0
            for x in range(w):
                for y in range(h):
                    a, b = apx[x, y], bpx[x, y]
                    if a[3] <= CUTOFF and b[3] <= CUTOFF:
                        continue
                    edge = a[3] > CUTOFF and any(
                        not (0 <= x + dx < w and 0 <= y + dy < h
                             and apx[x + dx, y + dy][3] > CUTOFF)
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                    if edge:
                        rim_total += 1
                        if a == b:
                            rim_ok += 1
                    elif a[3] > CUTOFF and b[3] > CUTOFF:
                        body_total += 1
                        if a != b:
                            body_changed += 1
            pct = 100.0 * body_changed / max(body_total, 1)
            print("  %-14s vs %-14s  rim %d/%d identical, body %d/%d changed (%.0f%%)"
                  % (a_name, b_name, rim_ok, rim_total,
                     body_changed, body_total, pct))
            if rim_ok != rim_total:
                raise SystemExit("!! rim differs between %s and %s: %d/%d match"
                                 % (a_name, b_name, rim_ok, rim_total))
            if pct < 95.0:
                raise SystemExit("!! too few body pixels differ between %s and "
                                 "%s: %.1f%%" % (a_name, b_name, pct))
    print("VERIFIED: rim byte-identical across all tones, bodies distinct")


if __name__ == "__main__":
    main()
