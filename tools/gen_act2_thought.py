#!/usr/bin/env python3
"""Act 2's thought-hazard clouds: a rounder, puffier silhouette in a candy
palette, for the same three-tone mechanic tools/gen_dark_thought.py draws for
Act 1's dread-smoke clouds.

PROCEDURAL, NOT CUT FROM A SOURCE RENDER — unlike gen_dark_thought.py, there is
no Pixellab source strip for a "childhood memory" cloud, and this is a 16x16
prop where hand-drawn flat geometry (the same technique gen_cone_spikes.py and
gen_spring_platform.py use) is entirely sufficient. The shape is a union of
circles — the classic cartoon-cloud silhouette: three base lobes across the
bottom plus two smaller bumps on top — which is also a DELIBERATE shape-language
break from Act 1's ragged, wind-torn smoke outline: round instead of jagged
reads as "a passing bad mood", not "a nightmare".

SAME CONTRACT AS dark_thought.gd EXPECTS, so this drops straight into its
existing frame math with zero script changes to the sprite side: 16x16 CELL,
4 FRAMES in a row (64x16 sheet), and a BREATH — the cloud's drawn height swells
and settles across the loop, never past the cell, same as Act 1's.

SAME RIM COLOUR AS THE SLUDGE TILES (tools/gen_act2_thought_tiles.py's RIM_HOT/
RIM_DIM) — and, as of the RED RIM pass below, THE SAME RED AS ACT 1's, not a
softer candy tint — so the floating clouds and the painted "sludge" hazard
read as the same family of thing at a glance, the way Act 1's clouds and its
sludge tiles share the same red.

Three body ramps, one per tone, all sharing that one rim (same rule
gen_dark_thought.py's TONES table follows — "the same outline" is the point of
every variant):

  dark_thought  (unpleasant) — deep indigo/plum, closest to Act 1's mood but
                still nowhere near black: this is a passing cloud, not dread.
  light_thought (pleasant)   — warm golden-cream.
  grey_thought  (neutral)    — soft lavender-grey, between the two.

WATERCOLOR PASS (2026-09). PALETTE ONLY, THE UNION-OF-CIRCLES SILHOUETTE AND
BREATH LOOP ARE UNCHANGED — same reasoning as gen_act2_thought_tiles.py's
header: this is a small, tiled/repeated hazard prop, exactly the class
experiments/act2_watercolor/README.md's "pulled back, not heavy bleed" call
was made for, and exactly the class this codebase already keeps hand-drawn
rather than bitmap-sourced (see gen_cone_spikes.py). `dark_thought`'s ramp is
read straight from the SAME Pixellab source gen_act2_thought_tiles.py uses
(ldtk/art/source/act2_sludge.png — its darkest/mid/lightest purple stops), so
the painted tiles and the unpleasant-tone cloud share real sampled colour, not
just a similar hand-typed hex. `light_thought` and `grey_thought` have no
Pixellab source of their own (no generation asked for "golden-cream" or
"lavender-grey" specifically); their ramps are hand-tuned the way the
pre-watercolor version already was, kept in the same relationship to each
other — dark reads unpleasant, light reads pleasant, grey sits neutral
between them — per this header's own rule above. RIM_LIT/RIM_DARK are copied
byte-for-byte from gen_act2_thought_tiles.py's RIM_HOT/RIM_DIM; see that
file's header for where those numbers came from.

RED RIM PASS (2026-09). The watercolor pass above had left the rim a soft
candy-pink, on the reasoning that a rounder, pastel-bodied "passing bad mood"
cloud should read as less severe than Act 1's dread-smoke. Reverted on
explicit direction: a thought hazard that no longer reads as dangerous at a
glance is a worse hazard, whatever the body colour says about its mood — so
the rim goes back to being THE SAME HOT RED gen_dark_thought.py uses
(RIM_DARK/RIM_LIT, copied byte-for-byte), on all three tones and on the
CHILDHOOD-palette body colours unchanged. This also makes `_apply_glow()`'s
default `light_color` (dark_thought.gd — hot red, doc'd there as "matching the
rim the art is drawn with") actually true for CHILDHOOD clouds again; under
the candy rim it was a mismatch nothing flagged. Body ramps, silhouette and
breath loop are untouched — only the rim moved.

Re-run after editing: python3 tools/gen_act2_thought.py
"""
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SLUDGE_SOURCE = os.path.join(ROOT, "assets", "hazards", "source", "act2_sludge.png")

CELL = 16
FRAMES = 4
# Same up-and-back-down breath shape as Act 1's BREATH, kept under CELL.
BREATH = [12, 13, 12, 11]


def _ramp_from_source(path, n=8):
    """Top-N most common opaque colours in a Pixellab source, sorted
    brightest to darkest. Same technique as the sibling generators; kept as
    its own copy per this project's self-contained-script convention."""
    img = Image.open(path).convert("RGBA")
    counts = Counter(px[:3] for px in img.getdata() if px[3] > 40)
    colors = [c for c, _ in counts.most_common(n)]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
                reverse=True)
    return colors


_SLUDGE_RAMP = _ramp_from_source(SLUDGE_SOURCE)

# Hot red rim — RED RIM PASS (see header) — the SAME numbers as
# gen_dark_thought.py's RIM_LIT/RIM_DARK (Act 1) and as
# gen_act2_thought_tiles.py's RIM_HOT/RIM_DIM, so the floating clouds and the
# painted sludge still read as one family, and this family still reads as
# dangerous regardless of which Act's cloud it is.
RIM_LIT = (236, 60, 42)
RIM_DARK = (122, 20, 18)

TONES = {
    # Sampled straight from the sludge source's darkest -> mid purple stops —
    # the same image the painted tiles use (see header).
    "dark_thought": (_SLUDGE_RAMP[-1], _SLUDGE_RAMP[2]),      # indigo/plum
    "light_thought": ((248, 202, 132), (255, 244, 214)),  # golden-cream
    "grey_thought": ((150, 142, 168), (206, 200, 220)),   # lavender-grey
}


def ramp(dark, lit, t):
    return tuple(int(round(dark[i] + (lit[i] - dark[i]) * t)) for i in range(3))


def cloud_mask(tall: int):
    """Union-of-circles cloud silhouette, `tall` px high, bottom-anchored in a
    CELLxCELL canvas. Three base lobes plus two smaller top bumps — round and
    puffy, the deliberate opposite of Act 1's jagged smoke."""
    base_y = CELL - 2  # the cloud's flat-ish underside
    scale = tall / 13.0  # 13 is the nominal full height this layout was tuned for
    lobes = [
        # (cx, cy offset above base, radius)
        (4.0, 3.2, 3.6), (8.0, 2.6, 4.4), (12.0, 3.2, 3.6),
        (6.2, 1.0, 2.8), (10.0, 1.0, 2.8),
    ]
    mask = [[False] * CELL for _ in range(CELL)]
    for x in range(CELL):
        for y in range(CELL):
            for cx, cy_off, r in lobes:
                cy = base_y - cy_off * scale
                rr = r * scale
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= rr * rr:
                    mask[x][y] = True
                    break
    return mask


def draw_frame(tall: int, body_dark, body_lit) -> Image.Image:
    mask = cloud_mask(tall)
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()

    ys = [y for x in range(CELL) for y in range(CELL) if mask[x][y]]
    lo, hi = min(ys), max(ys)
    span = max(hi - lo, 1)

    for x in range(CELL):
        for y in range(CELL):
            if not mask[x][y]:
                continue
            edge = any(
                not (0 <= x + dx < CELL and 0 <= y + dy < CELL and mask[x + dx][y + dy])
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            t = 1.0 - (y - lo) / span  # lit from the top, like a puff catching the sun
            rgb = ramp(RIM_DARK, RIM_LIT, t) if edge else ramp(body_dark, body_lit, t)
            px[x, y] = rgb + (255,)
    return img


def main():
    for name, (body_dark, body_lit) in TONES.items():
        sheet = Image.new("RGBA", (CELL * FRAMES, CELL), (0, 0, 0, 0))
        for i, tall in enumerate(BREATH):
            sheet.paste(draw_frame(tall, body_dark, body_lit), (i * CELL, 0))
        path = os.path.join(ROOT, "assets", "hazards", "act2_" + name + ".png")
        sheet.save(path)
        print("wrote %s  %dx%d" % (path, sheet.width, sheet.height))


if __name__ == "__main__":
    main()
