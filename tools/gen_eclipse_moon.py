#!/usr/bin/env python3
"""Turning the office moon into an eclipse, without redrawing the moon.

  assets/background/moon_shadow.png   64x64   the umbra across the disc
  assets/background/moon_halo.png     64x64   the ring of lit air around it

WHY TWO OVERLAYS AND NOT TEN MOONS. The escape row runs a blood moon that
recovers over ten rooms (12 -> 21), and the obvious way to do that is ten drawn
moons. That is ten files to keep in sync with each other, and it puts a slow
visual ramp in the art pipeline where nobody can see it — you cannot tell how
room 15 compares to room 17 without opening both.

Instead: MoonWindow tints the ONE existing moon.png per instance and lays these
two overlays on it at a per-instance strength, so the whole ramp is seven numbers
in ldtk/Act1World.tscn, side by side, readable in one screenful.

BOTH ARE WHITE and carry their shape in the alpha channel only. Colour comes from
the sprite's modulate, which is what makes one file serve a violet umbra at room
12 and a dusty mauve one at room 21.

GEOMETRY IS COPIED FROM moon.png, not guessed: its disc is centred at (31.5,
31.5) with radius 26 on a 64x64 canvas, measured off the alpha channel. These
must sit at the same size and offset as the moon or the shadow's edge will not
follow the limb, which is instantly obvious.

Re-run after editing: python3 tools/gen_eclipse_moon.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "background")

# The umbra shares moon.png's canvas exactly. The halo needs a BIGGER one — see
# HALO_N below — but the same pixel scale and the same centre, so both sprites
# sit at the same position and scale in MoonWindow.tscn and still line up.
N = 64
CX, CY = 31.5, 31.5
R = 26.0

# --- the umbra ------------------------------------------------------------
# Which way the Earth's shadow lies across the disc. Up and to the right, so the
# lit limb is low-left: the arrangement in every photograph of a partial eclipse
# anyone recognises, and the one the reference images use.
SHADOW_DIR = np.array([0.72, -0.70])
# Where the terminator sits across the disc, as a fraction of the radius from
# the centre along SHADOW_DIR. Negative pushes it past the centre so more than
# half the disc is shadowed at full strength.
TERMINATOR = -0.28
# How wide the terminator is, in px. WIDE on purpose: a hard edge reads as a
# bite taken out of the moon. Umbral shadow through an atmosphere is diffuse,
# and the softness is most of what makes it read as an eclipse rather than as a
# crescent phase.
SOFTNESS = 15.0
# The limb never goes fully dark — even at totality there is light bent round
# the Earth, which is the entire reason a blood moon is red rather than absent.
FLOOR = 0.12

# --- the halo -------------------------------------------------------------
#
# TWO FALLOFFS, not one. A single tight ring around the limb left the rest of the
# sky patch as a flat near-black rectangle with a lit moon pasted on it — the sky
# stopped being sky and became a hole in the wall. So: a bright RING hugging the
# limb, plus a broad dim WASH that carries most of the way to the frame.
#
# The wash is the important half and it is why the canvas grew. At 64px the halo
# could not reach past 32px from the moon's centre, which at MoonWindow's 0.5
# scale is 16 window px — the sky patch extends 31px below the moon, so the
# bottom third of every eclipsed window was unlit no matter what.
HALO_N = 96
HALO_C = (HALO_N - 1) / 2.0
HALO_PEAK = R + 1.0
HALO_INNER = 7.0     # falloff going inward from the peak (under the disc)
HALO_RING = 8.5      # the bright ring's falloff going outward
HALO_RING_MAX = 0.46
HALO_WASH = 21.0     # the dim wash's falloff going outward
HALO_WASH_MAX = 0.14
# Hard stop, in px from the moon's centre. The frame is 48px wide and the moon
# sits 3px right of its middle, so anything past 21 window px (42 here) escapes
# the frame and glows on the brick outside the window.
HALO_REACH = 42.0


def disc_mask(d: np.ndarray) -> np.ndarray:
    """1 inside the moon, 0 outside, with one px of antialiased limb — so the
    overlay's edge matches moon.png's own instead of standing proud of it."""
    return np.clip((R - d) / 1.0 + 0.5, 0.0, 1.0)


def main() -> None:
    y, x = np.mgrid[0:N, 0:N]
    dx, dy = x - CX, y - CY
    d = np.hypot(dx, dy)

    # Distance along the shadow's direction, in radii: -1 at the lit limb,
    # +1 at the shadowed one.
    along = (dx * SHADOW_DIR[0] + dy * SHADOW_DIR[1]) / R
    ramp = 1.0 / (1.0 + np.exp(-(along - TERMINATOR) * (R / SOFTNESS) * 2.0))
    shadow = np.clip(FLOOR + (1.0 - FLOOR) * ramp, 0.0, 1.0) * disc_mask(d)

    hy, hx = np.mgrid[0:HALO_N, 0:HALO_N]
    hd = np.hypot(hx - HALO_C, hy - HALO_C)
    inward = np.exp(-(((HALO_PEAK - hd) / HALO_INNER) ** 2))
    ring = np.where(hd < HALO_PEAK, inward,
                    np.exp(-(((hd - HALO_PEAK) / HALO_RING) ** 2))) * HALO_RING_MAX
    wash = np.where(hd < HALO_PEAK, inward,
                    np.exp(-(((hd - HALO_PEAK) / HALO_WASH) ** 2))) * HALO_WASH_MAX
    halo = ring + wash
    # Taper the last few px to nothing rather than clipping, or the wash ends on
    # a visible circle.
    halo *= np.clip((HALO_REACH - hd) / 6.0, 0.0, 1.0)

    os.makedirs(OUT, exist_ok=True)
    for name, alpha in (("moon_shadow", shadow), ("moon_halo", halo)):
        side = alpha.shape[0]
        px = np.zeros((side, side, 4), dtype=np.float64)
        px[:, :, :3] = 255.0
        a = np.where(alpha <= 0.004, 0.0, alpha)   # trim the tail to real zero
        px[:, :, 3] = np.clip(a, 0.0, 1.0) * 255.0
        img = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))
        path = os.path.join(OUT, "%s.png" % name)
        img.save(path)
        print("wrote %s (%dx%d)" % (path, side, side))


if __name__ == "__main__":
    main()
