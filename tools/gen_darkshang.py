#!/usr/bin/env python3
"""Darkshang — Hooshang's shadow self — as one sprite sheet.

Writes assets/characters/darkshang/darkshang.png: 4 columns x 3 rows of 32x48
frames (128x144), one row per animation, read left to right:

    row 0  IDLE    frames 1-4 of the reference: eyeless, breathing, still
    row 1  MOVE    the reference's eyes-open frames, extended to a 4-step shuffle
    row 2  SURGE   the reference's last two lunge poses, each with two arc phases

He is a SILHOUETTE, so there is no interior shading to draw and no palette to
speak of: the whole read is the shape, the rim and the eyes.

    * the fill is one near-black (BODY), flat on purpose;
    * a 1px rim traces the outline, three cold slate tones picked by which way
      the edge faces — the only thing that separates him from an unlit office
      wall, since pure black on near-black is a hole in the screen, not a body;
    * the eyes are the one bright element and they are COLD (pale blue-white).
      Warm gold is the musical notes' colour and appears nowhere on him.

The body is described as overlapping superellipse blobs in "model space" and
rasterised with 3x3 subsampling, so a pose is a handful of numbers (bob, lean,
swell, where the legs are) rather than 12 hand-placed bitmaps — which is what
makes a 12-frame sheet re-tunable at all. Every number here is fixed: the sheet
is byte-identical on every run.

Run from the repo root:
    python3 tools/gen_darkshang.py                  # write the sheet
    python3 tools/gen_darkshang.py --preview P.png  # + a 6x contact sheet on
                                                    #   an office-dark ground
"""
import os
import sys
import math

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "characters", "darkshang")

FRAME_W, FRAME_H = 32, 48
COLS, ROWS = 4, 3
ROW_IDLE, ROW_MOVE, ROW_SURGE = 0, 1, 2

# ---------------------------------------------------------------- palette ----
# Not black-black: a true (0,0,0) fill loses its own rim to any bloom/darkening
# the room applies, and reads as a missing sprite. This is as dark as a thing
# can be and still be a thing.
BODY = (6, 6, 9, 255)

# Rim, coldest-lit to unlit. Blue-grey, never warm — warm is Rumi and the notes.
RIM_LIT = (104, 118, 146, 255)   # edges facing the light (up / back-left)
RIM_MID = (56, 66, 86, 255)
RIM_DARK = (26, 31, 42, 255)     # edges facing away (down / front-right)

# Where the office light comes from, in canvas space (y grows down). Up and
# slightly behind him, matching the ceiling fluorescents.
LIGHT_DIR = (-0.45, -0.89)

# The eyes. Pale, cold, and the brightest thing in the frame by a mile.
EYE_CORE = (236, 246, 255, 255)
EYE_GLOW = (150, 190, 226, 255)
EYE_HALO = (64, 92, 124, 190)

# Lunge streaks. Same cold family as the eyes so they read as HIS motion.
ARC_BRIGHT = (196, 218, 240, 235)
ARC_FAINT = (128, 158, 190, 150)


# ------------------------------------------------------------- silhouette ----
# (cx, cy, rx, ry, n) superellipses in model space: |dx/rx|^n + |dy/ry|^n <= 1.
# n=2 is an ellipse; higher is squarer. Chunky and wide: a head barely wider
# than a fist on a body twice its width, and legs so short they are stubs.
# He faces RIGHT; the scene flips him for the other way.
HEAD = (16.0, 10.0, 6.0, 5.6, 2.0)   # a true ellipse: n>2 squares off a 12px
                                     # head into a hood
NECK = (16.0, 15.0, 4.6, 3.0, 2.4)   # fills the head/shoulder join, no neck gap
BODY_BLOB = (16.0, 28.0, 11.0, 11.5, 2.7)
ARM_BACK = (5.6, 32.0, 3.2, 7.0, 2.2)
ARM_FRONT = (26.4, 32.0, 3.2, 7.0, 2.2)
# Set wide apart and kept narrow. The first pass had them 8px apart and 8px
# wide, which merged them into one skirt with a notch in it — at this size the
# GAP is the only thing that says "legs", so it has to be wider than the rim.
LEG_BACK_X, LEG_FRONT_X = 11.0, 21.0
# (cy, rx, ry, n) — x comes from the pose. Set high enough to stay buried in the
# body: the belly tapers fast down here, so a leg that steps more than ~2px off
# centre loses its overlap and reads as a block floating under him.
LEG = (41.6, 3.2, 4.8, 3.0)

# The vertical span the forward lean shears across: 0 shift at the feet, full
# shift at the crown, so leaning never slides him off his own footing.
LEAN_TOP, LEAN_BOTTOM = 4.0, 46.0

SUB = 3          # subsamples per axis
COVER = 0.5      # coverage at which a pixel is part of him


class Pose:
    """One frame's worth of deformation, applied to the blobs above.

    bob    px the whole body rises (negative is up)
    lean   px the crown is pushed forward of the feet
    swell  body-width multiplier — the breath, and the pass-through swell's
           drawn cousin
    stretch  body-height multiplier (lunges flatten him)
    legs   (back_leg_dx, back_leg_dy, front_leg_dx, front_leg_dy)
    eyes   None, or (half_width, brightness 0..1)
    arcs   list of (radius, start_deg, end_deg, colour) motion streaks
    """

    def __init__(self, bob=0.0, lean=0.0, swell=1.0, stretch=1.0,
                 legs=(0.0, 0.0, 0.0, 0.0), eyes=None, arcs=()):
        self.bob = bob
        self.lean = lean
        self.swell = swell
        self.stretch = stretch
        self.legs = legs
        self.eyes = eyes
        self.arcs = list(arcs)

    def shear(self, model_y):
        t = (LEAN_BOTTOM - model_y) / (LEAN_BOTTOM - LEAN_TOP)
        return self.lean * max(0.0, min(1.0, t))

    def to_canvas(self, mx, my):
        """Model point -> canvas point. Eyes and arcs go through this so they
        can never drift off the body they are drawn on."""
        return mx + self.shear(my), my + self.bob

    def to_model(self, cx, cy):
        my = cy - self.bob
        return cx - self.shear(my), my

    def blobs(self):
        out = []
        for (bx, by, rx, ry, n) in (HEAD, NECK, BODY_BLOB, ARM_BACK, ARM_FRONT):
            # Swell/stretch scale about the body's centre, so a swelling
            # Darkshang grows outward rather than growing upward off his feet.
            cx = BODY_BLOB[0] + (bx - BODY_BLOB[0]) * self.swell
            cy = BODY_BLOB[1] + (by - BODY_BLOB[1]) * self.stretch
            out.append((cx, cy, rx * self.swell, ry * self.stretch, n))
        bdx, bdy, fdx, fdy = self.legs
        cy, rx, ry, n = LEG
        out.append((LEG_BACK_X + bdx, cy + bdy, rx, ry, n))
        out.append((LEG_FRONT_X + fdx, cy + fdy, rx, ry, n))
        return out


def _in_blobs(mx, my, blobs):
    for (cx, cy, rx, ry, n) in blobs:
        if abs((mx - cx) / rx) ** n + abs((my - cy) / ry) ** n <= 1.0:
            return True
    return False


def _mask(pose):
    """Boolean silhouette for one frame, subsampled so the round shapes keep a
    clean stepped edge instead of a jagged one."""
    blobs = pose.blobs()
    hits = [[False] * FRAME_W for _ in range(FRAME_H)]
    step = 1.0 / SUB
    for y in range(FRAME_H):
        for x in range(FRAME_W):
            covered = 0
            for sy in range(SUB):
                for sx in range(SUB):
                    px = x + (sx + 0.5) * step
                    py = y + (sy + 0.5) * step
                    mx, my = pose.to_model(px, py)
                    if _in_blobs(mx, my, blobs):
                        covered += 1
            hits[y][x] = covered / float(SUB * SUB) >= COVER
    return hits


def _rim_colour(mask, x, y):
    """Which of the three rim tones this edge pixel takes.

    The outward normal is the sum of the directions to the empty neighbours;
    dotted with the light it says whether this edge faces the fluorescents.
    Returns None for pixels that are not on the edge at all.
    """
    nx = ny = 0.0
    edge = False
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            ox, oy = x + dx, y + dy
            outside = (not (0 <= ox < FRAME_W and 0 <= oy < FRAME_H)
                       or not mask[oy][ox])
            if outside:
                # Diagonals count less: they are corners of the same edge, and
                # weighting them equally rounds every normal towards 45 degrees.
                w = 0.5 if (dx and dy) else 1.0
                nx += dx * w
                ny += dy * w
                if not (dx and dy):
                    edge = True
    if not edge:
        return None
    length = math.hypot(nx, ny)
    if length == 0.0:
        return RIM_MID
    facing = (nx / length) * LIGHT_DIR[0] + (ny / length) * LIGHT_DIR[1]
    if facing > 0.35:
        return RIM_LIT
    if facing > -0.4:
        return RIM_MID
    return RIM_DARK


def _draw_eyes(px, pose):
    """Two narrow slits, set in the head, with a faint halo bleeding onto the
    silhouette around them. They are the whole face — no brow, no mouth — so
    their WIDTH is the expression: wide for hunting, narrow for a lunge.

    The halo is deliberately weak and never runs past the ends of a slit. The
    first pass haloed the full width plus a pixel each side, and at a 13px-wide
    head the two glows met in the middle: he read as one visor band, which is a
    robot, not a pair of eyes watching you.
    """
    if pose.eyes is None:
        return
    half, bright = pose.eyes
    core = _mix(EYE_GLOW, EYE_CORE, bright)
    glow = _mix(EYE_HALO, EYE_GLOW, bright)
    # Model-space eye centres. The gap between them is load-bearing: two slits
    # with dark between them is a face, one bar is a slot.
    for eye_x in (12.8, 19.2):
        cx, cy = pose.to_canvas(eye_x, 9.6)
        ix, iy = int(round(cx)), int(round(cy))
        for dx in range(-half, half + 1):
            _put(px, ix + dx, iy, core)
        # Halo only under the slit's own span, and stronger below than above:
        # light pooling downward reads as something GLOWING out of the head
        # rather than as a second, dimmer slit.
        for dx in range(-half, half + 1):
            _blend(px, ix + dx, iy - 1, _fade(glow, 0.22))
            _blend(px, ix + dx, iy + 1, _fade(glow, 0.42))


def _draw_arcs(px, mask, pose):
    """Pale streaks curving around him on a lunge — drawn only where he is NOT,
    so they read as air torn past a solid shape rather than as marks on him."""
    for (radius, a0, a1, colour) in pose.arcs:
        cx, cy = pose.to_canvas(16.0, 28.0)
        steps = max(8, int(radius * 4))
        for i in range(steps + 1):
            t = i / float(steps)
            ang = math.radians(a0 + (a1 - a0) * t)
            x = int(round(cx + math.cos(ang) * radius))
            y = int(round(cy + math.sin(ang) * radius))
            if not (0 <= x < FRAME_W and 0 <= y < FRAME_H) or mask[y][x]:
                continue
            # Fade both ends so a streak tapers instead of stopping dead.
            taper = min(1.0, 3.2 * min(t, 1.0 - t) + 0.15)
            _blend(px, x, y, _fade(colour, taper))


def _put(px, x, y, c):
    if 0 <= x < FRAME_W and 0 <= y < FRAME_H:
        px[x, y] = c


def _blend(px, x, y, c):
    """Alpha-over onto whatever is there — the halo has to sit on both the body
    and the empty air beside it."""
    if not (0 <= x < FRAME_W and 0 <= y < FRAME_H):
        return
    src_a = c[3] / 255.0
    dst = px[x, y]
    dst_a = dst[3] / 255.0
    out_a = src_a + dst_a * (1.0 - src_a)
    if out_a <= 0.0:
        px[x, y] = (0, 0, 0, 0)
        return
    out = tuple(
        int(round((c[i] * src_a + dst[i] * dst_a * (1.0 - src_a)) / out_a))
        for i in range(3))
    px[x, y] = out + (int(round(out_a * 255)),)


def _mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def _fade(c, t):
    return (c[0], c[1], c[2], int(round(c[3] * max(0.0, min(1.0, t)))))


def render(pose):
    frame = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    px = frame.load()
    mask = _mask(pose)
    for y in range(FRAME_H):
        for x in range(FRAME_W):
            if mask[y][x]:
                px[x, y] = _rim_colour(mask, x, y) or BODY
    _draw_arcs(px, mask, pose)
    _draw_eyes(px, pose)
    return frame


# ------------------------------------------------------------------ poses ----
# IDLE: he is not doing anything, and that is the point — a slow swell and a 1px
# rise, no eyes. A perfectly still frame would look like a paused game; a walk
# cycle would look like he is coming for you. This is breathing.
IDLE = [
    Pose(bob=0.0, swell=1.00),
    Pose(bob=-1.0, swell=1.02),
    Pose(bob=-1.0, swell=1.03),
    Pose(bob=0.0, swell=1.01),
]

# MOVE: eyes open. Legs are stubs, so the walk is a SHUFFLE — the tell is the
# body rocking over them, not the stride length, which at 4px of leg would be
# invisible. A slight permanent lean says he is coming towards you.
MOVE = [
    Pose(bob=0.0, lean=1.5, swell=1.01, legs=(-1.4, 0.0, 1.4, -0.5),
         eyes=(1, 0.85)),
    Pose(bob=-1.0, lean=1.0, swell=1.00, legs=(0.0, -0.4, 0.4, 0.0),
         eyes=(1, 1.0)),
    Pose(bob=0.0, lean=1.5, swell=1.01, legs=(1.4, -0.5, -1.4, 0.0),
         eyes=(1, 0.85)),
    Pose(bob=-1.0, lean=1.0, swell=1.00, legs=(0.4, 0.0, 0.0, -0.4),
         eyes=(1, 1.0)),
]

# SURGE: the reference's last two frames. Two poses only — A is the lunge, B is
# the lunge further committed — alternating, each with its own streak phase, so
# the row cycles as pose/arcs rather than as four different drawings. The eyes
# narrow: same face, more intent.
_ARCS_A = [
    (13.5, 118.0, 246.0, ARC_BRIGHT),
    (18.0, 132.0, 232.0, ARC_FAINT),
]
_ARCS_B = [
    (15.5, 112.0, 250.0, ARC_BRIGHT),
    (20.5, 126.0, 238.0, ARC_FAINT),
    (24.0, 142.0, 220.0, ARC_FAINT),
]
# Both legs trail BACKWARD under the lean rather than splitting into a stride:
# he is not running, he is being thrown at you, and a stride would put a foot
# out in front to catch himself — which is the opposite of committed.
_SURGE_A = dict(bob=-1.0, lean=6.0, swell=1.03, stretch=0.97,
                legs=(-1.6, 0.5, -0.6, 0.2), eyes=(1, 1.0))
_SURGE_B = dict(bob=-2.0, lean=8.0, swell=1.05, stretch=0.94,
                legs=(-2.2, 0.7, -1.0, 0.3), eyes=(1, 1.0))
SURGE = [
    Pose(arcs=_ARCS_A, **_SURGE_A),
    Pose(arcs=_ARCS_B, **_SURGE_B),
    Pose(arcs=_ARCS_B, **_SURGE_A),
    Pose(arcs=_ARCS_A, **_SURGE_B),
]

SHEET = [IDLE, MOVE, SURGE]


def build_sheet():
    sheet = Image.new("RGBA", (FRAME_W * COLS, FRAME_H * ROWS), (0, 0, 0, 0))
    for row, poses in enumerate(SHEET):
        for col, pose in enumerate(poses):
            sheet.paste(render(pose), (col * FRAME_W, row * FRAME_H))
    return sheet


def build_preview(sheet, zoom=6):
    """A contact sheet at 6x on Act I's dim office grey, because the ONLY thing
    that matters about a silhouette is whether it separates from the wall it is
    standing in front of. Judge him here, not in an image viewer's white.

    The strip along the bottom is the same three poses at 1x, 2x and 3x — the
    sizes the game actually shows. A slit that is unmistakable at 6x can be one
    grey pixel at 1x, and that is the check that decides whether the eyes work.
    """
    pad = 4
    strip_h = FRAME_H * 3 + pad * 2
    w = sheet.width * zoom + pad * (COLS + 1)
    h = sheet.height * zoom + pad * (ROWS + 1) + strip_h
    out = Image.new("RGBA", (w, h), (24, 26, 32, 255))
    for row in range(ROWS):
        for col in range(COLS):
            cell = sheet.crop((col * FRAME_W, row * FRAME_H,
                               (col + 1) * FRAME_W, (row + 1) * FRAME_H))
            cell = cell.resize((FRAME_W * zoom, FRAME_H * zoom), Image.NEAREST)
            x = pad + col * (FRAME_W * zoom + pad)
            y = pad + row * (FRAME_H * zoom + pad)
            # Alternate ground tones: the left half on office grey, the right
            # half on the darkest corner of the level, where he is hardest to see.
            ground = (36, 38, 46, 255) if col % 2 == 0 else (14, 15, 19, 255)
            out.paste(Image.new("RGBA", cell.size, ground), (x, y))
            out.alpha_composite(cell, (x, y))

    top = h - strip_h + pad
    out.paste(Image.new("RGBA", (w, strip_h), (20, 22, 28, 255)), (0, h - strip_h))
    x = pad
    for row, col in ((ROW_IDLE, 0), (ROW_MOVE, 0), (ROW_MOVE, 1), (ROW_SURGE, 1)):
        cell = sheet.crop((col * FRAME_W, row * FRAME_H,
                           (col + 1) * FRAME_W, (row + 1) * FRAME_H))
        for z in (1, 2, 3):
            big = cell.resize((FRAME_W * z, FRAME_H * z), Image.NEAREST)
            out.alpha_composite(big, (x, top + FRAME_H * 3 - FRAME_H * z))
            x += FRAME_W * z + pad
        x += pad * 2
    return out


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet = build_sheet()
    path = os.path.join(OUT_DIR, "darkshang.png")
    sheet.save(path)
    print("wrote %s  %dx%d  (%d cols x %d rows of %dx%d)"
          % (path, sheet.width, sheet.height, COLS, ROWS, FRAME_W, FRAME_H))
    if "--preview" in sys.argv:
        dest = sys.argv[sys.argv.index("--preview") + 1]
        build_preview(sheet).save(dest)
        print("wrote preview %s" % dest)


if __name__ == "__main__":
    main()
