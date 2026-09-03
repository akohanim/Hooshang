#!/usr/bin/env python3
"""Spring platform art: a coiled-spring bounce pad — idle, compressed, and
the tall expanded pose it snaps to on release.

Procedural, not cut from a render — there is no source photo for this prop, so
it is drawn directly with the same "flat-shaded pixel geometry" technique
tools/gen_cone_spikes.py and tools/gen_dark_thought.py use for props with no
photo source.

FIXED SIZE, ONE FRAME SHAPE PER POSE (2026-09), AT THE USER'S EXPLICIT
DIRECTION. This prop is no longer a stretchable Platform-style tile:
  - COMPACT canvas (IDLE, COMPRESSED): 16x8.
  - EXPANDED canvas (the release overshoot): 16x16 — a REAL taller frame now,
    not a scale trick. Earlier passes scaled the compact IDLE sprite up
    tall-and-thin as a stand-in for a third art frame, reasoning that an
    8px-tall tile has no room to draw one — true for an 8px tile, but the user
    asked for the coil to actually extend further up on launch, on its own
    16x16 canvas, which is what this version draws for real. See
    spring_platform.gd's _play_stretch for how the two textures are swapped,
    bottom-anchored so the extra height grows UPWARD off the same standable
    footprint rather than pushing the mount down through the floor.
  - The entity itself is FIXED at 16x8 in scenes/props/platforms/spring_platform.gd
    (its `size` setter no longer accepts anything else) — "this should be the
    only size for this entity," not a resizable strip. See that file's own
    note on why the guarantee lives in code rather than only in the LDtk
    entity definition's resizable flags.

Three frames, not an animation: IDLE (coil at rest, tension stored),
COMPRESSED (coil squashed flat, held for one brief beat right on landing —
see spring_platform.gd's _play_bounce), EXPANDED (the coil taller than rest,
held for one brief beat right on release, easing back to IDLE). Same
"discrete frames stamped on" idea CrumblingPlatform's damage stages use, not
motion baked into a sheet.

DARK OUTLINE (2026-09). A 1px near-black stroke around every opaque pixel's
transparent neighbours — see _outline(). Added because the plain grey fill,
even the darkened one from the previous pass, still lost its own silhouette
edge against certain busy backgrounds; an outline is what actually holds a
small sprite's shape together regardless of what is behind it, and it is
what the reference sprite (mario.fandom.com/wiki/Spring_Jump) does too — every
stop in this file's palette already reads as "metal", the outline is what
makes it read as "an object" rather than a few adjacent smudges.

MARIO-SPRING PASS (2026-09), REPLACING THE WATERCOLOR/GOLD VERSION ENTIRELY,
AT THE USER'S EXPLICIT DIRECTION AND REFERENCE IMAGES. Worth recording the
attempts this replaced, so a next rewrite does not re-walk them:
  1. A wide zigzag filled solid across the whole 24px tile. Read as a sawtooth
     mountain range — a real coil is a thin wire with background showing
     THROUGH it between loops, not a filled wedge of metal.
  2. A narrower filled "post" per 8px cell, repeated three times, with a flat
     cap. Still a solid painted shape, not a wound wire, and gold — this
     project's general Act 2 palette (warm amber/bronze, see
     tools/gen_act2_tileset_8px.py), but not Mario's spring, which is grey
     steel. The user asked for the second point explicitly: "why is it gold?
     make it look like the coil platform from mario, gray."
  3. A continuous grey zigzag STROKE spanning the full 24px tile. Grey was
     right and the STROKE technique (kept below) was right, but one coil
     stretched across the whole platform still read as a repeating fence, not
     one spring — the user's own words: "no one single coil."
  4. One centred coil on a full-width ledge, 24px tile, light steel. Right
     shape, but checked against a real Act 2 room (pale sage/beige) and
     nearly invisible — darkened in the very next pass (see below).
  5. Same shape, darkened palette. Visible against the room, but the user's
     next reference (compressed-pose / extended-pose side by side) made clear
     the coil itself needed to actually look wound, and — this pass — that the
     extended pose needed to be a real taller shape and the whole thing a
     fixed 16-wide size, not a resizable strip. See FIXED SIZE above.

ONE COIL, ON A LEDGE THE SAME WIDTH AS THE COIL (AT THE USER'S EXPLICIT
DIRECTION, 2026-09 — narrower pass). A real spring is a single narrow object
roughly as tall as it is wide, not a strip running the width of whatever it is
bolted to — and the mount it sits on reads as part of the same object, so it
is drawn no wider than the coil's own resting width either. The mount/ledge
(BASE_ROWS) used to span the full 16px canvas; it is now COIL_WIDTH wide,
centred the same way the coil is (same COIL_X0/COIL_X1), in every pose —
including COMPRESSED, whose own cap (SQUASH_WIDTH) briefly bulges wider than
the ledge beneath it, which is correct: a squashed spring overhangs its
mount, it does not widen it. Narrowing the base means it no longer touches
the canvas's left/right edges, so _outline() now stamps a stroke down both of
its new vertical sides too, on top of the row it already stroked along the
top — see _outline()'s own note on why edge pixels are skipped, which still
holds for the BOTTOM row (still canvas-edge, still meant to butt against the
floor beneath it).

TWO DIFFERENT COMPACT SILHOUETTES, NOT ONE SHAPE AT TWO SCALES. Reference: a
squashed spring is two or three wide, nearly-flat rings pressed together,
barely taller than its own mount; an idle one is a taller, narrower column
with visible diagonal winding. draw_compressed() and draw_idle() are separate
functions rather than one shape parametrised by height — an earlier attempt
tried to get both poses out of one parametrised shape and the compressed pose
came out as "the idle shape, shorter", which is not what a squashed spring
actually looks like (wider, not just shorter).

STROKE, NOT FILL, for the wound wire. COIL_HI on the lit edge, COIL_DARK on
the shadow edge, nothing painted anywhere else in its column — the
transparent gaps between one stroke and the next are what read as one loop of
wire seen apart from another, the thing every filled version above got wrong.

Grey is a deliberate, hand-picked departure from the extracted-Pixellab-ramp
convention every other Act 2 prop generator follows (see
experiments/act2_watercolor/README.md) — this prop matches a specific
external reference's colour, not Act 2's own warm palette, so there is no
ramp to extract from; the Pixellab source under
assets/props/spring_platform/source/ is gold and is simply unused now, kept
on disk rather than deleted in case a grey-toned regeneration replaces it
later.

Re-run after editing: python3 tools/gen_spring_platform.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "spring_platform")
LDTK_ART = os.path.join(ROOT, "ldtk", "art")

# Compact canvas (IDLE, COMPRESSED) and the tall EXPANDED canvas — see FIXED
# SIZE above. Both are 16 wide; only the height differs.
TILE_W = 16
COMPACT_H = 8
EXPANDED_H = 16

# Dark gunmetal grey, matching the reference sprite
# (mario.fandom.com/wiki/Spring_Jump) rather than Act 2's usual warm gold —
# see the MARIO-SPRING PASS note above for why this prop breaks from the
# project's normal palette convention. None of these stops go above 150,
# on purpose: Act 2's tileset and backdrops are a pale sun-bleached
# sage/beige (sampled directly — ldtk/art/act2_tileset_8px.png's own
# most-common colours all read north of ~180 in luminance), so a light prop
# sits at almost the same brightness as the ROOM and disappears into it
# however correctly "grey" it is.
CAP_HI = (150, 155, 165, 255)        # the landing disc — brightest stop, still mid-dark
COIL_HI = (108, 113, 123, 255)       # lit (upper) edge of the wound wire
COIL_MID = (78, 83, 92, 255)         # the squashed-ring fill (COMPRESSED only)
COIL_DARK = (42, 45, 52, 255)        # shadow (lower) edge of the wound wire — near-black
BASE_HI = (95, 100, 109, 255)        # ledge, lit on top like every standable edge
BASE = (66, 70, 78, 255)
BASE_DARK = (36, 38, 44, 255)
# The 1px silhouette stroke — see DARK OUTLINE above. Darker than COIL_DARK so
# it still reads as an edge even where the fill beside it is already dark.
OUTLINE = (16, 17, 20, 255)

BASE_ROWS = 2  # bottom rows: the ledge the coil is mounted on
CAP_ROWS = 1  # top row of the coil: the flat disc Mario's feet land on
# The coil's own footprint — narrower than the tile, centred on it. Roughly as
# wide as it is tall (see ONE COIL, ON A LEDGE above): a real spring is not a
# strip the width of whatever it is bolted to.
COIL_WIDTH = 8
COIL_X0 = (TILE_W - COIL_WIDTH) // 2
COIL_X1 = COIL_X0 + COIL_WIDTH
STROKE_W = 3
# COMPRESSED's rings splay wider than the coil's own resting width — a
# squashed spring bulges, it does not just get shorter (see reference).
SQUASH_WIDTH = 12
SQUASH_X0 = (TILE_W - SQUASH_WIDTH) // 2
SQUASH_X1 = SQUASH_X0 + SQUASH_WIDTH
# How many rows one full left-right-left cycle of the EXPANDED coil's wave
# takes — small relative to its ~13 available rows so several turns are
# visible, which is the whole point of giving it real height to draw into.
EXPANDED_PERIOD_ROWS = 4


def _mount(px, h: int) -> int:
    """Paint the ledge — COIL_WIDTH wide, centred like the coil above it, not
    the full canvas — and return bracket_top, the first row it occupies
    (everything above that row is the coil's own to draw)."""
    bracket_top = h - BASE_ROWS
    for x in range(COIL_X0, COIL_X1):
        for y in range(bracket_top, h):
            row = y - bracket_top
            px[x, y] = BASE_HI if row == 0 else (BASE if row == 1 else BASE_DARK)
    return bracket_top


def _outline(img: Image.Image) -> Image.Image:
    """Stamp a 1px OUTLINE stroke into every transparent pixel that touches an
    opaque one (4-connected) — the silhouette edge that holds the shape
    together against any background. Canvas-edge pixels (the ledge's own left,
    right and bottom, which are meant to butt seamlessly against the level
    around them) have no out-of-bounds "neighbour" to trigger on, so they are
    correctly left unstroked — only the coil/cap/ledge-top edges that actually
    border open air get one."""
    px = img.load()
    w, h = img.size
    to_stamp = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] != 0:
                    to_stamp.append((x, y))
                    break
    for x, y in to_stamp:
        px[x, y] = OUTLINE
    return img


def draw_idle() -> Image.Image:
    """A narrow, upright coil at rest: a flat cap over one wound-wire stroke,
    on the ledge — one spring standing there, not a wave drawn across the
    whole tile.
    """
    img = Image.new("RGBA", (TILE_W, COMPACT_H), (0, 0, 0, 0))
    px = img.load()
    bracket_top = _mount(px, COMPACT_H)

    cap_top, cap_bottom = 1, 1 + CAP_ROWS
    for x in range(COIL_X0, COIL_X1):
        for y in range(cap_top, cap_bottom):
            px[x, y] = CAP_HI

    # One wound turn of wire between the cap and the ledge: a single diagonal
    # stroke sweeping from one side of the column to the other as it
    # descends, lit on its upper half and shadowed on its lower half. Four
    # rows is not enough height to show a real multi-loop spiral (compare
    # draw_expanded(), which has ~13 rows and shows several) — one clean
    # diagonal reads as "a turn of wire" where a busier attempt at this height
    # just read as noise (see the module docstring's pass 3).
    body_top, body_bottom = cap_bottom, bracket_top
    rows = body_bottom - body_top
    for i, y in enumerate(range(body_top, body_bottom)):
        t = i / max(rows - 1, 1)  # 0 at the cap, 1 at the ledge
        cx = COIL_X0 + int(round(t * (COIL_WIDTH - STROKE_W)))
        shade = COIL_HI if t < 0.5 else COIL_DARK
        for x in range(cx, min(cx + STROKE_W, COIL_X1)):
            px[x, y] = shade

    return _outline(img)


def draw_compressed() -> Image.Image:
    """A squashed spring: two wide, nearly-flat rings pressed directly onto
    the ledge, no visible winding — the tension has nowhere left to go.
    """
    img = Image.new("RGBA", (TILE_W, COMPACT_H), (0, 0, 0, 0))
    px = img.load()
    bracket_top = _mount(px, COMPACT_H)

    cap_row = bracket_top - 3
    for x in range(SQUASH_X0, SQUASH_X1):
        px[x, cap_row] = CAP_HI

    # Two flat rings, wider than the resting coil and squeezed to one row
    # each — a spring compresses by bulging outward, not by shrinking evenly.
    ring_rows = [cap_row + 1, cap_row + 2]
    widths = [SQUASH_WIDTH, SQUASH_WIDTH - 2]
    shades = [COIL_MID, COIL_DARK]
    for y, w, shade in zip(ring_rows, widths, shades):
        x0 = (TILE_W - w) // 2
        for x in range(x0, x0 + w):
            px[x, y] = shade

    return _outline(img)


def _row_wave(i: int, amplitude: int, period_rows: int) -> float:
    """Triangle wave, 0..amplitude, over ROW index (not x) — period_rows rows
    per full left-right-left cycle. Row-indexed rather than x-indexed on
    purpose: an earlier attempt derived a row's wave phase from a fractional
    slice of an x-oriented period and the rounding made consecutive rows jump
    around non-monotonically (see the module docstring's pass 3) — sampling
    the wave directly at integer row indices cannot do that."""
    if amplitude <= 0 or period_rows <= 0:
        return 0.0
    t = i % period_rows
    half = period_rows / 2.0
    frac = t / half if t < half else 2.0 - t / half
    return frac * amplitude


def draw_expanded() -> Image.Image:
    """The release overshoot: the same coil, genuinely taller — several
    visible turns of wound wire on its own 16x16 canvas, not a scale trick
    played on the resting IDLE frame. Bottom-anchored by
    spring_platform.gd._apply_frame (see its own note) so the extra height
    grows upward off the same standable footprint.
    """
    img = Image.new("RGBA", (TILE_W, EXPANDED_H), (0, 0, 0, 0))
    px = img.load()
    bracket_top = _mount(px, EXPANDED_H)

    cap_top, cap_bottom = 0, CAP_ROWS
    for x in range(COIL_X0, COIL_X1):
        for y in range(cap_top, cap_bottom):
            px[x, y] = CAP_HI

    body_top, body_bottom = cap_bottom, bracket_top
    amp = COIL_WIDTH - STROKE_W
    for i, y in enumerate(range(body_top, body_bottom)):
        cx = COIL_X0 + int(round(_row_wave(i, amp, EXPANDED_PERIOD_ROWS)))
        shade = COIL_HI if (i % EXPANDED_PERIOD_ROWS) < EXPANDED_PERIOD_ROWS / 2.0 \
            else COIL_DARK
        for x in range(cx, min(cx + STROKE_W, COIL_X1)):
            px[x, y] = shade

    return _outline(img)


os.makedirs(OUT, exist_ok=True)
os.makedirs(LDTK_ART, exist_ok=True)

idle = draw_idle()
compressed = draw_compressed()
expanded = draw_expanded()
idle.save(os.path.join(OUT, "idle.png"))
compressed.save(os.path.join(OUT, "compressed.png"))
expanded.save(os.path.join(OUT, "expanded.png"))

# LDtk icon: the EXPANDED frame is already a 16x16 square, so no crop/resize
# guesswork about which slice of a wider tile actually holds the coil (the
# old crop-and-upscale approach, from when the tile was 24px and the icon
# had to be cut out of it) — it just IS one, pixel for pixel.
expanded.save(os.path.join(LDTK_ART, "spring_platform.png"))

print("wrote %s idle.png, compressed.png (%dx%d), expanded.png (%dx%d)"
      % (os.path.relpath(OUT, ROOT), TILE_W, COMPACT_H, TILE_W, EXPANDED_H))
print("wrote %s" % os.path.relpath(os.path.join(LDTK_ART, "spring_platform.png"), ROOT))
