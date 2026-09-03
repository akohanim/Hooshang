#!/usr/bin/env python3
"""Act 2's paintable thought-hazard tiles: a playful, childhood-memory palette
for the same "sludge" mechanic tools/gen_thought_tiles.py builds for Act 1.

SAME 32x48 sheet, SAME six-frame x four-tile-type layout (fill, top edge, left
edge, corner) as gen_thought_tiles.py, and the SAME static contour / travelling
rim-brightness / fading-face structure — ldtk_thought_hazard_layer.gd drives
every painted cell purely from tile geometry and a coordinate hash, with no
palette-specific logic anywhere in it, so keeping the layout identical is what
lets this drop straight in as a tileset swap with zero script changes.

What actually changes is the read: Act 1's sludge is a dread-mass with a hot
red rim and a haunted face. Act 2 is a "negative cloud" from a happy childhood
memory, not a nightmare — so the contour is rounder (no sharp corner notch)
and the face reads as a pouty grump rather than something haunted. THE RIM,
though, is the SAME hot red as Act 1's (RED RIM PASS, 2026-09 — see
gen_act2_thought.py's header for the reasoning: a hazard that stops reading as
dangerous at a glance is worse regardless of how playful its body is), not the
softer candy-purple pulse an earlier pass gave it. Still unmistakably a hazard
— the rim is still the brightest, most saturated thing on the tile, and now
the same colour every other hazard in the game uses for that job.

WATERCOLOR PASS (2026-09). PALETTE ONLY, CONTOUR/ANIMATION UNCHANGED — reads a
Pixellab "pulled back" watercolor generation (see
experiments/act2_watercolor/README.md: pulled-back is the direction proven to
survive reduction to this project's actual small-prop/8px-tile scale; heavy
bleed measurably turns to mud there) for its body ramp and rim colour, rather
than hand-picked hex. The STATIC contour and the per-cell hashed animation
(gen_act2_thought.py's twin, and ldtk_thought_hazard_layer.gd on the runtime
side) are exactly the kind of thing this codebase already decided NOT to
source from a generated bitmap for a tile this small — see
tools/gen_cone_spikes.py's own header on why photo/paint-sourced detail turns
to mush at 8px, which applies here just as much as to a spike's point.

Source: ldtk/art/source/act2_sludge.png (Pixellab create_image_pixflux,
prompt "small round bubbly pastel purple grump cloud creature, candy pink
glowing rim, pouty cartoon face... detailed pixel art with
watercolor-influenced soft gradient shading, clean crisp pixel edges,
restrained painterly bleed... dreamy pastel childhood-memory palette of
lavender pink and plum", seed 2202) — the SAME source gen_act2_thought.py
reads, so the painted tiles and the floating clouds are sampled from one
image and cannot drift apart in tone. `_ramp_from_source()` sorts the
source's most-common opaque colours by luminance; BODY_DARK/MID/LIGHT are its
darkest/mid/lightest purple stops. RIM_HOT/RIM_DIM do NOT come from the
source at all — as of the RED RIM PASS (2026-09) they are Act 1's own hot red
(gen_dark_thought.py's RIM_LIT/RIM_DARK, copied byte-for-byte), not the
source's violet-pink brightest pixels and not the project's earlier
candy-pink either. The brief is explicit that the rim has to stay the
brightest, most-saturated thing on the tile — the "spot the hazard fast" job
— and, after this pass, the SAME colour that job uses everywhere else in the
game. gen_act2_thought.py's SAME two constants are kept equal to these by
hand; there is no automated check that they match (act2_hazards_test.gd
proves the tiles still kill and draw Act 2's own sheet, not rim colour).

Re-run after editing: python3 tools/gen_act2_thought_tiles.py
"""
import math
import os
from collections import Counter
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ldtk", "art")
SOURCE = os.path.join(OUT, "source", "act2_sludge.png")
CELL = 8
FRAMES = 6


def _ramp_from_source(path, n=8):
    """Top-N most common opaque colours in the Pixellab source, sorted
    brightest to darkest. Same technique as gen_act2_tileset_8px.py's
    helper — kept as a separate copy per this project's convention of
    self-contained generator scripts (see gen_act2_cone_spikes.py's own note
    on why a shared helper is not worth importing across these)."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


_RAMP = _ramp_from_source(SOURCE)

# ---------------------------------------------------------------------------
# Palette — pastel/candy body, NOT a pastel rim. Body ramp sampled from the
# Pixellab source (see header); rim is Act 1's hot red (RED RIM PASS, see
# header) so the hazard still reads as dangerous regardless of body colour.
# ---------------------------------------------------------------------------
BODY_LIGHT = _RAMP[0]   # palest lavender highlight
BODY_MID = _RAMP[2]     # solid mid purple
BODY_DARK = _RAMP[-1]   # deepest plum shadow

RIM_HOT = (236, 60, 42)
RIM_DIM = (122, 20, 18)

# Face — a small grump, not a haunted stare: darker than the body so it reads
# as an expression rather than another glow.
FACE_COLOR = (40, 24, 60)
FACE_EYES = {(2, 2), (5, 2)}
FACE_MOUTH = {(3, 5), (4, 5)}
FACE_PIXELS = FACE_EYES | FACE_MOUTH
FACE_VIS = [0.0, 0.0, 0.4, 1.0, 0.6, 0.0]

# ---------------------------------------------------------------------------
# Contour profiles (STATIC, like Act 1's) — rounder than the office sludge:
# no sharp inward notch, just a gentle one-pixel roll at the corner.
# ---------------------------------------------------------------------------
CONTOUR_TOP = [1, 0, 0, 0, 0, 0, 0, 1]
CONTOUR_LEFT = [1, 0, 0, 0, 0, 0, 0, 1]


def _hash(x: int, y: int) -> float:
    h = ((x * 7 + y * 13 + x * y * 3) * 2654435761) & 0xFFFF
    return (h % 100) / 99.0


def _lerp(a: tuple, b: tuple, t: float) -> tuple:
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def _body_color(x: int, y: int) -> tuple:
    t = _hash(x, y)
    if t < 0.4:
        c = _lerp(BODY_DARK, BODY_MID, t / 0.4)
    else:
        c = _lerp(BODY_MID, BODY_LIGHT, (t - 0.4) / 0.6)
    return c + (255,)


def _body_top(x, y):
    if 0 <= x < CELL and 0 <= y < CELL:
        return y >= CONTOUR_TOP[x]
    return y >= 0


def _body_left(x, y):
    if 0 <= x < CELL and 0 <= y < CELL:
        return x >= CONTOUR_LEFT[y]
    return x >= 0


def _body_corner(x, y):
    if 0 <= x < CELL and 0 <= y < CELL:
        return y >= CONTOUR_TOP[x] and x >= CONTOUR_LEFT[y]
    if y < 0 or x < 0:
        return False
    return True


def _body_fill(x, y):
    return True


BODY_FNS = {
    "fill": _body_fill,
    "top": _body_top,
    "left": _body_left,
    "corner": _body_corner,
}


def _is_rim(body_fn, x, y):
    if not body_fn(x, y):
        return False
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        if not body_fn(x + dx, y + dy):
            return True
    return False


def _rim_color(x: int, y: int, frame: int) -> tuple:
    phase = (x * 0.9 + y * 0.6) + frame * (math.tau / FRAMES)
    t = (math.sin(phase) + 1.0) / 2.0
    return _lerp(RIM_DIM, RIM_HOT, t) + (255,)


TILE_TYPES = ["fill", "top", "left", "corner"]


def draw_tile(tile_type: str, frame: int) -> Image.Image:
    body_fn = BODY_FNS[tile_type]
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()

    for y in range(CELL):
        for x in range(CELL):
            if not body_fn(x, y):
                continue
            if _is_rim(body_fn, x, y):
                px[x, y] = _rim_color(x, y, frame)
                continue
            if tile_type == "fill" and (x, y) in FACE_PIXELS:
                vis = FACE_VIS[frame]
                if vis > 0:
                    base = _body_color(x, y)[:3]
                    px[x, y] = _lerp(base, FACE_COLOR, vis) + (255,)
                    continue
            px[x, y] = _body_color(x, y)

    return img


sheet = Image.new("RGBA", (CELL * len(TILE_TYPES), CELL * FRAMES), (0, 0, 0, 0))
for frame in range(FRAMES):
    for col, tile_type in enumerate(TILE_TYPES):
        tile = draw_tile(tile_type, frame)
        sheet.paste(tile, (col * CELL, frame * CELL))

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, "act2_thought_tiles.png")
sheet.save(path)
print("wrote %s  %dx%d  (%d frames x %d tiles)"
      % (path, sheet.width, sheet.height, FRAMES, len(TILE_TYPES)))
