#!/usr/bin/env python3
"""Act III's way home, painted in LAYERS: the backdrops of the real sea and the
six rooms after it (SCRIPT.md TEN to THIRTEEN; rooms Act3_Level_25..31 in
tools/act3_rooms.py), read at runtime by scenes/props/sea/land_backdrop.gd.

He thinks he made it out, so these are the most beautiful rooms in the game. Each
room is a folder, assets/act3/land/<room>/, of transparent layers from far to
near, plus a layers.json manifest saying how far back each one is:

  sky, far, mid, near   painted planes, far to near: `p` is the depth, 0 as far
                        as the sky, 1 the terrain itself. They HOLD STILL in the
                        game (LandBackdrop): sliding them by depth read as the
                        mountains and the sea moving, in rooms whose camera never
                        pans sideways. The margins they are painted with date
                        from that slide; the runtime clips them to the room.
  clouds, trees         separate sprites: clouds drift, trees sway from the root.
  grass                 everything growing on the walkable ground line, swayed
                        per blade by a shader that knows where the ground is
                        (ground.png: the line, one pixel per column).
  glints, shafts, ...   animated by shaders: twinkling on the sea, haze drifting,
                        light in the wood breathing, the waterfall running.
  shadows               long morning shadows cast on the terrain, drawn over it.

These are one-off, native-resolution set pieces (never reduced onto the 8px
grid), the case CLAUDE.md's art rules leave open for painterly work. They are
still pixel art: every gradient is flat bands with an ordered (Bayer) dither at
the seams, every edge a hard pixel edge. Deterministic: random draws are seeded
by the room, so re-running rebuilds the same pixels.

    python3 tools/gen_act3_land_backdrops.py
"""
import json
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
SCREEN_H = 180
## Horizontal parallax per unit of depth: how far (px) a plane at p=0 slides per
## px he moves off the room's centre. LandBackdrop reads it from the manifest.
SLIDE = 0.06

BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=float)


# One morning, all the way home.
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
    # the real sea at sunrise (Act3_Level_25)
    'dawn_top': '#26306a', 'dawn_violet': '#4f4689', 'dawn_rose': '#b8678a', 'dawn_orange': '#ee9a62',
    'dawn_gold': '#f8d49c', 'dawn_sun': '#fff3cf', 'dawn_sea_far': '#a98aa8', 'dawn_sea': '#5c5a8e',
    'dawn_sea_deep': '#363f74', 'dawn_isle': '#6b5a8a', 'dawn_isle_far': '#8d77a0', 'dawn_cloud': '#f3b590',
    'dawn_cloud_shade': '#9d6f96',
}.items()}


def ground_of(room):
    """Per room x (0..W-1), the y of the first solid terrain pixel from the top,
    or None where a column has no ground."""
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


class Canvas:
    """A layer, painted in ROOM coordinates. The bitmap is bigger than the room
    by a margin on every side (so a parallax slide never shows an edge), and
    every primitive takes room coordinates; (mx, my) is where room (0, 0) lands
    in the bitmap."""

    def __init__(self, room_h, mx=0, my=0, seed=0, w=W):
        self.mx, self.my = mx, my
        self.w, self.h = w + 2 * mx, room_h + 2 * my
        self.px = np.zeros((self.h, self.w, 4))
        self.rng = random.Random(seed)
        ys, xs = np.mgrid[0:self.h, 0:self.w]
        self.bayer = BAYER[ys % 4, xs % 4]
        self.ry = ys - my
        self.rx = xs - mx

    def _paint(self, mask, colour):
        self.px[mask, :3] = colour
        self.px[mask, 3] = 255

    def put(self, x, y, colour):
        cx, cy = int(x) + self.mx, int(y) + self.my
        if 0 <= cx < self.w and 0 <= cy < self.h:
            self.px[cy, cx, :3] = colour
            self.px[cy, cx, 3] = 255

    def rect(self, x0, y0, x1, y1, colour):
        self._paint((self.rx >= x0) & (self.rx < x1) & (self.ry >= y0) & (self.ry < y1), colour)

    def gradient(self, stops, y0, y1, steps=7, soft=0.35):
        """Vertical bands through `stops` [(t, colour)] between room rows y0 and
        y1 (rows outside take the end colours), dithered only at band seams."""
        t = np.clip((self.ry - y0) / max(1, y1 - y0 - 1), 0, 1)
        ts = [s for s, _ in stops]
        cols = [c for _, c in stops]
        out = np.zeros((self.h, self.w, 3))
        for i in range(len(ts) - 1):
            seg = (t >= ts[i]) & ((t <= ts[i + 1]) if i < len(ts) - 2 else (t >= ts[i]))
            f = np.clip((t - ts[i]) / max(1e-6, ts[i + 1] - ts[i]), 0, 1)
            lvl = f * steps
            k = np.floor(lvl)
            k = np.minimum(k + ((self.bayer - 0.5) * soft + 0.5 < (lvl - k)), steps)
            colour = cols[i][None, None, :] + (cols[i + 1] - cols[i])[None, None, :] * (k / steps)[..., None]
            out[seg] = colour[seg]
        self.px[..., :3] = out
        self.px[..., 3] = 255

    def glow(self, cx, cy, r, colour, strength=1.0, power=2.0, steps=5, mix=0.22):
        d = np.sqrt((self.rx - cx) ** 2 + (self.ry - cy) ** 2) / r
        a = np.clip(1.0 - d, 0, 1) ** power * strength
        lvl = np.floor(a * steps + (self.bayer - 0.5) * 0.3)
        for i in range(1, steps + 1):
            m = (lvl >= i) & (self.px[..., 3] > 0)
            t = mix * i / steps
            self.px[m, :3] = self.px[m, :3] * (1 - t) + colour * t

    def disc(self, cx, cy, r, colour):
        self._paint((self.rx - cx) ** 2 + (self.ry - cy) ** 2 <= r * r, colour)

    def ridge(self, base, amps, seed_off=0.0):
        """A smooth ridge line as a function of room x."""
        rng = random.Random(self.rng.random() + seed_off)
        waves = [(a, rng.uniform(0.6, 1.4) * f, rng.uniform(0, math.tau)) for a, f in amps]
        return lambda x: base + sum(a * math.sin(f * x + p) for a, f, p in waves)

    def fill_below(self, line, colour, top_colour=None, rim=1, x0=-10 ** 6, x1=10 ** 6, deep=None, depth=40,
                   speckle=None, speckle_rate=0.0, bottom=None):
        """Fill under `line(x)` between room x0 and x1: a lit rim on top, banded
        toward `deep` over `depth` px, with an optional speckle of texture."""
        bottom_row = self.h if bottom is None else min(self.h, int(bottom) + self.my)
        for cx in range(self.w):
            x = cx - self.mx
            if x < x0 or x >= x1:
                continue
            y = int(round(line(x))) + self.my
            if y >= bottom_row:
                continue
            y = max(0, y)
            for k in range(bottom_row - y):
                c = colour
                if deep is not None:
                    t = min(1.0, k / depth)
                    lvl = math.floor(t * 3 + (BAYER[(y + k) % 4, cx % 4] - 0.5) * 0.4) / 3
                    c = colour + (deep - colour) * max(0.0, min(1.0, lvl))
                if speckle is not None and k > 1 and self.rng.random() < speckle_rate:
                    c = speckle
                if top_colour is not None and k < rim:
                    c = top_colour
                self.px[y + k, cx, :3] = c
                self.px[y + k, cx, 3] = 255

    def cut_below(self, line, x0=-10 ** 6, x1=10 ** 6):
        """Clear everything under `line(x)` between room x0 and x1: where land that
        stands BEYOND the water meets it, the water in front shows through."""
        for cx in range(self.w):
            x = cx - self.mx
            if x0 <= x < x1:
                self.px[max(0, int(round(line(x))) + self.my):, cx, 3] = 0

    def mist(self, y, thickness, colour=None, strength=0.6):
        """Haze over what is already painted: flat bands thinning from its middle."""
        colour = P['mist'] if colour is None else colour
        a = np.clip(1 - np.abs(self.ry - y) / thickness, 0, 1) ** 1.2 * strength
        lvl = np.floor(a * 4 + (self.bayer - 0.5) * 0.25)
        for i in range(1, 5):
            m = (lvl >= i) & (self.px[..., 3] > 0)
            self.px[m, :3] = self.px[m, :3] * 0.82 + colour * 0.18

    def dither_fill(self, coverage, colour, alpha=255):
        """Paint `colour` where an ordered dither says `coverage` wins."""
        m = np.asarray(coverage) > self.bayer
        self.px[m, :3] = colour
        self.px[m, 3] = alpha

    def save(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(np.clip(self.px, 0, 255).astype(np.uint8)).save(path)


def margins(room, p):
    """How big a margin a plane at depth `p` needs: its slide across the room plus
    the camera's vertical travel, times how far back it is."""
    cam_travel = max(0.0, (room.h * 8 - SCREEN_H) / 2)
    return int(160 * SLIDE * (1 - p)) + 3, int(cam_travel * (1 - p)) + 3


class Scene:
    """One room's layers being painted, and the manifest that describes them."""

    def __init__(self, name, room, seed):
        self.name, self.room, self.seed = name, room, seed
        self.dir = OUT / name
        self.layers, self.clouds, self.trees, self.extras = [], [], [], {}
        self.H = room.h * 8
        self._n = 0
        if self.dir.exists():
            for old in self.dir.glob('*.png'):
                old.unlink()

    def canvas(self, p):
        mx, my = margins(self.room, p)
        self._n += 1
        return Canvas(self.H, mx, my, seed=self.seed * 100 + self._n)

    def add(self, name, c, p, z, **fx):
        c.save(self.dir / f'{name}.png')
        self.layers.append(dict(name=name, texture=f'{name}.png', p=p, z=z, margin=[c.mx, c.my], **fx))

    def sprite(self, kind, name, c, x, y, p, z, **fx):
        """A cloud (anchored at its middle) or a tree (anchored at its roots):
        its own small bitmap, placed at room (x, y)."""
        c.save(self.dir / f'{name}.png')
        entry = dict(texture=f'{name}.png', x=x, y=y, p=p, z=z, size=[c.w, c.h], **fx)
        (self.clouds if kind == 'cloud' else self.trees).append(entry)

    def ground_texture(self, ground, p=1.0):
        """The ground line, for the grass shader: per bitmap column of a p=1
        plane, the bitmap row of the ground, 16 bits in red and green. A second
        row holds the same line SMOOTHED over a few cells, for the terrain's
        earth shading (act3_depth_tint): measured from each column's own top, a
        raised block came out darker than the ground either side of it, in
        hard vertical seams."""
        mx, my = margins(self.room, p)
        w = W + 2 * mx
        img = np.zeros((2, w, 4), dtype=np.uint8)
        line = [ground[min(W - 1, max(0, cx - mx))] for cx in range(w)]
        line = [self.H if g is None else g for g in line]
        for cx in range(w):
            window = line[max(0, cx - 24):cx + 25]
            for row, v in ((0, line[cx]), (1, sum(window) / len(window))):
                v = int(round(v + my))
                img[row, cx] = [v % 256, v // 256, 0, 255]
        self.dir.mkdir(parents=True, exist_ok=True)
        Image.fromarray(img).save(self.dir / 'ground.png')
        self.extras['ground_margin'] = [mx, my]
        # The same line in room y, for the runtime's motes and butterflies.
        self.extras['ground'] = [int(g) if g is not None else self.H for g in ground[:W]]

    def write(self):
        manifest = dict(room=[W, self.H], slide=SLIDE, layers=self.layers, clouds=self.clouds,
                        trees=self.trees, **self.extras)
        (self.dir / 'layers.json').write_text(json.dumps(manifest, indent=1) + '\n')
        print('painted', self.name, '-', len(self.layers), 'layers,', len(self.clouds), 'clouds,',
              len(self.trees), 'trees')


# ------------------------------------------------------------------ motifs --

def cloud_sprite(w, h, rng, lit_side=-1, palette=None):
    """A soft cumulus on its own transparent bitmap: overlapping ellipses, lit
    along the top on the sun's side, shaded underneath."""
    lit, mid, shade, dark = palette or (P['cloud_lit'], P['cloud_mid'], P['cloud_shade'], P['cloud_dark'])
    c = Canvas(int(h * 2.4) + 4, 0, 0, seed=rng.random(), w=int(w * 2.2) + 4)
    cx, cy = c.w / 2, c.h / 2
    blobs = [(cx + rng.uniform(-w * 0.4, w * 0.4), cy + rng.uniform(-h * 0.25, h * 0.1),
              rng.uniform(w * 0.25, w * 0.45), rng.uniform(h * 0.45, h * 0.75)) for _ in range(5)]
    blobs.append((cx, cy + h * 0.15, w * 0.55, h * 0.4))
    cover = np.zeros((c.h, c.w))
    for bx, by, bw, bh in blobs:
        d = ((c.rx - bx) / bw) ** 2 + ((c.ry - by) / bh) ** 2
        cover = np.maximum(cover, np.clip(1.15 - d, 0, 1))
    rel = np.clip((c.ry - (cy - h * 0.6)) / (h * 1.3), 0, 1)
    side = np.clip(((c.rx - cx) * lit_side) / (w * 1.2), -0.3, 0.3)
    shading = rel - side
    body = np.clip(cover * 3, 0, 1)
    c.dither_fill(np.where(cover > 0.15, body, 0), dark)
    c.dither_fill(np.where((cover > 0.2) & (shading < 0.85), body, 0), shade)
    c.dither_fill(np.where((cover > 0.25) & (shading < 0.6), body, 0), mid)
    c.dither_fill(np.where((cover > 0.3) & (shading < 0.35), body, 0), lit)
    return c


def tree_sprite(h, rng, fruit=None, lit=-1, palette=None, pine=False, bent=False):
    """A tree on its own transparent bitmap, roots at the bottom middle, with a
    few pixels of air either side so its sway never clips. Returns (canvas, x of
    the roots in the bitmap)."""
    pad = 4
    w = int(h * (0.9 if not pine else 0.55)) + 2 * pad + (int(h * 0.35) if bent else 0)
    c = Canvas(h + 2, 0, 0, seed=rng.random(), w=w)
    base, x = h + 1, w // 2 - (int(h * 0.17) if bent else 0)
    if pine:
        dark, mid, light = palette or (P['pine_dark'], P['pine'], P['pine_lit'])
        c.rect(x, base - int(h * 0.15), x + 2, base, P['trunk_dark'])
        tiers = max(3, int(h / 7))
        for i in range(tiers):
            ty = base - int(h * 0.12) - int(i * (h * 0.85) / tiers)
            half = int((tiers - i) * 2.2 * (h / 40 + 0.4)) + 1
            th = int(h * 0.85 / tiers) + 3
            for k in range(th):
                ww = int(half * (k + 1) / th)
                y = ty - th + k
                for dx in range(-ww, ww + 1):
                    col = mid
                    if dx * lit > ww * 0.35:
                        col = light
                    elif dx * lit < -ww * 0.4 or k == th - 1:
                        col = dark
                    c.put(x + dx, y, col)
        return c, x
    dark, mid, light, hi = palette or (P['leaf_dark'], P['leaf'], P['leaf_lit'], P['leaf_hi'])
    trunk_h = int(h * 0.42)
    lean = 0
    for k in range(trunk_h):
        if bent and k > trunk_h * 0.3:
            lean = int((k - trunk_h * 0.3) * 0.45)
        c.put(x - 1 + lean, base - k, P['trunk'])
        c.put(x + lean, base - k, P['trunk'])
        c.put(x + 1 + lean, base - k, P['trunk_dark'])
    c.put(x - 2, base, P['trunk']); c.put(x + 2, base, P['trunk_dark'])
    for i in range(5):
        c.put(x - 1 - i // 2 + lean, base - trunk_h - i, P['trunk'])
        c.put(x + 2 + i // 2 + lean, base - trunk_h - i, P['trunk_dark'])
    cy = base - trunk_h - int(h * 0.25)
    r = h * 0.38
    cxc = x + lean + (int(h * 0.12) if bent else 0)
    blobs = [(cxc + rng.uniform(-r * 0.7, r * 0.7), cy + rng.uniform(-r * 0.5, r * 0.4) * (0.6 if bent else 1.0),
              rng.uniform(r * 0.45, r * 0.7)) for _ in range(9)]
    cover = np.zeros((c.h, c.w), dtype=bool)
    for bx, by, br in blobs:
        cover |= (c.rx - bx) ** 2 + ((c.ry - by) * (1.6 if bent else 1.15)) ** 2 <= br * br
    yy, xx = np.nonzero(cover)
    for y, xp in zip(yy, xx):
        u = (xp - cxc) / r * lit
        v = (y - cy) / r
        s = u * 0.55 - v * 0.75 + rng.uniform(-0.25, 0.25)
        col = dark if s < -0.45 else mid if s < 0.15 else light if s < 0.6 else hi
        c.px[y, xp, :3] = col
        c.px[y, xp, 3] = 255
    if fruit is not None:
        for _ in range(int(r * 1.6)):
            i = rng.randrange(len(yy))
            fy, fx = yy[i], xx[i]
            if abs(fx - cxc) < r * 0.95 and fy > cy - r * 0.6:
                c.put(fx, fy, fruit[0]); c.put(fx + 1, fy, fruit[0])
                c.put(fx, fy + 1, fruit[1]); c.put(fx + 1, fy + 1, fruit[2])
    return c, x


def plant_grass(c, ground, palette, height=(1, 4), density=0.9, flowers=(), flower_rate=0.0, tall=None):
    """Blades and flowers along the room's ground line, on a transparent p=1
    plane so the grass shader can sway them from the root."""
    dark, mid, lit, hi = palette
    rng = c.rng
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
                col = dark if k == 0 else (hi if k == hgt - 1 and rng.random() < 0.5 else (lit if k > hgt // 2 else mid))
                c.put(x + (lean if k > hgt * 0.6 else 0), g - 1 - k, col)
        if flowers and rng.random() < flower_rate:
            petal, centre = rng.choice(flowers)
            stem = rng.randint(2, 5)
            for k in range(stem):
                c.put(x, g - 1 - k, P['grass_dark'] if k < stem - 1 else mid)
            top = g - 1 - stem
            c.put(x, top, centre)
            c.put(x - 1, top, petal); c.put(x + 1, top, petal); c.put(x, top - 1, petal)


def cast_shadow(c, x, ground_y, length, depth=3, strength=0.55):
    """A long morning shadow laid on the ground to the right (the sun is low on
    the left all the way home): a flattened, dithered wedge just under the grass
    line, drawn over the terrain."""
    for dx in range(-2, int(length) + 1):
        t = dx / max(1.0, length)
        half = depth * (1.0 - abs(t - 0.35) * 1.2)
        for dy in range(int(math.ceil(max(0.0, half))) + 1):
            a = strength * (1.0 - t * 0.7) * (1.0 - dy / (half + 1.0))
            if a > BAYER[(ground_y + dy) % 4, (x + dx) % 4]:
                c.put(x + dx, ground_y + dy, P['shadow'])


def soften(c, alpha):
    """Every painted pixel of a shadow plane to the same see-through strength."""
    m = c.px[..., 3] > 0
    c.px[m, 3] = alpha


def sea_plane(c, y0, y1, x0, x1, far, near, deep=None):
    """A flat sea under a horizon, darkening toward the viewer, with faint ripple
    lines (the moving glints are a layer of their own)."""
    span = max(1, y1 - y0)
    rng = c.rng
    for y in range(int(y0), int(y1)):
        t = (y - y0) / span
        col = far + (near - far) * min(1.0, t * 1.6)
        if deep is not None and t > 0.6:
            col = near + (deep - near) * (t - 0.6) / 0.4
        c.rect(x0, y, x1, y + 1, col)
    for _ in range(int((x1 - x0) * span / 30)):
        x = rng.randint(int(x0), int(x1) - 4)
        y = rng.randint(int(y0) + 1, int(y1) - 1)
        c.rect(x, y, x + rng.randint(2, 6), y + 1, far * 0.5 + near * 0.5)


def glint_plane(c, y0, y1, x0, x1, sun_x, colour, near_colour, rate=1.0):
    """The sea's glints alone on a transparent plane: thick along the sun's road,
    sparse elsewhere. The twinkle shader winks each one on and off."""
    rng = c.rng
    span = max(1, y1 - y0)
    for _ in range(int((x1 - x0) * span / 14 * rate)):
        x = rng.randint(int(x0), int(x1) - 4)
        y = rng.randint(int(y0) + 1, int(y1) - 1)
        near_sun = sun_x is not None and abs(x - sun_x) < 30 + (y - y0) * 0.5
        if not near_sun and rng.random() < 0.6:
            continue
        n = rng.randint(2, 6 if near_sun else 3)
        c.rect(x, y, x + n, y + 1, colour if near_sun else near_colour)


def birds_sheet(scene):
    """Two frames of a gull, wings up then down, 7x4 each, for LandBackdrop."""
    c = Canvas(4, 0, 0, w=14)
    for x, y in [(0, 1), (1, 0), (2, 1), (3, 2), (4, 1), (5, 0), (6, 1)]:
        c.put(x, y, P['bird'])
    for x, y in [(7, 0), (8, 1), (9, 2), (10, 2), (11, 2), (12, 1), (13, 0)]:
        c.put(x, y + 1, P['bird'])
    c.save(scene.dir / 'bird.png')


# ------------------------------------------------------------------- rooms --

def real_sea(room):
    """THE REAL SEA at sunrise, now in depth: the sky, the sun, long clouds lit
    from under, two far islands, the sea and the sun's road across it."""
    s = Scene('Act3_Level_25', room, 25)
    H = s.H
    horizon = 96
    sky = s.canvas(0.0)
    sky.gradient([(0.0, P['dawn_top']), (0.35, P['dawn_violet']), (0.62, P['dawn_rose']),
                  (0.85, P['dawn_orange']), (1.0, P['dawn_gold'])], -10, horizon)
    sky.glow(232, 70, 160, P['dawn_gold'], 1.0, 1.3, steps=6, mix=0.3)
    sky.glow(232, 70, 70, P['dawn_sun'], 1.0, 1.2, steps=4, mix=0.35)
    sky.disc(232, 70, 11, P['dawn_sun'])
    s.add('sky', sky, 0.0, -12)
    rng = random.Random(25)
    pal = (P['dawn_cloud'], P['dawn_cloud'] * 0.8 + P['dawn_rose'] * 0.2, P['dawn_cloud_shade'], P['dawn_violet'])
    for i, (x, y, w, h) in enumerate([(60, 26, 54, 6), (150, 42, 70, 5), (290, 20, 40, 5), (20, 58, 30, 4)]):
        s.sprite('cloud', f'cloud_{i}', cloud_sprite(w, h, rng, lit_side=1, palette=pal), x, y, 0.05, -11,
                 speed=1.2 + 0.6 * i)
    far = s.canvas(0.15)
    def isle(x0, x1, top, waves):
        # a silhouette rising out of the water and back into it, not a cut slab
        def line(x):
            t = min(1.0, max(0.0, (x - x0) / (x1 - x0)))
            return horizon - (top + sum(a * math.sin(x * f) for a, f in waves)) * math.sin(math.pi * t) ** 0.45
        return line
    far.fill_below(isle(6, 96, 7, [(3, 0.05), (1.5, 0.13)]), P['dawn_isle_far'], x0=6, x1=96, bottom=horizon)
    far.fill_below(isle(292, 420, 10, [(4, 0.04), (2, 0.11)]), P['dawn_isle'], x0=292, x1=420, bottom=horizon)
    s.add('far', far, 0.15, -11)
    sea = s.canvas(0.3)
    sea_plane(sea, horizon, H + sea.my, -sea.mx, W + sea.mx, P['dawn_sea_far'], P['dawn_sea'], P['dawn_sea_deep'])
    sea.glow(232, horizon + 4, 120, P['dawn_orange'], 0.9, 1.6, steps=4, mix=0.3)
    s.add('sea', sea, 0.3, -10)
    gl = s.canvas(0.3)
    glint_plane(gl, horizon + 1, H, -gl.mx, W + gl.mx, 232, P['dawn_sun'], P['dawn_gold'], rate=1.4)
    s.add('glints', gl, 0.3, -10, shader='twinkle')
    birds_sheet(s)
    s.extras['birds'] = dict(count=2, y=[30, 70], every=[7.0, 13.0])
    s.ground_texture(ground_of(room))   # no grass here, but the sand has depth too
    s.write()


def shore_road(room):
    """Over the dunes: the sun still low behind him on the left, the sea and its
    glitter falling away behind, a pine headland ahead on the right."""
    s = Scene('Act3_Level_26', room, 26)
    g = ground_of(room)
    sky = s.canvas(0.0)
    sky.gradient([(0.0, P['sky_top']), (0.35, P['sky_hi']), (0.6, P['sky_mid']), (0.8, P['sky_low']),
                  (0.92, P['haze']), (1.0, P['gold'])], -10, 106)
    sky.glow(-30, 104, 230, P['gold_hi'], 1.0, 1.3, steps=6)
    sky.glow(-30, 104, 110, P['sun_glow'], 1.0, 1.2, steps=4)
    s.add('sky', sky, 0.0, -12)
    rng = random.Random(26)
    for i, (x, y, w, h) in enumerate([(78, 30, 46, 11), (206, 18, 62, 12), (300, 44, 30, 8)]):
        s.sprite('cloud', f'cloud_{i}', cloud_sprite(w, h, rng), x, y, 0.08, -11, speed=1.5 + 0.8 * i)
    sea = s.canvas(0.2)
    sea_plane(sea, 104, s.H + sea.my, -sea.mx, W + sea.mx, P['sea_far'], P['sea'])
    sea.glow(-30, 104, 140, P['glint'], 0.6, 1.6, steps=3)
    s.add('sea', sea, 0.2, -11)
    gl = s.canvas(0.2)
    glint_plane(gl, 105, s.H, -gl.mx, 200, 0, P['glint'], P['sea_lit'])
    s.add('glints', gl, 0.2, -11, shader='twinkle')
    far = s.canvas(0.35)
    head = lambda x: 104 - max(0.0, x - 150) * 0.30 + 2.5 * math.sin(x * 0.07)
    far.fill_below(head, P['far_hill'], P['far_hill_lit'], rim=1, x0=150, deep=P['hill_dark'], depth=60,
                   speckle=P['far_mtn'], speckle_rate=0.03)
    # Its foot is a shore across the bay, nearer the further right it runs: the
    # sea shows in front of it, with a line of surf where the two meet.
    shore = lambda x: 104 + max(0.0, x - 150) * 0.24 + 1.2 * math.sin(x * 0.19)
    far.cut_below(shore, x0=150)
    for x in range(150, W + far.mx):
        far.put(x, int(round(shore(x))) - 1, P['sea_lit'] if (x // 3) % 3 else P['glint'])
    far.mist(104, 10, strength=0.5)
    s.add('far', far, 0.35, -10)
    for i, (x, h) in enumerate([(206, 12), (219, 16), (230, 14), (243, 19), (256, 17), (268, 22), (281, 19),
                                (294, 24), (308, 21)]):
        t, ax = tree_sprite(h, rng, pine=True, palette=(P['hill_dark'], P['far_hill'] * 0.8 + P['hill'] * 0.2,
                                                         P['far_hill_lit']))
        s.sprite('tree', f'pine_{i}', t, x, int(head(x)) + 3, 0.35, -10, anchor=ax, sway=1.0, phase=i * 0.7)
    dunes = s.canvas(0.65)
    dune = lambda x: 150 - max(0.0, x - 40) * 0.16 + 4 * math.sin(x * 0.045) + 2 * math.sin(x * 0.13)
    dunes.fill_below(dune, P['sand'], P['sand_lit'], rim=2, x0=20, deep=P['sand_dark'], depth=30)
    for x in range(22, W + dunes.mx, 2):
        if dunes.rng.random() < 0.55:
            top = int(dune(x))
            for k in range(dunes.rng.randint(2, 7)):
                dunes.put(x + (1 if k > 4 else 0), top - 1 - k,
                          P['gold_grass_dark'] if k < 2 else (P['gold_grass_lit'] if k > 3 else P['gold_grass']))
    s.add('near', dunes, 0.65, -9)
    grass = s.canvas(1.0)
    plant_grass(grass, g, (P['grass_dark'], P['gold_grass'], P['gold_grass_lit'], P['grass_hi']),
                height=(1, 5), density=0.75, tall=(0.25, (6, 10)),
                flowers=[(P['violet'], P['gorse']), (P['daisy'], P['gorse']), (P['gorse'], P['lemon_dark'])],
                flower_rate=0.08)
    s.add('grass', grass, 1.0, -6, shader='grass')
    s.ground_texture(g)
    birds_sheet(s)
    s.extras['birds'] = dict(count=3, y=[28, 66], every=[5.0, 10.0])
    s.extras['particles'] = [dict(kind='seed', amount=8, colour='#f6f1e2', wind=10.0)]
    s.write()


def high_meadow(room):
    """The high meadow above the sea: blue mountains, valleys of mist, the lit
    green hills, poppies everywhere, and one lemon tree on the brow, laying its
    long morning shadow across the grass."""
    s = Scene('Act3_Level_27', room, 27)
    g = ground_of(room)
    sky = s.canvas(0.0)
    sky.gradient([(0.0, P['sky_top']), (0.4, P['sky_hi']), (0.75, P['sky_mid']), (0.92, P['sky_low']),
                  (1.0, P['haze'])], -10, 96)
    sky.glow(20, 10, 190, P['gold_hi'], 0.9, 1.5, steps=5)
    s.add('sky', sky, 0.0, -12)
    rng = random.Random(27)
    for i, (x, y, w, h) in enumerate([(130, 26, 70, 13), (262, 14, 44, 9), (40, 50, 28, 7), (330, 40, 34, 8)]):
        s.sprite('cloud', f'cloud_{i}', cloud_sprite(w, h, rng), x, y, 0.06, -11, speed=1.2 + 0.5 * i)
    mtn_c = s.canvas(0.12)
    mtn = mtn_c.ridge(70, [(11, 0.024), (5, 0.062), (2, 0.16)])
    mtn_c.fill_below(mtn, P['far_mtn'], P['far_mtn_lit'], rim=1, deep=P['far_hill'], depth=30)
    for cx in range(mtn_c.w):
        x = cx - mtn_c.mx
        y = int(mtn(x))
        cap = int(max(0, 66 - y) * 0.6)
        if cap:
            mtn_c.rect(x, y, x + 1, y + cap, P['mist'])
    mtn_c.mist(84, 7, strength=0.7)
    sea_plane(mtn_c, 84, 96, -mtn_c.mx, 90, P['sea_far'], P['sea'])
    s.add('far', mtn_c, 0.12, -11)
    hills_far = s.canvas(0.3)
    far = hills_far.ridge(88, [(5, 0.035), (2, 0.09)])
    hills_far.fill_below(far, P['far_hill'], P['far_hill_lit'], rim=1, deep=P['hill_dark'], depth=40,
                         speckle=P['hill_dark'], speckle_rate=0.04)
    hills_far.mist(94, 5, strength=0.5)
    s.add('mid_far', hills_far, 0.3, -10)
    hills = s.canvas(0.5)
    mid = hills.ridge(100, [(6, 0.028), (2, 0.08)])
    hills.fill_below(mid, P['hill'], P['hill_lit'], rim=2, deep=P['hill_dark'], depth=30,
                     speckle=P['hill_lit'], speckle_rate=0.04)
    s.add('mid', hills, 0.5, -9)
    for i, x in enumerate(range(-6, W + 6, 23)):
        if rng.random() < 0.55:
            t, ax = tree_sprite(rng.randint(8, 12), rng, palette=(P['hill_dark'], P['hill_dark'] * 0.6 + P['hill'] * 0.4,
                                                                  P['hill'], P['hill_lit']))
            s.sprite('tree', f'copse_{i}', t, x, int(mid(x)) + 3, 0.5, -9, anchor=ax, sway=1.0, phase=i)
    # the lemon tree stands on the walkable brow: it moves with the terrain
    t, ax = tree_sprite(66, rng, fruit=(P['lemon'], P['lemon_hi'], P['lemon_dark']), lit=-1)
    s.sprite('tree', 'lemon_tree', t, 150, g[150], 1.0, -7, anchor=ax, sway=1.5, phase=0.0)
    grass = s.canvas(1.0)
    plant_grass(grass, g, (P['grass_dark'], P['grass'], P['grass_lit'], P['grass_hi']), height=(2, 6), density=0.95,
                tall=(0.2, (6, 9)),
                flowers=[(P['poppy'], P['poppy_dark']), (P['poppy'], P['poppy_dark']), (P['daisy'], P['gorse'])],
                flower_rate=0.22)
    s.add('grass', grass, 1.0, -6, shader='grass')
    s.ground_texture(g)
    shade = s.canvas(1.0)
    cast_shadow(shade, 150, g[150], 58, depth=3)
    soften(shade, 120)
    s.add('shadows', shade, 1.0, 0)
    birds_sheet(s)
    s.extras['birds'] = dict(count=2, y=[30, 56], every=[8.0, 14.0])
    s.extras['particles'] = [dict(kind='petal', amount=10, colour='#d9423a', wind=8.0),
                             dict(kind='butterfly', amount=2, colour='#f6f1e2', wind=0.0)]
    s.write()


def tall_grass(room):
    """Tall grass, gold and green, rising higher than he is; the wood dark
    ahead. Quiet. Something could be in it."""
    s = Scene('Act3_Level_28', room, 28)
    g = ground_of(room)
    sky = s.canvas(0.0)
    sky.gradient([(0.0, P['sky_top']), (0.4, P['sky_hi']), (0.75, P['sky_mid']), (0.92, P['sky_low']),
                  (1.0, P['haze'])], -10, 110)
    s.add('sky', sky, 0.0, -12)
    rng = random.Random(28)
    for i, (x, y, w, h) in enumerate([(80, 26, 60, 12), (230, 40, 40, 9), (330, 20, 36, 8)]):
        s.sprite('cloud', f'cloud_{i}', cloud_sprite(w, h, rng), x, y, 0.06, -11, speed=1.3 + 0.6 * i)
    far = s.canvas(0.25)
    ridge = far.ridge(98, [(6, 0.03), (2, 0.1)])
    far.fill_below(ridge, P['far_hill'], P['far_hill_lit'], rim=2, deep=P['hill_dark'], depth=40)
    far.mist(104, 8, strength=0.5)
    s.add('far', far, 0.25, -11)
    wood = s.canvas(0.55)
    edge = lambda x: 128 - max(0.0, x - 170) * 0.25
    wood.fill_below(edge, P['wood_back'], x0=160)
    s.add('mid', wood, 0.55, -10)
    for i, x in enumerate(range(176, W + 20, 7)):
        t, ax = tree_sprite(rng.randint(30, 52), rng, pine=True)
        s.sprite('tree', f'pine_{i}', t, x + rng.randint(-2, 2), int(edge(min(W - 1, x))) + 4, 0.55, -10,
                 anchor=ax, sway=1.2, phase=i * 0.9)
    for i, x in enumerate(range(150, 200, 9)):
        t, ax = tree_sprite(rng.randint(22, 30), rng, lit=-1)
        s.sprite('tree', f'oak_{i}', t, x, 132, 0.6, -10, anchor=ax, sway=1.2, phase=i * 1.3)
    back = s.canvas(0.8)
    line = back.ridge(132, [(3, 0.05)])
    back.fill_below(line, P['gold_grass_dark'], P['gold_grass'], rim=1)
    for cx in range(back.w):
        x = cx - back.mx
        base = int(line(x))
        for _ in range(2):
            if back.rng.random() < 0.7:
                hgt = back.rng.randint(4, 14)
                b = base + back.rng.randint(0, 6)
                for k in range(hgt):
                    back.put(x, b - k, P['gold_grass_lit'] if k > hgt - 3 else P['gold_grass'])
    s.add('near', back, 0.8, -9)
    grass = s.canvas(1.0)
    plant_grass(grass, g, (P['gold_grass_dark'], P['gold_grass'], P['gold_grass_lit'], P['gold_grass_lit']),
                height=(4, 12), density=1.0, tall=(0.35, (12, 22)), flowers=[(P['daisy'], P['gorse'])],
                flower_rate=0.02)
    s.add('grass', grass, 1.0, -6, shader='grass', sway=1.6)
    s.ground_texture(g)
    s.extras['particles'] = [dict(kind='seed', amount=12, colour='#e8d27a', wind=6.0)]
    s.write()


def wood(room):
    """Inside the wood: trunks in three depths of fog, the canopy overhead
    stirring, and shafts of morning light breathing through it, dust turning in
    them. The near trunks lay their shadows across the forest floor."""
    s = Scene('Act3_Level_29', room, 29)
    g = ground_of(room)
    rng = random.Random(29)
    sky = s.canvas(0.0)
    sky.gradient([(0.0, P['leaf_dark']), (0.35, P['wood_fog']), (0.7, P['wood_fog_far']), (1.0, P['wood_fog'])],
                 -10, s.H)
    s.add('sky', sky, 0.0, -12)
    trunks = []
    for depth, p, colour, wmin, wmax, step in [(0, 0.15, P['wood_fog_far'] * 0.92, 3, 5, 26),
                                               (1, 0.4, P['wood_back'], 5, 8, 34),
                                               (2, 0.75, P['trunk_dark'], 8, 12, 47)]:
        c = s.canvas(p)
        x = -c.mx + rng.randint(-6, 6)
        while x < W + c.mx:
            w = rng.randint(wmin, wmax)
            c.rect(x, -c.my, x + w, s.H + c.my, colour)
            if depth == 2:
                c.rect(x + w - 2, -c.my, x + w, s.H + c.my, P['trunk'])
                c.rect(x, -c.my, x + 1, s.H + c.my, P['trunk_dark'] * 0.8)
                trunks.append((x, w))
            x += step + rng.randint(-6, 8)
        if depth == 0:
            c.mist(118, 12, P['wood_fog_far'], strength=0.4)
        s.add(['far', 'mid', 'near'][depth], c, p, -11 + depth)
    shafts = s.canvas(0.5)
    ang = math.tan(math.radians(-22))
    a = np.zeros((shafts.h, shafts.w))
    for i in range(8):
        c0 = -60 + i * 58
        u = shafts.rx - shafts.ry * ang
        a = np.maximum(a, np.clip(1 - np.abs(u - c0) / 7, 0, 1))
    a = a * np.clip((shafts.ry - 10) / 40.0, 0, 1) * 0.32
    shafts.dither_fill(a, P['gold_hi'], alpha=150)
    s.add('shafts', shafts, 0.5, -10, shader='pulse')
    canopy = s.canvas(0.6)
    cover = np.zeros((canopy.h, canopy.w))
    for _ in range(46):
        bx, by, br = rng.uniform(-30, W + 30), rng.uniform(-14, 26), rng.uniform(10, 22)
        cover = np.maximum(cover, np.clip(1.2 - ((canopy.rx - bx) ** 2 + ((canopy.ry - by) * 1.3) ** 2) / (br * br), 0, 1))
    canopy.dither_fill(np.clip(cover * 2, 0, 1), P['leaf_dark'])
    canopy.dither_fill(np.where(cover > 0.6, np.clip((cover - 0.6) * 3, 0, 1), 0) * (canopy.ry < 30), P['leaf'])
    for _ in range(200):
        cx, cy = rng.randint(0, canopy.w - 1), rng.randint(0, min(canopy.h - 1, 30 + canopy.my))
        if cover[cy, cx] > 0.3:
            canopy.px[cy, cx, :3] = P['leaf_lit'] if rng.random() < 0.7 else P['leaf_hi']
            canopy.px[cy, cx, 3] = 255
    s.add('canopy', canopy, 0.6, -9, shader='hang', sway=1.5)
    grass = s.canvas(1.0)
    plant_grass(grass, g, (P['leaf_dark'], P['leaf'], P['leaf_lit'], P['leaf_hi']), height=(2, 6), density=0.8,
                tall=(0.12, (7, 10)), flowers=[(P['daisy'], P['gorse']), (P['violet'], P['gorse'])], flower_rate=0.03)
    for x in range(4, W - 4, 11):
        if g[x] is None or grass.rng.random() < 0.4:
            continue
        for k in range(6):
            grass.put(x, g[x] - 1 - k, P['leaf'])
            if k % 2 == 0:
                grass.put(x - 1 - k // 2, g[x] - 1 - k, P['leaf_lit']); grass.put(x + 1 + k // 2, g[x] - 1 - k, P['leaf'])
    s.add('grass', grass, 1.0, -6, shader='grass')
    s.ground_texture(g)
    shade = s.canvas(1.0)
    for x, w in trunks:
        foot = min(W - 1, max(0, x + w // 2))
        if 0 <= x < W and g[foot] is not None:
            cast_shadow(shade, x + w, g[foot], 34, depth=2, strength=0.45)
    soften(shade, 110)
    s.add('shadows', shade, 1.0, 0)
    s.extras['particles'] = [dict(kind='mote', amount=16, colour='#fbe6b8', wind=2.0),
                             dict(kind='leaf', amount=5, colour='#74a84b', wind=6.0)]
    s.write()


def rocks(room):
    """The headland: the wind, gorse in flower, a bent pine leaning with it, and
    the sea far below on the right where the land is running out."""
    s = Scene('Act3_Level_30', room, 30)
    g = ground_of(room)
    rng = random.Random(30)
    sky = s.canvas(0.0)
    sky.gradient([(0.0, P['sky_top']), (0.4, P['sky_hi']), (0.75, P['sky_mid']), (0.92, P['sky_low']),
                  (1.0, P['haze'])], -10, 88)
    sky.glow(-20, 40, 200, P['gold_hi'], 0.8, 1.5, steps=5)
    s.add('sky', sky, 0.0, -12)
    for i, (x, y, w, h) in enumerate([(66, 30, 54, 11), (200, 20, 70, 13), (300, 50, 30, 7)]):
        s.sprite('cloud', f'cloud_{i}', cloud_sprite(w, h, rng), x, y, 0.07, -11, speed=2.0 + 0.8 * i)
    sea = s.canvas(0.15)
    sea_plane(sea, 88, s.H + sea.my, -sea.mx, W + sea.mx, P['sea_far'], P['sea'])
    coast = lambda x: (88 - min(18.0, max(0.0, 116 - x) * 0.7) + 1.5 * math.sin(x * 0.11)
                       + 1.0 * math.sin(x * 0.37))
    sea.fill_below(coast, P['rock_far'], P['far_mtn_lit'], rim=1, x1=118, bottom=89, deep=P['far_mtn'], depth=14)
    for x in range(-sea.mx, 118):
        # The cliff where it drops to the water, a shade darker than the top.
        if 116 - x < 26:
            for y in range(int(coast(x)) + 2, 89):
                sea.put(x, y, P['far_mtn'])
    sea.mist(86, 6, strength=0.6)
    s.add('sea', sea, 0.15, -11)
    gl = s.canvas(0.15)
    glint_plane(gl, 90, s.H, 100, W + gl.mx, None, P['glint'], P['sea_lit'], rate=0.8)
    s.add('glints', gl, 0.15, -11, shader='twinkle')
    head = s.canvas(0.6)
    line = lambda x: 106 + max(0.0, x - 200) * 0.55 + 2 * math.sin(x * 0.21)
    head.fill_below(line, P['rock'], P['grass_lit'], rim=2, deep=P['rock_dark'], depth=40,
                    speckle=P['rock_lit'], speckle_rate=0.04)
    shade = s.canvas(0.6)
    for _ in range(10):
        bx, by, br = rng.randint(-10, 220), rng.randint(104, 114), rng.randint(5, 10)
        # each boulder lays a short shadow on the turf to its right
        cast_shadow(shade, bx + int(br * 0.3), by + int(br / 1.4) - 1, br * 1.6, depth=2, strength=0.5)
        m = (head.rx - bx) ** 2 + ((head.ry - by) * 1.4) ** 2 <= br * br
        head._paint(m, P['rock'])
        head._paint(m & ((head.rx - bx) < -br * 0.2) & ((head.ry - by) < 0), P['rock_lit'])
        head._paint(m & ((head.rx - bx) > br * 0.35), P['rock_dark'])
    for x in range(8, 220, 13):
        y = int(line(x)) + 1
        for k in range(18):
            dx, dy = rng.randint(-5, 5), rng.randint(-4, 0)
            head.put(x + dx, y + dy, P['near'] if k < 8 else P['gorse'])
    s.add('near', head, 0.6, -9)
    # and the bent pine a long one, down the slope after the sun
    cast_shadow(shade, 172, int(line(172)) + 1, 40, depth=2, strength=0.5)
    soften(shade, 120)
    s.add('near_shade', shade, 0.6, -9)
    t, ax = tree_sprite(38, rng, bent=True, palette=(P['pine_dark'], P['pine'], P['pine_lit'], P['pine_lit']))
    s.sprite('tree', 'bent_pine', t, 170, int(line(170)) + 1, 0.6, -9, anchor=ax, sway=2.2, phase=0.4)
    grass = s.canvas(1.0)
    plant_grass(grass, g, (P['grass_dark'], P['grass'], P['grass_lit'], P['grass_hi']), height=(1, 4), density=0.6,
                flowers=[(P['gorse'], P['lemon_dark']), (P['gorse'], P['lemon_dark']), (P['daisy'], P['gorse'])],
                flower_rate=0.12)
    s.add('grass', grass, 1.0, -6, shader='grass', sway=1.6)
    s.ground_texture(g)
    birds_sheet(s)
    s.extras['birds'] = dict(count=3, y=[44, 80], every=[5.0, 9.0])
    s.extras['particles'] = [dict(kind='petal', amount=10, colour='#f0c23b', wind=18.0)]
    s.write()


def edge(room):
    """The edge, two screens tall. The sky over the cliff top; down the ravine,
    hills falling away in mist; the far wall with its ledges and a thread of
    waterfall; the cliff he hangs from, painted; the valley floor far below."""
    s = Scene('Act3_Level_31', room, 31)
    g = ground_of(room)
    rng = random.Random(31)
    H = s.H
    sky = s.canvas(0.2)
    sky.gradient([(0.0, P['sky_top']), (0.3, P['sky_hi']), (0.6, P['sky_mid']), (0.85, P['sky_low']),
                  (1.0, P['haze'])], -20, 150)
    sky.glow(-20, 30, 200, P['gold_hi'], 0.8, 1.5, steps=5)
    low = Canvas(H, sky.mx, sky.my)
    low.gradient([(0.0, P['haze']), (0.35, P['far_hill_lit']), (0.75, P['far_hill']), (1.0, P['wood_fog'])], 150, H)
    lower = sky.ry >= 150
    sky.px[lower] = low.px[lower]
    s.add('sky', sky, 0.2, -12)
    for i, (x, y, w, h) in enumerate([(90, 30, 64, 13), (240, 50, 50, 10), (20, 70, 30, 7)]):
        s.sprite('cloud', f'cloud_{i}', cloud_sprite(w, h, rng), x, y, 0.25, -11, speed=1.4 + 0.7 * i)
    for k, (base, col, lit, p) in enumerate([(110, P['far_mtn'], P['far_mtn_lit'], 0.35),
                                             (170, P['far_hill'], P['far_hill_lit'], 0.5),
                                             (240, P['hill_dark'], P['hill'], 0.65)]):
        c = s.canvas(p)
        ridge = c.ridge(base, [(10, 0.03), (4, 0.09)])
        c.fill_below(ridge, col, lit, rim=1, x0=150, deep=col * 0.85 + P['wood_fog'] * 0.15, depth=50,
                     speckle=col * 0.9, speckle_rate=0.03)
        c.mist(base + 18, 16, strength=0.6)
        s.add(f'hills_{k}', c, p, -11)
    # The ravine's far wall is solid in the room (its top three columns are real
    # rock and grass, the rest invisible solid), so it hangs at the room's own
    # depth and is drawn OVER the terrain: on a plane of its own it slid off the
    # real rock as the camera went down, which then read as a box stuck on it.
    top = min(y for y in g[296:] if y is not None)
    wall = s.canvas(1.0)
    wall_left = lambda y: 272 + 6 * math.sin(y * 0.045) + 3 * math.sin(y * 0.17)
    for y in range(top, H + wall.my):
        x0 = int(wall_left(y))
        wall.rect(x0, y, W + wall.mx, y + 1, P['rock'])
        wall.rect(x0, y, x0 + 2, y + 1, P['rock_lit'])
    for y in range(top + 6, H + wall.my):
        for x in range(int(wall_left(y)) + 2, W + wall.mx):
            if (x * 7 + y * 3) % 23 == 0 or rng.random() < 0.04:
                wall.put(x, y, P['rock_dark'])
    # its grassy top, level with the real one
    for x in range(int(wall_left(top)), W + wall.mx):
        wall.put(x, top, P['grass_lit'])
        wall.put(x, top + 1, P['grass'])
        for k in range(rng.randint(0, 4) if rng.random() < 0.6 else 0):
            wall.put(x, top - 1 - k, P['grass_hi'] if k > 1 else P['grass'])
    for y in range(120, H - 70, 46):
        x0 = int(wall_left(y)) - 2
        wall.rect(x0, y, x0 + 24, y + 3, P['rock_lit'])
    s.add('wall', wall, 1.0, 1)
    for i, y in enumerate(range(120, H - 70, 46)):
        t, ax = tree_sprite(15, rng, palette=(P['near_dark'], P['near'], P['near_lit'], P['grass_hi']))
        s.sprite('tree', f'ledge_{i}', t, int(wall_left(y)) + 8, y, 1.0, 2, anchor=ax, sway=1.0, phase=i * 1.1)
    fall = s.canvas(1.0)
    for y in range(140, 352):
        x = int(wall_left(y)) + 6
        fall.put(x, y, P['mist'] if (y // 3) % 2 else P['sea_lit'])
        fall.put(x + 1, y, P['sea_lit'])
    s.add('waterfall', fall, 1.0, 2, shader='fall')
    face = s.canvas(1.0)
    cliff_face(face, rng, H)
    s.add('cliff', face, 1.0, -8)
    for i, x in enumerate(range(196, W, 13)):
        t, ax = tree_sprite(rng.randint(24, 38), rng, lit=-1)
        s.sprite('tree', f'valley_{i}', t, x + rng.randint(-3, 3), 352, 1.0, -8, anchor=ax, sway=1.3, phase=i * 0.8)
    stream = s.canvas(1.0)
    stream.rect(196, 349, W + stream.mx, 351, P['sea_lit'])
    s.add('stream', stream, 1.0, -8, shader='twinkle')
    grass = s.canvas(1.0)
    plant_grass(grass, g, (P['grass_dark'], P['grass'], P['grass_lit'], P['grass_hi']), height=(1, 5), density=0.85,
                tall=(0.15, (6, 9)), flowers=[(P['poppy'], P['poppy_dark']), (P['daisy'], P['gorse'])], flower_rate=0.06)
    s.add('grass', grass, 1.0, -6, shader='grass')
    s.ground_texture(g)
    shade = s.canvas(1.0)
    # the lip of the cliff top shadows the first stretch of rock under it
    for y in range(128, 140):
        for x in range(0, 200):
            if (140 - y) / 12 * 0.6 > BAYER[y % 4, x % 4]:
                shade.put(x, y, P['shadow'])
    soften(shade, 110)
    s.add('shadows', shade, 1.0, -7)
    birds_sheet(s)
    s.extras['birds'] = dict(count=2, y=[104, 150], every=[9.0, 16.0])
    s.extras['particles'] = [dict(kind='mote', amount=10, colour='#e4e9ee', wind=4.0)]
    s.write()


def cliff_face(c, rng, H):
    """The cliff he falls from and hangs on: warm rock in wavy strata, darker
    away from the light and toward the foot, a lit lip along the face, cracks,
    ledges of moss and fern, roots from the soil above, and the crack at the
    root of the vine that the mice come out of."""
    face = [int(199 - 2 * abs(math.sin(y * 0.11)) - (1 if (y // 9) % 3 == 0 else 0)) for y in range(H)]
    top = 128
    for y in range(top, H):
        for x in range(-c.mx, face[y] + 1):
            strata = math.sin(y * 0.33 + math.sin(x * 0.05) * 2.2) + 0.5 * math.sin(y * 0.9 + x * 0.02)
            depth = (y - top) / (H - top)
            away = (face[y] - x) / 200.0
            shade = 0.15 + depth * 0.45 + away * 0.25 + (0.18 if strata > 1.05 else 0.0) - (0.1 if strata < -1.0 else 0.0)
            lvl = shade * 3 + (BAYER[y % 4, (x + c.mx) % 4] - 0.5) * 0.6
            col = P['rock_lit'] if lvl < 0.6 else P['rock'] if lvl < 1.4 else P['rock_dark'] if lvl < 2.2 else P['rock_dark'] * 0.8
            c.put(x, y, col)
        c.put(face[y] - 1, y, P['rock_lit']); c.put(face[y], y, P['rock_lit'])
        c.put(face[y] + 1, y, P['rock_dark'] * 0.7)
    for x0 in (34, 88, 141, 176):
        x = x0 + rng.randint(-4, 4)
        y = top + rng.randint(6, 40)
        for _ in range(rng.randint(30, 90)):
            if y < H:
                c.put(x, y, P['rock_dark'] * 0.6)
            y += 1
            x += rng.choice([-1, 0, 0, 0, 1])
    for _ in range(14):
        y = rng.randint(top + 14, H - 30)
        x = rng.randint(6, 180)
        w = rng.randint(8, 20)
        c.rect(x, y, x + w, y + 1, P['rock_lit'])
        for k in range(w):
            if rng.random() < 0.7:
                for h in range(rng.randint(1, 3)):
                    c.put(x + k, y - 1 - h, P['near'] if h == 0 else P['grass_lit'])
    for x0 in range(8, 196, 17):
        x = x0 + rng.randint(-3, 3)
        for k in range(rng.randint(4, 14)):
            c.put(x + (k // 5), top + k, P['trunk'] if k % 3 else P['trunk_lit'])
    for k in range(12):
        c.put(196 - k // 4, 130 + k, P['shadow'])
        c.put(197 - k // 4, 130 + k, P['rock_dark'] * 0.6)


def main():
    import act3_rooms
    rs = {r.name: r for r in act3_rooms.ROOMS}
    for fn, name in [(real_sea, 'Act3_Level_25'), (shore_road, 'Act3_Level_26'), (high_meadow, 'Act3_Level_27'),
                     (tall_grass, 'Act3_Level_28'), (wood, 'Act3_Level_29'), (rocks, 'Act3_Level_30'),
                     (edge, 'Act3_Level_31')]:
        fn(rs[name])


if __name__ == '__main__':
    main()
