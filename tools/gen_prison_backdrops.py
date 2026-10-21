"""Painted back walls for the prison hub and its four wings.

One native-resolution painting per room (320x192; the hub 640x384), drawn
procedurally and dithered onto a per-wing palette. These are SET-PIECE
backdrops — never squeezed onto the 8px grid — so they may carry soft
gradients, but they are kept dark and low-contrast on purpose: the castle
masonry, scaffolding, spikes and props in front are pale and warm, and the
room has to read as "inside the school" without ever competing with them.

Palette: the castle back-wall ramp is read from `ldtk/art/castle/castle-01.png`
/ `castle-02.png` (the mauve-indigo interior and pink brick the prison is built
from) and each wing pushes it toward its own colour — library green-brown,
cafeteria terracotta + turquoise tile, basement cobalt, gym honey gold. (The
Pixellab subscription had lapsed when this was made, so unlike the other Act 2
generators the ramp anchors are sampled from existing project art rather than
a fresh swatch; every shape is procedural either way.)

    python3 tools/gen_prison_backdrops.py      # writes assets/backdrop/prison/*.png

`scenes/props/prison/prison_room.gd` hangs `<room>.png` behind each prison room.
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/backdrop/prison'

BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def castle_anchors():
    """Darkest and mid interior tones straight from the castle art."""
    im = np.asarray(Image.open(ROOT / 'ldtk/art/castle/castle-01.png').convert('RGBA')).reshape(-1, 4)
    opaque = im[im[:, 3] > 200][:, :3].astype(float)
    lum = (opaque * np.array([0.299, 0.587, 0.114])).sum(axis=1)
    deep = opaque[lum < np.percentile(lum, 12)].mean(axis=0)
    mid = opaque[(lum > np.percentile(lum, 20)) & (lum < np.percentile(lum, 40))].mean(axis=0)
    return deep, mid


DEEP, MID = castle_anchors()

# Per-wing key colours: shadow, wall, light, accent, accent2. The wall tones
# are the castle anchors pulled toward the wing's hue.
WINGS = {
    'Hub':   dict(tint=hexc('#5a4a6e'), light=hexc('#c9a27a'), accent=hexc('#3f8f8c'), accent2=hexc('#b5584e')),
    'Green': dict(tint=hexc('#4a4a38'), light=hexc('#c8a466'), accent=hexc('#5c7a4e'), accent2=hexc('#8a4a3a')),
    'Red':   dict(tint=hexc('#6a4440'), light=hexc('#e0b48a'), accent=hexc('#3d8a88'), accent2=hexc('#b06a3e')),
    'Blue':  dict(tint=hexc('#2f4058'), light=hexc('#8fc4c8'), accent=hexc('#3c6e8c'), accent2=hexc('#a8844e')),
    'Gold':  dict(tint=hexc('#62503a'), light=hexc('#ecc878'), accent=hexc('#4f8a84'), accent2=hexc('#b45a44')),
}


class Canvas:
    def __init__(self, w, h, wing, seed):
        self.w, self.h = w, h
        self.p = WINGS[wing]
        self.wall = MID * 0.45 + self.p['tint'] * 0.55
        self.shadow = DEEP * 0.6 + self.p['tint'] * 0.25
        self.a = np.zeros((h, w, 3), float)
        self.rng = random.Random(seed)

    # -- primitives (all clip to the canvas) --
    def rect(self, x0, y0, x1, y1, col, alpha=1.0):
        x0, x1 = max(0, int(x0)), min(self.w, int(x1))
        y0, y1 = max(0, int(y0)), min(self.h, int(y1))
        if x0 >= x1 or y0 >= y1: return
        self.a[y0:y1, x0:x1] = self.a[y0:y1, x0:x1] * (1 - alpha) + np.asarray(col) * alpha

    def vgrad(self, x0, y0, x1, y1, top, bottom, alpha=1.0):
        y0i, y1i = max(0, int(y0)), min(self.h, int(y1))
        for y in range(y0i, y1i):
            t = (y - y0) / max(1, (y1 - y0 - 1))
            self.rect(x0, y, x1, y + 1, np.asarray(top) * (1 - t) + np.asarray(bottom) * t, alpha)

    def mask(self, m, col, alpha=1.0):
        self.a[m] = self.a[m] * (1 - alpha) + np.asarray(col) * alpha

    def grid(self):
        return np.mgrid[0:self.h, 0:self.w]

    def arch_mask(self, cx, base_y, half_w, height, pointed=True):
        """A pointed (Persian) or round arch opening, base at base_y."""
        yy, xx = self.grid()
        spring = base_y - height + half_w * (1.35 if pointed else 1.0)
        rect = (np.abs(xx - cx) <= half_w) & (yy <= base_y) & (yy >= spring)
        if pointed:
            r = half_w * 1.35
            left = (xx - (cx + half_w - r)) ** 2 + (yy - spring) ** 2 <= r * r
            right = (xx - (cx - half_w + r)) ** 2 + (yy - spring) ** 2 <= r * r
            top = left & right & (yy < spring) & (np.abs(xx - cx) <= half_w)
        else:
            top = ((xx - cx) ** 2 + (yy - spring) ** 2 <= half_w * half_w) & (yy < spring)
        return rect | top

    def glow(self, cx, cy, radius, col, strength):
        yy, xx = self.grid()
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
        f = np.clip(1 - d, 0, 1) ** 2 * strength
        self.a += (np.asarray(col)[None, None, :] - self.a) * f[..., None]

    def beam(self, x_top, w_top, x_bot, w_bot, y0, y1, col, strength):
        for y in range(max(0, int(y0)), min(self.h, int(y1))):
            t = (y - y0) / max(1, y1 - y0)
            cx = x_top + (x_bot - x_top) * t
            hw = (w_top + (w_bot - w_top) * t) / 2
            fade = strength * (1 - t) ** 1.2
            self.rect(cx - hw, y, cx + hw, y + 1, col, fade)

    # -- shared structure --
    def back_wall(self, block=16, course=8, light=0.0):
        """Large stone blocks with darker mortar, top to bottom."""
        self.vgrad(0, 0, self.w, self.h, self.wall * 0.78, self.wall * 1.0)
        mortar = self.wall * 0.62
        for row, y in enumerate(range(0, self.h, course)):
            off = (block // 2) * (row % 2)
            self.rect(0, y, self.w, y + 1, mortar, 0.55)
            for x in range(-off, self.w, block):
                self.rect(x, y, x + 1, y + course, mortar, 0.45)
                # per-block value jitter: the wall is stone, not wallpaper
                j = self.rng.uniform(-0.05, 0.05) + light
                self.rect(x + 1, y + 1, x + block, y + course, self.wall * (1 + j), 0.35)

    def frieze(self, y, h=6):
        """A Persian geometric band: alternating diamonds and dots."""
        self.rect(0, y, self.w, y + h, self.shadow * 1.1)
        self.rect(0, y, self.w, y + 1, self.p['light'] * 0.45)
        self.rect(0, y + h - 1, self.w, y + h, self.p['light'] * 0.35)
        c = h // 2
        for x in range(4, self.w, 10):
            for d in range(c):
                self.rect(x - d, y + c - (c - 1 - d) - 1, x + d + 1, y + c - (c - 1 - d), self.p['accent'] * 0.75)
                self.rect(x - d, y + c + (c - 1 - d) - 1, x + d + 1, y + c + (c - 1 - d), self.p['accent'] * 0.75)
            self.rect(x + 5, y + c - 1, x + 6, y + c, self.p['light'] * 0.6)

    def wainscot(self, y, tiles=True):
        col_a, col_b = self.p['accent'] * 0.62, self.p['accent'] * 0.48
        if not tiles:
            self.vgrad(0, y, self.w, self.h, self.shadow * 1.35, self.shadow * 0.95)
            return
        for ty in range(y, self.h, 8):
            for tx in range(0, self.w, 8):
                self.rect(tx, ty, tx + 8, ty + 8, col_a if ((tx + ty) // 8) % 2 else col_b)
                self.rect(tx, ty, tx + 8, ty + 1, self.shadow, 0.5)
                self.rect(tx, ty, tx + 1, ty + 8, self.shadow, 0.5)
        self.rect(0, y - 2, self.w, y, self.p['light'] * 0.4)

    def window(self, cx, base_y, half_w, height, sky=None, beam=True):
        sky = hexc('#9cc6cc') if sky is None else sky
        frame = self.arch_mask(cx, base_y + 2, half_w + 2, height + 3)
        self.mask(frame, self.p['light'] * 0.5)
        m = self.arch_mask(cx, base_y, half_w, height)
        yy, _ = self.grid()
        top = base_y - height
        t = np.clip((yy - top) / max(1, height), 0, 1)[..., None]
        glass = sky * 0.75 * (1 - t) + sky * 0.5 * t
        self.a[m] = glass[m]
        # lattice
        self.mask(m & (np.abs(self.grid()[1] - cx) < 1), self.shadow * 1.2)
        for ly in range(int(top) + 6, int(base_y), 7):
            self.mask(m & (np.abs(yy - ly) < 0.5), self.shadow * 1.2)
        self.rect(cx - half_w - 3, base_y, cx + half_w + 4, base_y + 3, self.p['light'] * 0.45)
        if beam:
            self.beam(cx, half_w * 2, cx + height * 0.6, half_w * 3.2, base_y - height * 0.4, base_y + height * 1.8,
                      self.p['light'], 0.10)

    def lamp(self, x, y_top, length):
        self.rect(x, y_top, x + 1, y_top + length, self.shadow * 0.9)
        y = y_top + length
        self.glow(x, y + 4, 26, self.p['light'], 0.28)
        self.rect(x - 4, y, x + 5, y + 3, self.p['accent2'] * 0.8)
        self.rect(x - 2, y + 3, x + 3, y + 5, self.p['light'] * 0.95)

    def banner(self, x, y, w, h, col):
        self.rect(x - 1, y - 2, x + w + 1, y, self.shadow)
        self.rect(x, y, x + w, y + h, col)
        self.rect(x + 1, y + 1, x + w - 1, y + 2, self.p['light'] * 0.5, 0.6)
        for i in range(w // 2 + 1):
            self.rect(x + i, y + h, x + w - i, y + h + 1, col)
            if i > 3: break
        self.rect(x + w // 2 - 1, y + h // 3, x + w // 2 + 2, y + h // 3 + 3, self.p['light'] * 0.7)

    def vignette(self, strength=0.35):
        yy, xx = self.grid()
        dx = (xx - self.w / 2) / (self.w / 2)
        dy = (yy - self.h / 2) / (self.h / 2)
        f = np.clip(np.sqrt(dx * dx * 0.6 + dy * dy), 0, 1.4) ** 2 * strength
        self.a *= (1 - f)[..., None]

    def finish(self, path, levels=26):
        """Dither onto a ramp from shadow to light that passes through the wing
        colours — the per-wing palette, ~levels colours."""
        img = np.clip(self.a, 0, 255)
        lum = (img * np.array([0.299, 0.587, 0.114])).sum(axis=-1)
        # Keep the room dark: compress values into the backdrop band.
        target = 20 + (lum / 255.0) ** 0.95 * 132
        scale = np.where(lum > 1, target / np.maximum(lum, 1), 1.0)
        img = img * scale[..., None]
        step = 255.0 / levels
        thr = np.tile(BAYER, (self.h // 4 + 1, self.w // 4 + 1))[:self.h, :self.w][..., None]
        q = np.floor(img / step + thr) * step
        out = np.clip(q, 0, 255).astype(np.uint8)
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(out).save(path)


# --------------------------------------------------------------- furniture --

BOOK_COLS = ['#8a3e34', '#5d6e3e', '#a07a3a', '#3e5a6a', '#6a4a6e', '#9a6a44', '#4a6a54']


def bookshelf(c, x0, y0, x1, y1):
    wood, dark = c.p['accent2'] * 0.85, c.shadow * 0.9
    c.rect(x0, y0, x1, y1, dark)
    c.rect(x0, y0, x0 + 3, y1, wood); c.rect(x1 - 3, y0, x1, y1, wood)
    c.rect(x0 - 2, y0 - 4, x1 + 2, y0, wood * 1.1)
    for sy in range(y0 + 14, y1, 14):
        c.rect(x0, sy, x1, sy + 2, wood)
        x = x0 + 3
        while x < x1 - 4:
            bw = c.rng.choice((2, 2, 3, 3, 4))
            bh = c.rng.randint(7, 11)
            col = hexc(c.rng.choice(BOOK_COLS)) * c.rng.uniform(0.75, 1.0)
            if c.rng.random() < 0.08:  # a leaning gap
                x += bw + 1
                continue
            c.rect(x, sy - bh, x + bw, sy, col)
            c.rect(x, sy - bh, x + bw, sy - bh + 1, col * 1.25)
            x += bw
    c.rect(x0, y1 - 2, x1, y1, wood * 0.8)


def ladder(c, x, y0, y1, lean=10):
    wood = c.p['accent2'] * 1.0
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0)
        dx = int(lean * t)
        c.rect(x + dx, y, x + dx + 1, y + 1, wood)
        c.rect(x + dx + 8, y, x + dx + 9, y + 1, wood)
        if (y - y0) % 7 == 0: c.rect(x + dx, y, x + dx + 9, y + 1, wood * 0.9)


def crates(c, x, y_floor, n):
    for i in range(n):
        s = c.rng.choice((14, 16, 18))
        cx = x + i * 17 + c.rng.randint(-2, 2)
        cy = y_floor - s - (16 if i % 3 == 2 else 0)
        wood = c.p['accent2'] * c.rng.uniform(0.7, 0.9)
        c.rect(cx, cy, cx + s, cy + s, wood)
        c.rect(cx, cy, cx + s, cy + 2, wood * 1.2)
        c.rect(cx + 1, cy + s // 2, cx + s - 1, cy + s // 2 + 1, wood * 0.7)
        c.rect(cx, cy, cx + 1, cy + s, wood * 0.6)


def counter(c, x0, x1, y, h=18):
    c.rect(x0, y, x1, y + h, c.p['accent2'] * 0.75)
    c.rect(x0 - 2, y - 3, x1 + 2, y, c.p['light'] * 0.55)
    for x in range(x0 + 6, x1 - 6, 14):
        c.rect(x, y + 4, x + 10, y + h - 3, c.p['accent2'] * 0.6)


def pot(c, x, y, w=16, h=12, steam=True):
    copper = c.p['accent2'] * 1.1
    c.rect(x, y, x + w, y + h, copper)
    c.rect(x, y, x + w, y + 2, copper * 1.25)
    c.rect(x - 2, y + 3, x, y + 5, copper); c.rect(x + w, y + 3, x + w + 2, y + 5, copper)
    if steam:
        for i in range(3):
            sx = x + 4 + i * 4
            for k in range(10):
                c.rect(sx + int(2 * math.sin(k * 0.7 + i)), y - 2 - k * 2, sx + 1 + int(2 * math.sin(k * 0.7 + i)),
                       y - 1 - k * 2, c.p['light'], 0.25 * (1 - k / 10))


def plate_rack(c, x, y, cols, rows):
    for r in range(rows):
        c.rect(x - 2, y + r * 14 + 12, x + cols * 6 + 2, y + r * 14 + 14, c.p['accent2'] * 0.8)
        for k in range(cols):
            px = x + k * 6
            c.rect(px, y + r * 14 + 1, px + 4, y + r * 14 + 12, c.p['light'] * 0.62)
            c.rect(px + 1, y + r * 14 + 3, px + 3, y + r * 14 + 10, c.p['light'] * 0.5)


def chalkboard(c, x, y, w, h):
    c.rect(x - 2, y - 2, x + w + 2, y + h + 2, c.p['accent2'] * 0.8)
    c.rect(x, y, x + w, y + h, hexc('#2c3a34'))
    for ly in range(y + 4, y + h - 2, 5):
        lw = c.rng.randint(w // 3, w - 6)
        c.rect(x + 3, ly, x + 3 + lw, ly + 1, hexc('#b8c4b0'), 0.55)


def pipe_h(c, y, x0, x1, thick=4):
    metal = c.p['accent2'] * 0.75
    c.rect(x0, y, x1, y + thick, metal)
    c.rect(x0, y, x1, y + 1, metal * 1.35)
    for x in range(x0 + 20, x1, 40):
        c.rect(x, y - 1, x + 3, y + thick + 1, metal * 0.8)


def pipe_v(c, x, y0, y1, thick=4):
    metal = c.p['accent2'] * 0.7
    c.rect(x, y0, x + thick, y1, metal)
    c.rect(x, y0, x + 1, y1, metal * 1.35)
    for y in range(y0 + 16, y1, 32):
        c.rect(x - 1, y, x + thick + 1, y + 3, metal * 0.85)


def valve(c, cx, cy, r=5):
    yy, xx = c.grid()
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    c.mask((d <= r) & (d >= r - 1.2), c.p['accent2'] * 1.15)
    c.mask((np.abs(xx - cx) < 0.6) & (d < r), c.p['accent2'])
    c.mask((np.abs(yy - cy) < 0.6) & (d < r), c.p['accent2'])


def stone_arches(c, y_top, span, pier=10):
    """Basement vaulting: recessed round-headed bays between square piers."""
    for x in range(0, c.w + span, span):
        cx = x + span / 2
        half = span / 2 - pier / 2
        bay = c.arch_mask(cx, c.h, half, c.h - y_top, pointed=False)
        ring = c.arch_mask(cx, c.h, half + 3, c.h - y_top + 3, pointed=False) & ~bay
        c.mask(ring, c.wall * 1.18)
        c.mask(bay, c.shadow * 1.15)
        yy, _ = c.grid()
        # the recess catches a little light low down, where the water glows
        c.mask(bay & (yy > c.h - 50), c.shadow * 1.45, 0.5)
        c.rect(x - pier / 2, y_top - 6, x + pier / 2, c.h, c.wall * 0.95)
        c.rect(x - pier / 2, y_top - 6, x - pier / 2 + 1, c.h, c.wall * 1.2)


def caustics(c, y0, y1, col):
    for y in range(y0, y1):
        for x in range(c.w):
            v = math.sin(x * 0.11 + y * 0.31) + math.sin(x * 0.07 - y * 0.23 + 1.7)
            if v > 1.35:
                c.rect(x, y, x + 1, y + 1, col, 0.25 * (1 - (y - y0) / max(1, y1 - y0)))


def wall_bars(c, x, y0, y1, w=22):
    wood = c.p['light'] * 0.62
    c.rect(x, y0, x + 2, y1, wood); c.rect(x + w - 2, y0, x + w, y1, wood)
    for y in range(y0 + 4, y1, 6):
        c.rect(x + 2, y, x + w - 2, y + 1, wood * 0.9)


def rope(c, x, y0, y1):
    for y in range(y0, y1):
        sway = int(1.5 * math.sin(y * 0.05))
        col = c.p['light'] * (0.58 if (y // 2) % 2 else 0.5)
        c.rect(x + sway, y, x + sway + 2, y + 1, col)


def pennants(c, y, x0, x1):
    for x in range(x0, x1):
        sag = int(6 * math.sin((x - x0) / max(1, x1 - x0) * math.pi))
        c.rect(x, y + sag, x + 1, y + sag + 1, c.shadow * 1.4)
    cols = [c.p['accent2'], c.p['accent'], c.p['light'] * 0.8]
    for i, x in enumerate(range(x0 + 4, x1 - 4, 10)):
        sag = int(6 * math.sin((x - x0) / max(1, x1 - x0) * math.pi))
        for k in range(7):
            c.rect(x + k // 2, y + sag + 1 + k, x + 7 - k // 2, y + sag + 2 + k, cols[i % 3] * 0.85)


def lockers(c, x0, x1, y, h):
    for i, x in enumerate(range(x0, x1, 12)):
        col = c.p['accent'] * (0.75 if i % 2 else 0.68)
        c.rect(x, y, x + 11, y + h, col)
        c.rect(x, y, x + 11, y + 1, col * 1.3)
        for v in range(y + 5, y + 14, 3):
            c.rect(x + 3, v, x + 8, v + 1, c.shadow, 0.6)
        c.rect(x + 8, y + h // 2, x + 9, y + h // 2 + 3, c.p['light'] * 0.7)
    c.rect(x0 - 2, y + h, x1 + 2, y + h + 3, c.p['accent2'] * 0.7)


def trophy_cabinet(c, x, y, w, h):
    c.rect(x - 2, y - 2, x + w + 2, y + h + 2, c.p['accent2'] * 0.8)
    c.rect(x, y, x + w, y + h, c.shadow * 1.3)
    for sy in range(y + h // 3, y + h, h // 3):
        c.rect(x, sy, x + w, sy + 1, c.p['light'] * 0.4)
    for sx in range(x + 4, x + w - 6, 9):
        for sy in (y + h // 3, y + 2 * h // 3):
            gold = c.p['light'] * c.rng.uniform(0.85, 1.0)
            c.rect(sx + 2, sy - 9, sx + 5, sy - 5, gold)
            c.rect(sx + 1, sy - 10, sx + 6, sy - 9, gold)
            c.rect(sx + 3, sy - 5, sx + 4, sy - 2, gold * 0.85)
            c.rect(sx + 1, sy - 2, sx + 6, sy, gold * 0.8)
    c.rect(x + 1, y + 1, x + 2, y + h - 1, c.p['light'] * 0.5, 0.5)


def cistern(c, x, y, w, h):
    c.rect(x, y, x + w, y + h, c.shadow * 1.3)
    for cy in range(y, y + h, 8):
        off = 6 * ((cy // 8) % 2)
        c.rect(x, cy, x + w, cy + 1, c.shadow, 0.6)
        for cx in range(x - off, x + w, 12):
            c.rect(cx, cy, cx + 1, cy + 8, c.shadow, 0.5)
    c.rect(x - 2, y - 3, x + w + 2, y, c.wall * 1.15)
    c.rect(x + 3, y + 6, x + w - 3, y + 9, c.p['light'] * 0.45, 0.6)


def mosaic_arch(c, cx, base_y, half_w, height):
    outer = c.arch_mask(cx, base_y, half_w + 6, height + 6)
    inner = c.arch_mask(cx, base_y, half_w, height)
    c.mask(outer & ~inner, c.p['accent'] * 0.7)
    yy, xx = c.grid()
    dots = outer & ~inner & (((xx + yy) % 5) == 0)
    c.mask(dots, c.p['light'] * 0.7)
    c.mask(inner, c.shadow * 1.05)
    c.vgrad(cx - half_w, base_y - 26, cx + half_w + 1, base_y, c.shadow * 1.05, c.shadow * 1.4, 0.6)


# ------------------------------------------------------------------- rooms --

def paint_library(c, room):
    c.back_wall(light=0.02)
    c.frieze(10)
    if room == 'G01':
        c.window(160, 70, 16, 46)
        for x0 in (12, 70, 214, 262):
            bookshelf(c, x0, 40, x0 + 46, 176)
        ladder(c, 116, 52, 176, lean=-8)
        c.lamp(196, 16, 22)
    elif room == 'G02':
        c.rect(0, 92, 320, 98, c.p['accent2'] * 0.7)                      # balcony rail
        for x in range(4, 320, 9): c.rect(x, 82, x + 2, 92, c.p['accent2'] * 0.6)
        for x0 in range(8, 320, 56): bookshelf(c, x0, 22, x0 + 44, 82)
        for x0 in range(30, 320, 70): bookshelf(c, x0, 112, x0 + 48, 184)
        c.lamp(80, 0, 40); c.lamp(240, 0, 40)
    elif room == 'G03':
        for x0 in (8, 96, 184, 272): bookshelf(c, x0, 30, x0 + 40, 170)
        crates(c, 54, 184, 2); crates(c, 140, 184, 2); crates(c, 228, 184, 2)
        for i in range(6):
            x, y = c.rng.randint(10, 300), c.rng.randint(12, 40)
            for k in range(8): c.rect(x + k, y + k // 2, x + k + 1, y + k // 2 + 1, c.p['light'] * 0.35, 0.5)  # cobwebs
        c.glow(150, 120, 30, c.p['light'], 0.18)
    else:  # G04 back stair
        c.window(250, 60, 12, 36)
        for i in range(10):
            x, y = 30 + i * 22, 176 - i * 14
            c.rect(x, y, x + 26, y + 4, c.p['accent2'] * 0.75)
            c.rect(x, y + 4, x + 2, 184, c.p['accent2'] * 0.5)
        bookshelf(c, 6, 60, 50, 176)
    c.vignette(0.3)


def paint_cafeteria(c, room):
    c.back_wall(block=12, course=6, light=0.05)
    c.wainscot(120)
    c.frieze(14)
    if room == 'R01':
        counter(c, 40, 280, 100)
        for x in (60, 100, 150, 200, 250): pot(c, x, 88)
        chalkboard(c, 120, 34, 70, 36)
        for x in (40, 160, 280): c.lamp(x, 0, 18)
    elif room == 'R02':
        for x in (24, 92, 230): pot(c, x, 104, w=22, h=16)
        c.rect(150, 40, 210, 118, c.shadow * 1.2)                      # roll-up shutter
        for y in range(42, 118, 4): c.rect(152, y, 208, y + 1, c.wall * 1.1)
        plate_rack(c, 250, 30, 9, 4)
        c.lamp(120, 0, 24); c.lamp(280, 0, 20)
    elif room == 'R03':
        plate_rack(c, 20, 26, 12, 5); plate_rack(c, 220, 26, 12, 5)
        pipe_h(c, 112, 0, 320); pipe_v(c, 120, 0, 112); pipe_v(c, 196, 0, 112)
        for x in (110, 180): c.rect(x, 128, x + 40, 150, c.p['light'] * 0.42)  # sinks
        c.lamp(160, 0, 28)
    else:  # R04 staff corridor
        for x in range(20, 320, 70):
            c.rect(x, 60, x + 30, 120, c.p['accent2'] * 0.6)
            c.rect(x + 23, 88, x + 26, 92, c.p['light'] * 0.8)
        chalkboard(c, 250, 40, 40, 26)
        c.lamp(100, 0, 30); c.lamp(220, 0, 30)
    c.vignette(0.3)


def paint_basement(c, room):
    c.back_wall(block=18, course=9, light=-0.05)
    stone_arches(c, 30, 80)
    if room == 'B01':
        for x in (40, 200): cistern(c, x, 100, 60, 84)
        pipe_h(c, 40, 0, 320, 6); pipe_v(c, 300, 40, 184, 6); valve(c, 150, 60)
    elif room == 'B02':
        pipe_h(c, 30, 0, 320, 5); pipe_h(c, 48, 0, 320, 3)
        for x in (70, 170, 270): valve(c, x, 32)
    elif room == 'B03':
        for x in (20, 120, 220): cistern(c, x, 70, 70, 114)
        pipe_v(c, 100, 0, 184, 5); pipe_v(c, 204, 0, 184, 5)
        for x in (60, 160, 260): valve(c, x, 60, 6)
        c.beam(160, 18, 180, 40, 0, 120, c.p['light'], 0.12)
    else:  # B04 dry stair
        for i in range(9):
            x, y = 220 - i * 22, 180 - i * 18
            c.rect(x, y, x + 30, y + 6, c.wall * 1.25)
        c.lamp(60, 0, 34)
        pipe_v(c, 290, 0, 184, 5)
    caustics(c, 110, 192, c.p['light'])
    c.vignette(0.38)


def paint_gym(c, room):
    c.vgrad(0, 0, c.w, c.h, c.wall * 0.85, c.wall * 1.05)
    for i, x in enumerate(range(0, c.w, 10)):                          # plank panelling
        c.rect(x, 0, x + 10, c.h, c.p['light'] * 0.42 if i % 2 else c.p['light'] * 0.36, 0.55)
        c.rect(x, 0, x + 1, c.h, c.shadow, 0.6)
    c.vgrad(0, 122, c.w, c.h, c.p['accent'] * 0.45, c.p['accent'] * 0.3, 0.8)    # painted dado
    c.rect(0, 118, c.w, 122, c.p['accent2'] * 0.8)                      # painted stripe
    c.frieze(8)
    if room == 'Y01':
        for x in (60, 160, 260): c.window(x, 60, 12, 40)
        for x in (10, 290): wall_bars(c, x, 70, 184)
        for x in (110, 210): rope(c, x, 0, 150)
    elif room == 'Y02':
        wall_bars(c, 20, 40, 184); wall_bars(c, 50, 40, 184)
        c.rect(130, 150, 190, 184, c.p['accent2'] * 0.75)              # vaulting box
        for y in range(156, 184, 7): c.rect(130, y, 190, y + 1, c.shadow, 0.6)
        for i in range(3): c.rect(220 + i * 4, 160 - i * 8, 300 - i * 4, 168 - i * 8, c.p['accent'] * 0.7)  # mats
        pennants(c, 26, 100, 300)
    elif room == 'Y03':
        for x in (30, 130, 230): trophy_cabinet(c, x, 50, 60, 90)
        for x in (106, 206): c.banner(x, 40, 12, 30, c.p['accent2'] * 0.8)
        pennants(c, 20, 10, 310)
    else:  # Y04 lockers
        lockers(c, 10, 310, 70, 90)
        c.window(160, 44, 10, 26)
    c.vignette(0.3)


def paint_hub(c):
    c.back_wall(block=20, course=10)
    c.frieze(12, 8)
    c.frieze(200, 8)
    for cx in (80, 240, 400, 560):
        mosaic_arch(c, cx, 190, 34, 140)
        mosaic_arch(c, cx, 376, 30, 120)
    for cx in (160, 480):
        c.window(cx, 130, 14, 60, beam=True)
    for x in (40, 300, 600):
        c.lamp(x, 0, 30)
    for i, x in enumerate((120, 200, 440, 520)):
        col = [hexc('#b54c41'), hexc('#548f68'), hexc('#449bb8'), hexc('#deaf4a')][i] * 0.75
        Canvas.banner(c, x, 30, 16, 44, col)
    c.vignette(0.32)


def main():
    rooms = {'Hub': None}
    for wing, letter in (('Green', 'G'), ('Red', 'R'), ('Blue', 'B'), ('Gold', 'Y')):
        for i in range(1, 5):
            rooms[f'{letter}0{i}'] = wing
    for room, wing in rooms.items():
        if room == 'Hub':
            c = Canvas(640, 384, 'Hub', 'Hub')
            paint_hub(c)
        else:
            c = Canvas(320, 192, wing, room)
            {'Green': paint_library, 'Red': paint_cafeteria, 'Blue': paint_basement, 'Gold': paint_gym}[wing](c, room)
        c.finish(OUT / f'Prison_{room}.png')
    print('Wrote', len(rooms), 'backdrops to', OUT.relative_to(ROOT))


if __name__ == '__main__':
    main()
