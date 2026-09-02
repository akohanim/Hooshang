#!/usr/bin/env python3
"""Spring platform art: a coiled-spring bounce pad, idle and compressed.

Procedural, not cut from a render — there is no source photo for this prop, so
it is drawn directly with the same "flat-shaded pixel geometry" technique
tools/gen_cone_spikes.py and tools/gen_dark_thought.py use for props with no
photo source.

24x8 is the repeating unit — same TILE size as tools/gen_platforms.py, because
scenes/props/platforms/spring_platform.gd extends Platform and reuses its
tile-laying _rebuild() (see platform.gd's TILE constant); SpringPlatform only
overrides which texture gets applied to each already-built tile
(_after_rebuild), so the art has to tile at the same 24x8 unit or the
last-tile clipping math in platform.gd would crop it wrong.

Two frames, not an animation: IDLE (coil at full height, a zigzag reading as
tension) and COMPRESSED (coil squashed flat, used for one brief beat right on
launch — see spring_platform.gd's _play_bounce). Same "discrete frames stamped
onto the solid tile" idea CrumblingPlatform's damage stages use, not motion
baked into the sheet.

Warm amber/gold metal, matching Act 2's sun-drenched palette (see
tools/gen_act2_tileset_8px.py) rather than Act 1's cold office greys.

WATERCOLOR PASS (2026-09). PALETTE ONLY — THE ZIGZAG GEOMETRY IS UNCHANGED.
This prop's art has to tile at exactly the 24x8 unit platform.gd's _rebuild()
lays copies of (see header above), which a generative image cannot be trusted
to hit; per experiments/act2_watercolor/README.md this is exactly the
"gameplay-critical, tiled, or reduced-small" asset class the pulled-back
watercolor direction was chosen FOR, not a licence to reduce a photo. So this
reads a Pixellab "pulled back" generation purely for its colour ramp —
BASE_HI/BASE/BASE_DARK and COIL_HI/COIL/COIL_DARK are its own most-common
opaque pixels, sorted by luminance — and _zigzag_y()/draw() are byte-for-byte
what they were.

Source: assets/props/spring_platform/source/act2_spring.png (Pixellab
create_image_pixflux, prompt "coiled brass and gold bounce spring mechanism,
mounted on a dark wooden bracket... detailed pixel art with
watercolor-influenced soft gradient shading, clean crisp pixel edges,
restrained painterly bleed... warm sun-drenched palette of gold amber and
bronze", seed 2204).

Re-run after editing: python3 tools/gen_spring_platform.py
"""
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props", "spring_platform")
LDTK_ART = os.path.join(ROOT, "ldtk", "art")
SOURCE = os.path.join(OUT, "source", "act2_spring.png")

TILE_W, TILE_H = 24, 8


def _ramp_from_source(path, n=10):
    """Top-N most common opaque colours in a Pixellab source, sorted
    brightest to darkest. Same technique as the Act 2 hazard generators;
    kept as its own copy per this project's self-contained-script
    convention."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


_RAMP = _ramp_from_source(SOURCE)
# Warm brown/bronze stops (the bracket) vs. gold stops (the coil) separate
# cleanly by saturation/hue — the bracket ramp is close to grey-brown, the
# coil ramp is unambiguously gold — rather than by rank, since the two
# regions interleave in frequency.
_GOLD = [c for c in _RAMP if c[0] > 150 and c[0] - c[2] > 60]
_BRACKET = [c for c in _RAMP if c not in _GOLD]

# Mounting bracket: dark, sits under the coil, the same "stand here" lip job
# the office platform's edge() forcing does.
BASE_HI = _BRACKET[0] + (255,)
BASE = _BRACKET[len(_BRACKET) // 2] + (255,)
BASE_DARK = _BRACKET[-1] + (255,)

# The coil itself: gold, lit along the top of each zigzag stroke.
COIL_HI = tuple(min(255, int(c * 1.08)) for c in _GOLD[0]) + (255,)
COIL = _GOLD[len(_GOLD) // 2] + (255,)
COIL_DARK = _GOLD[-1] + (255,)

BASE_ROWS = 2  # bottom rows: the bracket the coil sits in


def _zigzag_y(x: int, amplitude: int, period: int) -> int:
    """Triangle wave, 0..amplitude, period `period` px."""
    t = x % period
    half = period / 2.0
    if t < half:
        frac = t / half
    else:
        frac = 2.0 - t / half
    return int(round(frac * amplitude))


def draw(amplitude: int, period: int) -> Image.Image:
    """One tile: dark bracket at the bottom, a gold zigzag coil above it.

    `amplitude` is how tall the coil's zigzag swings — full for IDLE (tension
    stored), flattened for COMPRESSED (tension spent).
    """
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    px = img.load()

    # Bracket along the bottom, lit on top like every other standable edge in
    # this project (bricks/platforms all put the highlight where you land).
    for x in range(TILE_W):
        for y in range(TILE_H - BASE_ROWS, TILE_H):
            row = y - (TILE_H - BASE_ROWS)
            px[x, y] = BASE_HI if row == 0 else (BASE if row == 1 else BASE_DARK)

    # Coil zigzag, drawn as a 2px-thick stroke riding the wave, filled down to
    # the bracket so it reads as one coiled spring rather than a floating line.
    coil_top = TILE_H - BASE_ROWS - 1 - amplitude
    for x in range(TILE_W):
        wave_y = (TILE_H - BASE_ROWS - 1) - _zigzag_y(x, amplitude, period)
        for y in range(max(coil_top, 0), TILE_H - BASE_ROWS):
            if y < wave_y - 1:
                continue  # above the stroke at this x: empty (see-through gap)
            shade = COIL_HI if y <= wave_y else (
                COIL if y <= wave_y + 1 else COIL_DARK)
            px[x, y] = shade

    return img


os.makedirs(OUT, exist_ok=True)
os.makedirs(LDTK_ART, exist_ok=True)

# IDLE: tall coil, full tension. COMPRESSED: squashed almost flat.
idle = draw(amplitude=4, period=8)
compressed = draw(amplitude=1, period=8)
idle.save(os.path.join(OUT, "idle.png"))
compressed.save(os.path.join(OUT, "compressed.png"))

# LDtk icon: square, cropped from the idle tile's left end and upscaled.
icon = idle.crop((0, 0, 16, TILE_H)).resize((16, 16), Image.NEAREST)
icon.save(os.path.join(LDTK_ART, "spring_platform.png"))

print("wrote %s idle.png, compressed.png  %dx%d each"
      % (os.path.relpath(OUT, ROOT), TILE_W, TILE_H))
print("wrote %s" % os.path.relpath(os.path.join(LDTK_ART, "spring_platform.png"), ROOT))
