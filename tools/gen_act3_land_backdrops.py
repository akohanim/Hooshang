#!/usr/bin/env python3
"""Act III's way home, painted: the backdrops of the six rooms after the real sea
(SCRIPT.md ELEVEN to THIRTEEN; rooms Act3_Level_26..31 in tools/act3_rooms.py).

He thinks he made it out, so these are the most beautiful rooms in the game: a
coast road over the dunes, a high meadow with one lemon tree, tall grass, a wood,
the rocks of a headland, and the edge of a cliff above a valley. One morning
palette runs through all six, so they read as one walk.

These are one-off, native-resolution set pieces (never reduced onto the 8px
grid), the case CLAUDE.md's art rules leave open for painterly work. They are
still pixel art: every gradient is an ordered (Bayer) dither between flat
colours, and every edge is a hard pixel edge.

Each painting knows its room: grass, flowers and tree roots are planted along
the room's real ground line (read from tools/act3_rooms.py), so they stand on
the terrain the player walks on. Deterministic: every random draw is seeded by
the room, so re-running rebuilds the same pixels.

    python3 tools/gen_act3_land_backdrops.py          # writes assets/act3/land/*.png
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/act3/land'
sys.path.insert(0, str(Path(__file__).resolve().parent))

W = 320

BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=float)


# One morning, all six rooms.
P = {k: hexc(v) for k, v in {
    'sky_top': '#3d63a8', 'sky_hi': '#5a85c4', 'sky_mid': '#86aedb', 'sky_low': '#b9d0e6',
    'haze': '#e9dcc6', 'gold': '#f6cf8e', 'gold_hi': '#fbe6b8', 'sun': '#fff6d8', 'sun_glow': '#ffe6a6',
    'cloud_lit': '#fff1dc', 'cloud_mid': '#f1d9c4', 'cloud_shade': '#c9b3b9', 'cloud_dark': '#a297ad',
    'far_mtn': '#8ea6c8', 'far_mtn_lit': '#b9c6dc', 'far_hill': '#7f9fb0', 'far_hill_lit': '#a6bfb8',
    'hill': '#5f8a63', 'hill_lit': '#86ad66', 'hill_dark': '#476f52',
    'near': '#3f6f3e', 'near_lit': '#6f9e48', 'near_dark': '#2e5333',
    'grass': '#5f9a3f', 'grass_lit': '#9cc456', 'grass_hi': '#cfe27a', 'grass_dark': '#3b6b33',
    'gold_grass': '#c9b45a', 'gold_grass_lit': '#e8d27a', 'gold_grass_dark': '#9a8a46',
    'sand': '#e6c995', 'sand_lit': '#f3dfb0', 'sand_dark': '#c9a874',
    'sea': '#3f74ac', 'sea_far': '#6f9cc9', 'sea_lit': '#a9cdea', 'glint': '#fff5cf',
    'trunk': '#5a3f2c', 'trunk_dark': '#3d2a20', 'trunk_lit': '#7d5a3c',
    'leaf': '#3e7340', 'leaf_dark': '#2a5233', 'leaf_lit': '#74a84b', 'leaf_hi': '#a9cf62',
    'pine': '#2f5a46', 'pine_dark': '#1f3f35', 'pine_lit': '#4f7f55',
    'lemon': '#f6d43c', 'lemon_hi': '#fff08a', 'lemon_dark': '#d0a52a',
    'poppy': '#d9423a', 'poppy_dark': '#9c2b2b', 'daisy': '#f6f1e2', 'gorse': '#f0c23b', 'violet': '#9a7cc7',
    'rock': '#8a837c', 'rock_lit': '#b2aaa0', 'rock_dark': '#5e5853', 'rock_far': '#9fa3ab',
    'mist': '#e4e9ee', 'shadow': '#24313a', 'bird': '#3b3a46',
    'wood_fog': '#6e8c78', 'wood_fog_far': '#93ad99', 'wood_back': '#4d6d58',
}.items()}


class Canvas:
    def __init__(self, h, seed):
        self.h = h
        self.px = np.zeros((h, W, 3))
        self.rng = random.Random(seed)
        ys, xs = np.mgrid[0:h, 0:W]
        self.bayer = BAYER[ys % 4, xs % 4]

    # -- primitives -------------------------------------------------------
    def blend(self, alpha, colour):
        """Paint `colour` where an ordered dither says the coverage `alpha`
        (array or scalar per pixel, 0..1) wins. Hard pixels, soft-looking edges."""
        mask = np.asarray(alpha) > self.bayer
        self.px[mask] = colour

    def gradient(self, stops, y0=0, y1=None, steps=7, soft=0.35):
        """Vertical gradient through `stops` [(t, colour)...], painted the way a
        pixel artist paints a sky: `steps` flat bands between each pair of
        stops, dithered only along the seam between two bands."""
        y1 = self.h if y1 is None else y1
        ts = [t for t, _ in stops]
        cols = [c for _, c in stops]
        for y in range(y0, y1):
            t = (y - y0) / max(1, (y1 - y0 - 1))
            i = 0
            while i < len(ts) - 2 and t > ts[i + 1]:
                i += 1
            f = min(1.0, max(0.0, (t - ts[i]) / max(1e-6, ts[i + 1] - ts[i])))
            lvl = f * steps
            k = int(lvl)
            frac = lvl - k
            lo = cols[i] + (cols[i + 1] - cols[i]) * min(1.0, k / steps)
            hi = cols[i] + (cols[i + 1] - cols[i]) * min(1.0, (k + 1) / steps)
            up = (self.bayer[y] - 0.5) * soft + 0.5 < frac
            self.px[y][~up] = lo
            self.px[y][up] = hi

    def bands(self, alpha, colour_from, colour_to, steps=5, soft=0.3, floor=0.02):
        """Paint a 0..1 field as flat bands from colour_from (low) to colour_to
        (high), dithered only at the seams. Below `floor` nothing is painted."""
        a = np.clip(np.asarray(alpha, dtype=float), 0, 1)
        lvl = a * steps
        k = np.floor(lvl)
        frac = lvl - k
        k = k + ((self.bayer - 0.5) * soft + 0.5 < frac)
        k = np.clip(k, 0, steps)
        for i in range(1, steps + 1):
            m = (k == i) & (a > floor)
            self.px[m] = colour_from + (colour_to - colour_from) * (i / steps)

    def disc(self, cx, cy, r, colour):
        ys, xs = np.ogrid[0:self.h, 0:W]
        self.px[(xs - cx) ** 2 + (ys - cy) ** 2 <= r * r] = colour

    def glow(self, cx, cy, r, colour, strength=1.0, power=2.0, steps=5):
        """A soft radial light, as rings of flat colour blended toward `colour`."""
        ys, xs = np.ogrid[0:self.h, 0:W]
        d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / r
        a = np.clip(1.0 - d, 0, 1) ** power * strength
        lvl = np.floor(a * steps + ((self.bayer - 0.5) * 0.3))
        for i in range(1, steps + 1):
            m = lvl >= i
            t = 0.22 * i / steps
            self.px[m] = self.px[m] * (1 - t) + colour * t

    def fill_below(self, ys_of_x, colour, top_colour=None, rim=1, x0=0, x1=W, deep=None, depth=40,
                   speckle=None, speckle_rate=0.0, bottom=None):
        """Fill under a ridge line y(x) between x0 and x1; a lit rim along the
        top, darkening in bands toward `deep` over `depth` px, and an optional
        speckle of texture (fields, scrub, stones)."""
        bottom = self.h if bottom is None else bottom
        rng = self.rng
        for x in range(max(0, x0), min(W, x1)):
            y = int(round(ys_of_x[x]))
            if y >= bottom:
                continue
            y = max(0, y)
            col = np.tile(colour, (bottom - y, 1))
            if deep is not None:
                for k in range(bottom - y):
                    t = min(1.0, k / depth)
                    lvl = math.floor(t * 3 + (BAYER[(y + k) % 4, x % 4] - 0.5) * 0.4) / 3
                    col[k] = colour + (deep - colour) * max(0.0, min(1.0, lvl))
            self.px[y:bottom, x] = col
            if speckle is not None:
                for k in range(2, bottom - y):
                    if rng.random() < speckle_rate:
                        self.px[y + k, x] = speckle
            if top_colour is not None:
                self.px[y:min(bottom, y + rim), x] = top_colour

    def ridge(self, base, amps, seed_off=0.0):
        """A smooth ridge: base + a few sines, per x."""
        rng = random.Random(self.rng.random() + seed_off)
        waves = [(a, rng.uniform(0.6, 1.4) * f, rng.uniform(0, math.tau)) for a, f in amps]
        return np.array([base + sum(a * math.sin(f * x + p) for a, f, p in waves) for x in range(W)])

    def put(self, x, y, colour):
        if 0 <= x < W and 0 <= y < self.h:
            self.px[y, x] = colour

    def rect(self, x0, y0, x1, y1, colour):
        self.px[max(0, y0):max(0, min(self.h, y1)), max(0, x0):max(0, min(W, x1))] = colour

    def save(self, name):
        OUT.mkdir(parents=True, exist_ok=True)
        Image.fromarray(np.clip(self.px, 0, 255).astype(np.uint8)).save(OUT / f'{name}.png')

    # -- motifs -----------------------------------------------------------
    def sky(self, warm=0.55, top=None):
        """Morning sky: blue overhead, warming toward the horizon line."""
        h = self.h if top is None else top
        self.gradient([(0.0, P['sky_top']), (0.35, P['sky_hi']), (0.65, P['sky_mid']),
                       (0.85, P['sky_low']), (1.0, P['haze'] * warm + P['sky_low'] * (1 - warm))], 0, h)

    def cloud(self, cx, cy, w, h, lit_side=1):
        """A soft cumulus: a few overlapping ellipses, lit along the top on the
        sun's side, shaded underneath."""
        rng = self.rng
        blobs = [(cx + rng.uniform(-w * 0.4, w * 0.4), cy + rng.uniform(-h * 0.25, h * 0.1),
                  rng.uniform(w * 0.25, w * 0.45), rng.uniform(h * 0.45, h * 0.75)) for _ in range(5)]
        blobs.append((cx, cy + h * 0.15, w * 0.55, h * 0.4))
        ys, xs = np.ogrid[0:self.h, 0:W]
        cover = np.zeros((self.h, W))
        for bx, by, bw, bh in blobs:
            d = ((xs - bx) / bw) ** 2 + ((ys - by) / bh) ** 2
            cover = np.maximum(cover, np.clip(1.15 - d, 0, 1))
        # Shading from the vertical position inside the cloud.
        rel = np.clip((ys - (cy - h * 0.6)) / (h * 1.3), 0, 1) + np.zeros_like(cover)
        side = np.clip(((xs - cx) * lit_side) / (w * 1.2), -0.3, 0.3) + np.zeros_like(cover)
        shade = rel - side
        self.blend(np.where(cover > 0.15, np.clip(cover * 3, 0, 1), 0), P['cloud_dark'])
        self.blend(np.where((cover > 0.2) & (shade < 0.85), np.clip(cover * 3, 0, 1), 0), P['cloud_shade'])
        self.blend(np.where((cover > 0.25) & (shade < 0.6), np.clip(cover * 3, 0, 1), 0), P['cloud_mid'])
        self.blend(np.where((cover > 0.3) & (shade < 0.35), np.clip(cover * 3, 0, 1), 0), P['cloud_lit'])

    def birds(self, n, x0, x1, y0, y1):
        for _ in range(n):
            x = self.rng.randint(x0, x1)
            y = self.rng.randint(y0, y1)
            for dx, dy in [(-2, -1), (-1, 0), (1, 0), (2, -1)]:
                self.put(x + dx, y + dy, P['bird'])

    def sea_band(self, y0, y1, x0=0, x1=W, sun_x=None):
        """Flat sea under a horizon, darkening toward the viewer, with glints."""
        span = max(1, y1 - y0)
        for y in range(y0, y1):
            t = (y - y0) / span
            c = P['sea_far'] if t < 0.35 else P['sea']
            self.px[y, x0:x1] = c
            if t >= 0.25 and t < 0.4:
                row = self.bayer[y, x0:x1] < (0.4 - t) * 4
                self.px[y, x0:x1][row] = P['sea_far']
        rng = self.rng
        for _ in range(int((x1 - x0) * span / 18)):
            x = rng.randint(x0, x1 - 4)
            y = rng.randint(y0 + 1, y1 - 1)
            near_sun = sun_x is not None and abs(x - sun_x) < 60
            n = rng.randint(2, 6 if near_sun else 3)
            c = P['glint'] if near_sun and rng.random() < 0.6 else P['sea_lit']
            self.px[y, x:x + n] = c

    def pine(self, x, base, h, scale=1.0, lit=1, dark=None, mid=None, light=None):
        """A pine: stacked tiers, lit on the sun's side."""
        dark = P['pine_dark'] if dark is None else dark
        mid = P['pine'] if mid is None else mid
        light = P['pine_lit'] if light is None else light
        self.rect(x, base - int(h * 0.15), x + max(1, int(2 * scale)), base, P['trunk_dark'])
        tiers = max(3, int(h / 7))
        for i in range(tiers):
            ty = base - int(h * 0.12) - int(i * (h * 0.85) / tiers)
            half = int((tiers - i) * 2.2 * scale) + 1
            th = int(h * 0.85 / tiers) + 3
            for k in range(th):
                w = int(half * (k + 1) / th)
                y = ty - th + k
                for dx in range(-w, w + 1):
                    c = mid
                    if dx * lit > w * 0.35:
                        c = light
                    elif dx * lit < -w * 0.4 or k == th - 1:
                        c = dark
                    self.put(x + dx, y, c)

    def round_tree(self, x, base, h, fruit=None, lit=1, palette=None):
        """A broad tree: trunk, then a canopy of overlapping lit/shaded blobs."""
        dark, mid, light, hi = palette or (P['leaf_dark'], P['leaf'], P['leaf_lit'], P['leaf_hi'])
        rng = self.rng
        trunk_h = int(h * 0.42)
        self.rect(x - 1, base - trunk_h, x + 2, base, P['trunk'])
        self.rect(x + 1, base - trunk_h, x + 2, base, P['trunk_dark'])
        self.put(x - 2, base - 1, P['trunk']); self.put(x + 2, base - 1, P['trunk_dark'])
        # two branches into the crown
        for i in range(5):
            self.put(x - 1 - i // 2, base - trunk_h - i, P['trunk'])
            self.put(x + 2 + i // 2, base - trunk_h - i, P['trunk_dark'])
        cy = base - trunk_h - int(h * 0.25)
        r = h * 0.38
        blobs = [(x + rng.uniform(-r * 0.7, r * 0.7), cy + rng.uniform(-r * 0.5, r * 0.4), rng.uniform(r * 0.45, r * 0.7))
                 for _ in range(9)]
        ys, xs = np.ogrid[0:self.h, 0:W]
        cover = np.zeros((self.h, W), dtype=bool)
        for bx, by, br in blobs:
            cover |= (xs - bx) ** 2 + ((ys - by) * 1.15) ** 2 <= br * br
        yy, xx = np.nonzero(cover)
        for y, xpix in zip(yy, xx):
            u = (xpix - x) / r * lit
            v = (y - cy) / r
            s = u * 0.55 - v * 0.75 + rng.uniform(-0.25, 0.25)
            c = dark if s < -0.45 else mid if s < 0.15 else light if s < 0.6 else hi
            self.px[y, xpix] = c
        if fruit is not None:
            for _ in range(int(r * 1.6)):
                i = rng.randrange(len(yy))
                fy, fx = yy[i], xx[i]
                if abs(fx - x) < r * 0.95 and fy > cy - r * 0.6:
                    self.put(fx, fy, fruit[0]); self.put(fx + 1, fy, fruit[0])
                    self.put(fx, fy + 1, fruit[1]); self.put(fx + 1, fy + 1, fruit[2])

    def grass_line(self, ground, palette, height=(1, 4), density=0.9, flowers=(), flower_rate=0.0,
                   tall=None):
        """Blades and flowers planted along the room's ground line (ground[x] =
        the first terrain pixel row in column x, or None for no ground)."""
        dark, mid, lit, hi = palette
        rng = self.rng
        for x in range(W):
            g = ground[x]
            if g is None:
                continue
            if rng.random() < density:
                hgt = rng.randint(*height)
                if tall is not None and rng.random() < tall[0]:
                    hgt = rng.randint(*tall[1])
                lean = rng.choice([-1, 0, 0, 1]) if hgt > 4 else 0
                for k in range(hgt):
                    c = dark if k == 0 else (hi if k == hgt - 1 and rng.random() < 0.5 else (lit if k > hgt // 2 else mid))
                    self.put(x + (lean if k > hgt * 0.6 else 0), g - 1 - k, c)
            if flowers and rng.random() < flower_rate:
                petal, centre = rng.choice(flowers)
                stem = rng.randint(2, 5)
                for k in range(stem):
                    self.put(x, g - 1 - k, P['grass_dark'] if k < stem - 1 else mid)
                top = g - 1 - stem
                self.put(x, top, centre)
                self.put(x - 1, top, petal); self.put(x + 1, top, petal); self.put(x, top - 1, petal)

    def mist(self, y, thickness, colour=None, strength=0.6):
        """A soft horizontal band of haze: flat bands that thin away from its
        middle, blended a little toward `colour` each step."""
        colour = P['mist'] if colour is None else colour
        ys = np.arange(self.h)[:, None] + np.zeros((1, W))
        a = np.clip(1 - np.abs(ys - y) / thickness, 0, 1) ** 1.2 * strength
        lvl = np.floor(a * 4 + (self.bayer - 0.5) * 0.25)
        for i in range(1, 5):
            m = lvl >= i
            self.px[m] = self.px[m] * 0.82 + colour * 0.18

    def shafts(self, x0, angle, width, gap, count, colour, strength=0.28, top=0, bottom=None):
        """Diagonal light shafts (dithered, so they read as light, not paint)."""
        bottom = self.h if bottom is None else bottom
        ys, xs = np.mgrid[0:self.h, 0:W]
        u = xs - ys * math.tan(angle)
        a = np.zeros((self.h, W))
        for i in range(count):
            c = x0 + i * gap
            a = np.maximum(a, np.clip(1 - np.abs(u - c) / width, 0, 1))
        fade = np.clip((ys - top) / 40.0, 0, 1) * np.clip((bottom - ys) / 60.0, 0, 1)
        self.blend(a * strength * fade, colour)


def ground_of(room):
    """Per pixel column, the y of the first solid terrain pixel from the top of
    the room's open air (None where a column has no ground in view)."""
    g = []
    for x in range(W):
        c = x // 8
        top = None
        for y in range(1, room.h):
            if room.ch(c, y) in 'g#':
                top = y * 8
                break
        g.append(top)
    return g


def rooms():
    import act3_rooms
    return {r.name: r for r in act3_rooms.ROOMS}


GRASS = (P['grass_dark'], P['grass'], P['grass_lit'], P['grass_hi'])
GOLD_GRASS = (P['gold_grass_dark'], P['gold_grass'], P['gold_grass_lit'], P['gold_grass_lit'])


# ------------------------------------------------------------------ rooms --

def shore_road(room):
    """Over the dunes: the sun still low behind him on the left, the sea and its
    glitter falling away behind, a pine headland ahead on the right."""
    c = Canvas(room.h * 8, 26)
    c.gradient([(0.0, P['sky_top']), (0.35, P['sky_hi']), (0.6, P['sky_mid']), (0.8, P['sky_low']),
                (0.92, P['haze']), (1.0, P['gold'])], 0, 106)
    c.glow(-30, 104, 230, P['gold_hi'], 1.0, 1.3, steps=6)
    c.glow(-30, 104, 110, P['sun_glow'], 1.0, 1.2, steps=4)
    c.cloud(78, 30, 46, 11, lit_side=-1)
    c.cloud(206, 18, 62, 12, lit_side=-1)
    c.cloud(300, 44, 30, 8, lit_side=-1)
    c.sea_band(104, 192, 0, W, sun_x=0)
    c.glow(-30, 104, 140, P['glint'], 0.6, 1.6, steps=3)
    # the headland ahead: a long ridge rising out of the sea on the right
    head = np.array([104 - max(0.0, x - 150) * 0.30 + 2.5 * math.sin(x * 0.07) for x in range(W)])
    c.fill_below(head, P['far_hill'], P['far_hill_lit'], rim=1, x0=150, deep=P['hill_dark'], depth=60,
                 speckle=P['far_mtn'], speckle_rate=0.03)
    for x, h in [(206, 12), (219, 16), (230, 14), (243, 19), (256, 17), (268, 22), (281, 19), (294, 24), (308, 21)]:
        c.pine(x, int(head[x]) + 3, h, 0.75, lit=-1, dark=P['hill_dark'], mid=P['far_hill'] * 0.8 + P['hill'] * 0.2,
               light=P['far_hill_lit'])
    # dunes rising toward the road, marram grass on their crests
    dune = np.array([150 - max(0.0, x - 40) * 0.16 + 4 * math.sin(x * 0.045) + 2 * math.sin(x * 0.13) for x in range(W)])
    c.fill_below(dune, P['sand'], P['sand_lit'], rim=2, x0=20, deep=P['sand_dark'], depth=30)
    rng = c.rng
    for x in range(22, W, 2):
        if rng.random() < 0.55:
            top = int(dune[x])
            for k in range(rng.randint(2, 7)):
                c.put(x + (1 if k > 4 else 0), top - 1 - k,
                      P['gold_grass_dark'] if k < 2 else (P['gold_grass_lit'] if k > 3 else P['gold_grass']))
    c.birds(4, 110, 250, 34, 66)
    c.grass_line(ground_of(room), (P['grass_dark'], P['gold_grass'], P['gold_grass_lit'], P['grass_hi']),
                 height=(1, 5), density=0.75, tall=(0.25, (6, 10)),
                 flowers=[(P['violet'], P['gorse']), (P['daisy'], P['gorse']), (P['gorse'], P['lemon_dark'])],
                 flower_rate=0.08)
    c.save('shore_road')


def high_meadow(room):
    """The high meadow above the sea: blue mountains, valleys of mist, the lit
    green hills, poppies everywhere, and one lemon tree on the brow."""
    c = Canvas(room.h * 8, 27)
    c.gradient([(0.0, P['sky_top']), (0.4, P['sky_hi']), (0.75, P['sky_mid']), (0.92, P['sky_low']),
                (1.0, P['haze'])], 0, 96)
    c.glow(20, 10, 190, P['gold_hi'], 0.9, 1.5, steps=5)
    c.cloud(130, 26, 70, 13, lit_side=-1)
    c.cloud(262, 14, 44, 9, lit_side=-1)
    c.cloud(40, 50, 28, 7, lit_side=-1)
    # far mountains, snow along their crests
    mtn = c.ridge(70, [(11, 0.024), (5, 0.062), (2, 0.16)])
    c.fill_below(mtn, P['far_mtn'], P['far_mtn_lit'], rim=1, deep=P['far_hill'], depth=30)
    for x in range(W):
        y = int(mtn[x])
        cap = int(max(0, 66 - y) * 0.6)
        if cap:
            c.rect(x, y, x + 1, y + cap, P['mist'])
            if x % 2 == 0:
                c.put(x, y + cap, P['far_mtn_lit'])
    c.mist(84, 7, strength=0.7)
    c.sea_band(84, 96, 0, 90)
    far = c.ridge(88, [(5, 0.035), (2, 0.09)])
    c.fill_below(far, P['far_hill'], P['far_hill_lit'], rim=1, deep=P['hill_dark'], depth=40,
                 speckle=P['hill_dark'], speckle_rate=0.04)
    c.mist(94, 5, strength=0.5)
    hills = c.ridge(100, [(6, 0.028), (2, 0.08)])
    c.fill_below(hills, P['hill'], P['hill_lit'], rim=2, deep=P['hill_dark'], depth=30,
                 speckle=P['hill_lit'], speckle_rate=0.04)
    rng = c.rng
    # copses and hedgerows on the hills
    for x in range(4, W, 3):
        if rng.random() < 0.12:
            c.round_tree(x, int(hills[x]) + 3, rng.randint(7, 11),
                         palette=(P['hill_dark'], P['hill_dark'] * 0.6 + P['hill'] * 0.4, P['hill'], P['hill_lit']))
    # the lemon tree on the brow of the hill (the room's highest ground)
    g = ground_of(room)
    c.round_tree(150, g[150], 66, fruit=(P['lemon'], P['lemon_hi'], P['lemon_dark']), lit=-1)
    c.grass_line(g, GRASS, height=(2, 6), density=0.95, tall=(0.2, (6, 9)),
                 flowers=[(P['poppy'], P['poppy_dark']), (P['poppy'], P['poppy_dark']), (P['daisy'], P['gorse'])],
                 flower_rate=0.22)
    c.birds(3, 190, 300, 30, 56)
    c.save('high_meadow')


def tall_grass(room):
    """Tall grass, gold and green, rising higher than he is; the wood dark
    ahead. Quiet. Something could be in it."""
    c = Canvas(room.h * 8, 28)
    c.sky(warm=0.35)
    c.cloud(80, 26, 60, 12, lit_side=-1)
    c.cloud(230, 40, 40, 9, lit_side=-1)
    far = c.ridge(98, [(6, 0.03), (2, 0.1)])
    c.fill_below(far, P['far_hill'], P['far_hill_lit'], rim=2)
    c.mist(104, 8, strength=0.5)
    # the wood's edge on the right
    edge = np.array([128 - max(0, x - 170) * 0.25 for x in range(W)])
    c.fill_below(edge, P['wood_back'])
    for x in range(176, W + 8, 7):
        c.pine(x + c.rng.randint(-2, 2), int(edge[min(W - 1, x)]) + 4, c.rng.randint(30, 52), 1.1, lit=-1)
    for x in range(150, 200, 9):
        c.round_tree(x, 132, c.rng.randint(22, 30), lit=-1)
    back = c.ridge(132, [(3, 0.05)])
    c.fill_below(back, P['gold_grass_dark'], P['gold_grass'], rim=1)
    # a sea of grass heads above the back line
    for x in range(W):
        for _ in range(2):
            if c.rng.random() < 0.7:
                hgt = c.rng.randint(4, 14)
                base = int(back[x]) + c.rng.randint(0, 6)
                for k in range(hgt):
                    c.put(x, base - k, P['gold_grass_lit'] if k > hgt - 3 else P['gold_grass'])
    c.grass_line(ground_of(room), GOLD_GRASS, height=(4, 12), density=1.0, tall=(0.35, (12, 22)),
                 flowers=[(P['daisy'], P['gorse'])], flower_rate=0.02)
    c.save('tall_grass')


def wood(room):
    """Inside the wood: trunks in three depths of fog, the canopy overhead, and
    shafts of morning light coming through it."""
    c = Canvas(room.h * 8, 29)
    c.gradient([(0.0, P['leaf_dark']), (0.35, P['wood_fog']), (0.7, P['wood_fog_far']), (1.0, P['wood_fog'])])
    rng = c.rng
    for depth, colour, wmin, wmax, step in [(0, P['wood_fog_far'] * 0.92, 3, 5, 26),
                                            (1, P['wood_back'], 5, 8, 34), (2, P['trunk_dark'], 8, 12, 47)]:
        x = rng.randint(-10, 10)
        while x < W + 10:
            w = rng.randint(wmin, wmax)
            c.rect(x, 0, x + w, c.h, colour)
            if depth == 2:
                c.rect(x + w - 2, 0, x + w, c.h, P['trunk'])
                c.rect(x, 0, x + 1, c.h, P['trunk_dark'] * 0.8)
            x += step + rng.randint(-6, 8)
    c.shafts(-40, math.radians(-22), 7, 58, 7, P['gold_hi'], strength=0.32, top=10)
    # the canopy
    ys, xs = np.ogrid[0:c.h, 0:W]
    cover = np.zeros((c.h, W))
    for _ in range(40):
        bx, by, br = rng.uniform(-10, W + 10), rng.uniform(-14, 26), rng.uniform(10, 22)
        cover = np.maximum(cover, np.clip(1.2 - ((xs - bx) ** 2 + ((ys - by) * 1.3) ** 2) / (br * br), 0, 1))
    c.blend(np.clip(cover * 2, 0, 1), P['leaf_dark'])
    c.blend(np.where(cover > 0.6, np.clip((cover - 0.6) * 3, 0, 1), 0) * (np.arange(c.h)[:, None] < 30), P['leaf'])
    for _ in range(160):
        x, y = rng.randint(0, W - 1), rng.randint(0, 30)
        if cover[y, x] > 0.3:
            c.put(x, y, P['leaf_lit'] if rng.random() < 0.7 else P['leaf_hi'])
    c.mist(118, 12, P['wood_fog_far'], strength=0.4)
    g = ground_of(room)
    c.grass_line(g, (P['leaf_dark'], P['leaf'], P['leaf_lit'], P['leaf_hi']), height=(2, 6), density=0.8,
                 tall=(0.12, (7, 10)), flowers=[(P['daisy'], P['gorse']), (P['violet'], P['gorse'])],
                 flower_rate=0.03)
    # ferns: little fans either side of a stem
    for x in range(4, W - 4, 11):
        if g[x] is None or rng.random() < 0.4:
            continue
        base = g[x]
        for k in range(6):
            c.put(x, base - 1 - k, P['leaf'])
            if k % 2 == 0:
                c.put(x - 1 - k // 2, base - 1 - k, P['leaf_lit']); c.put(x + 1 + k // 2, base - 1 - k, P['leaf'])
    c.save('wood')


def rocks(room):
    """The headland: the wind, gorse in flower, a bent pine, and the sea far
    below on the right where the land is running out."""
    c = Canvas(room.h * 8, 30)
    c.gradient([(0.0, P['sky_top']), (0.4, P['sky_hi']), (0.75, P['sky_mid']), (0.92, P['sky_low']),
                (1.0, P['haze'])], 0, 88)
    c.glow(-20, 40, 200, P['gold_hi'], 0.8, 1.5, steps=5)
    c.cloud(66, 30, 54, 11, lit_side=-1)
    c.cloud(200, 20, 70, 13, lit_side=-1)
    c.cloud(300, 50, 30, 7, lit_side=-1)
    c.sea_band(88, 192, 0, W, sun_x=-60)
    # a far coast across the bay on the left
    coast = np.array([88 - max(0.0, 110 - x) * 0.18 + 1.5 * math.sin(x * 0.11) for x in range(W)])
    c.fill_below(coast, P['rock_far'], P['far_mtn_lit'], rim=1, x1=110, bottom=96)
    # the headland falling away to the sea on the right: grassy top, rock face
    head = np.array([106 + max(0.0, x - 200) * 0.55 + 2 * math.sin(x * 0.21) for x in range(W)])
    c.fill_below(head, P['rock'], P['grass_lit'], rim=2, x0=0, deep=P['rock_dark'], depth=40,
                 speckle=P['rock_lit'], speckle_rate=0.04)
    rng = c.rng
    ys, xs = np.ogrid[0:c.h, 0:W]
    for _ in range(10):
        bx, by, br = rng.randint(0, 220), rng.randint(104, 114), rng.randint(5, 10)
        m = (xs - bx) ** 2 + ((ys - by) * 1.4) ** 2 <= br * br
        c.px[m] = P['rock']
        c.px[m & ((xs - bx) < -br * 0.2) & ((ys - by) < 0)] = P['rock_lit']
        c.px[m & ((xs - bx) > br * 0.35)] = P['rock_dark']
    # gorse bushes along the slope
    for x in range(8, 220, 13):
        y = int(head[x]) + 1
        for k in range(18):
            dx, dy = rng.randint(-5, 5), rng.randint(-4, 0)
            c.put(x + dx, y + dy, P['near'] if k < 8 else P['gorse'])
    # a wind-bent pine at the edge of the land
    base = int(head[256]) + 1
    for i in range(30):
        c.put(256 + i // 4, base - i, P['trunk_dark']); c.put(257 + i // 4, base - i, P['trunk'])
    for dx, dy, w in [(6, -30, 20), (9, -24, 24), (12, -18, 18)]:
        for y in range(4):
            for x in range(w):
                c.put(256 + dx + x - 4, base + dy + y - (1 if x > w // 2 else 0), P['pine'] if y < 2 else P['pine_dark'])
                if y == 0 and x % 3 == 0:
                    c.put(256 + dx + x - 4, base - 1 + dy, P['pine_lit'])
    g = ground_of(room)
    c.grass_line(g, (P['grass_dark'], P['grass'], P['grass_lit'], P['grass_hi']), height=(1, 4), density=0.6,
                 flowers=[(P['gorse'], P['lemon_dark']), (P['gorse'], P['lemon_dark']), (P['daisy'], P['gorse'])],
                 flower_rate=0.12)
    c.birds(3, 150, 300, 50, 80)
    c.save('rocks')


def edge(room):
    """The edge: two screens tall. Sky and clouds over the cliff top; across the
    gap, the ravine falling away in layers of mist to a valley far below, with
    trees and a stream, where the second tiger waits."""
    c = Canvas(room.h * 8, 31)
    H = c.h
    c.gradient([(0.0, P['sky_top']), (0.3, P['sky_hi']), (0.6, P['sky_mid']), (0.85, P['sky_low']),
                (1.0, P['haze'])], 0, 150)
    c.gradient([(0.0, P['haze']), (0.35, P['far_hill_lit']), (0.75, P['far_hill']), (1.0, P['wood_fog'])], 150, H)
    c.glow(-20, 30, 200, P['gold_hi'], 0.8, 1.5, steps=5)
    c.cloud(90, 30, 64, 13, lit_side=-1)
    c.cloud(240, 50, 50, 10, lit_side=-1)
    rng = c.rng
    # far hills seen down the ravine, three layers fading into the haze
    for base, col, lit, step in [(110, P['far_mtn'], P['far_mtn_lit'], 0), (170, P['far_hill'], P['far_hill_lit'], 1),
                                 (240, P['hill_dark'], P['hill'], 2)]:
        ridge = c.ridge(base, [(10, 0.03), (4, 0.09)])
        c.fill_below(ridge, col, lit, rim=1, x0=150, deep=col * 0.85 + P['wood_fog'] * 0.15, depth=50,
                     speckle=col * 0.9, speckle_rate=0.03)
        c.mist(base + 18, 16, strength=0.6)
    # the far wall of the ravine, close behind the gap on the right
    wall_left = np.array([272 + 6 * math.sin(y * 0.045) + 3 * math.sin(y * 0.17) for y in range(H)])
    for y in range(74, H):
        x0 = int(wall_left[y])
        c.px[y, x0:] = P['rock']
        c.px[y, x0:x0 + 2] = P['rock_lit']
        for x in range(x0 + 2, W):
            if (x * 7 + y * 3) % 23 == 0 or rng.random() < 0.04:
                c.px[y, x] = P['rock_dark']
    for y in range(120, H - 70, 46):
        x0 = int(wall_left[y]) - 2
        c.rect(x0, y, x0 + 24, y + 3, P['rock_lit'])
        c.round_tree(x0 + 10, y, 15, palette=(P['near_dark'], P['near'], P['near_lit'], P['grass_hi']))
    # a thread of waterfall down the far wall
    for y in range(140, 352):
        x = int(wall_left[y]) + 6
        c.put(x, y, P['mist'] if (y // 3) % 2 else P['sea_lit'])
        c.put(x + 1, y, P['sea_lit'])
    c.mist(300, 26, strength=0.5)
    cliff_face(c, rng)
    # the valley floor: trees and a stream
    for x in range(196, W, 13):
        c.round_tree(x + rng.randint(-3, 3), 352, rng.randint(24, 38), lit=-1)
    c.rect(196, 349, W, 351, P['sea_lit'])
    g = ground_of(room)
    c.grass_line(g, GRASS, height=(1, 5), density=0.85, tall=(0.15, (6, 9)),
                 flowers=[(P['poppy'], P['poppy_dark']), (P['daisy'], P['gorse'])], flower_rate=0.06)
    c.birds(3, 210, 290, 140, 200)
    c.save('edge')


def cliff_face(c, rng):
    """The cliff he falls from and hangs on: painted, not tiled. Warm rock in
    wavy strata, darker away from the light and toward the foot, a lit lip
    along the face where the ravine's light catches it, cracks, ledges of moss
    and fern, roots hanging from the soil above, and the crack at the root of
    the vine that the mice come out of."""
    H = c.h
    face = [int(199 - 2 * abs(math.sin(y * 0.11)) - (1 if (y // 9) % 3 == 0 else 0)) for y in range(H)]
    top = 128
    for y in range(top, H):
        for x in range(0, face[y] + 1):
            strata = math.sin(y * 0.33 + math.sin(x * 0.05) * 2.2) + 0.5 * math.sin(y * 0.9 + x * 0.02)
            depth = (y - top) / (H - top)
            away = (face[y] - x) / 200.0
            shade = 0.15 + depth * 0.45 + away * 0.25 + (0.18 if strata > 1.05 else 0.0) - (0.1 if strata < -1.0 else 0.0)
            lvl = shade * 3 + (BAYER[y % 4, x % 4] - 0.5) * 0.6
            col = P['rock_lit'] if lvl < 0.6 else P['rock'] if lvl < 1.4 else P['rock_dark'] if lvl < 2.2 else P['rock_dark'] * 0.8
            c.px[y, x] = col
        # the face itself catches the light coming up the ravine
        c.px[y, face[y] - 1:face[y] + 1] = P['rock_lit']
        c.px[y, face[y] + 1:face[y] + 2] = P['rock_dark'] * 0.7
    # cracks: a few jagged dark lines running down the rock
    for x0 in (34, 88, 141, 176):
        x = x0 + rng.randint(-4, 4)
        y = top + rng.randint(6, 40)
        for _ in range(rng.randint(30, 90)):
            if 0 <= x < W and y < H:
                c.px[y, x] = P['rock_dark'] * 0.6
            y += 1
            x += rng.choice([-1, 0, 0, 0, 1])
    # ledges with moss and ferns
    for _ in range(14):
        y = rng.randint(top + 14, H - 30)
        x = rng.randint(6, 180)
        w = rng.randint(8, 20)
        c.rect(x, y, x + w, y + 1, P['rock_lit'])
        for k in range(w):
            if rng.random() < 0.7:
                for h in range(rng.randint(1, 3)):
                    c.put(x + k, y - 1 - h, P['near'] if h == 0 else P['grass_lit'])
    # roots hanging from the soil over the edge
    for x0 in range(8, 196, 17):
        x = x0 + rng.randint(-3, 3)
        for k in range(rng.randint(4, 14)):
            c.put(x + (k // 5), top + k, P['trunk'] if k % 3 else P['trunk_lit'])
    # the crack at the root of the vine, where the mice live
    for k in range(12):
        c.put(196 - k // 4, 130 + k, P['shadow'])
        c.put(197 - k // 4, 130 + k, P['rock_dark'] * 0.6)
    # the far wall of the ravine, all the way to the room's right edge
    for y in range(80, H):
        for x in range(296, W):
            if (x * 5 + y * 3) % 17 == 0:
                c.px[y, x] = P['rock_dark']


def main():
    rs = rooms()
    for fn, name in [(shore_road, 'Act3_Level_26'), (high_meadow, 'Act3_Level_27'), (tall_grass, 'Act3_Level_28'),
                     (wood, 'Act3_Level_29'), (rocks, 'Act3_Level_30'), (edge, 'Act3_Level_31')]:
        fn(rs[name])
        print('painted', name)


if __name__ == '__main__':
    main()
