#!/usr/bin/env python3
"""The tiger of Act III's last scene (SCRIPT.md TWELVE and THIRTEEN): the one
that steps out of the tall grass and runs Hooshang to the edge of the land, and
its twin pacing at the foot of the cliff. Side view, facing right, in the
adult rig's own scale (Hooshang is 16px tall; a tiger is ~30px long and ~13px
at the shoulder) and outline weight.

Built the way tools/gen_chubby_hooshang.py builds weight onto Hooshang, not
drawn frame by frame: a four-legged gallop drawn by hand drifts from frame to
frame. A small RIG of shapes (a long low body, a head and muzzle, two ears, four
jointed legs, a curving tail) is posed per frame by a handful of numbers and
coloured by rule: lit along the back, cream at the belly, chest and muzzle,
dark stripes across the orange only, the far-side legs a shade darker, and a
one-pixel outline round the whole silhouette.

Writes assets/characters/tiger/frames/<clip>_<n>.png (44x22 each), then
builds assets/characters/tiger/tiger.aseprite from them with Aseprite (tags per
clip) and exports the sheet the game plays: assets/characters/tiger/tiger.png
+ tiger.json. Edit poses here, or pixels in the .aseprite, then re-export.

    python3 tools/gen_tiger.py
"""
import json
import math
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/tiger'
FRAMES = OUT / 'frames'
ASEPRITE = '/Users/ari/Applications/Aseprite.app/Contents/MacOS/aseprite'
CW, CH = 44, 22


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)] + [255], dtype=np.uint8)


C = {k: hexc(v) for k, v in {
    'outline': '#22150f', 'orange': '#e5802c', 'lit': '#f6a548', 'shade': '#b65a1e', 'far': '#9c4b1a',
    'cream': '#f6ead2', 'cream_shade': '#d8c3a0', 'stripe': '#2a1a14', 'eye': '#e8c23a', 'pupil': '#22150f',
    'nose': '#c97b74', 'mouth': '#7a2626', 'teeth': '#fffaf0', 'tongue': '#c9555a',
}.items()}

# Pixel classes painted into the canvas before colouring.
EMPTY, BODY, FAR_LEG, NEAR_LEG, HEAD, MUZZLE, EAR, TAIL, MOUTH, TEETH = range(10)


class Rig:
    def __init__(self):
        self.cls = np.zeros((CH, CW), dtype=np.int8)

    def ellipse(self, cx, cy, rx, ry, cls, only_empty=False):
        ys, xs = np.mgrid[0:CH, 0:CW]
        m = ((xs + 0.5 - cx) / rx) ** 2 + ((ys + 0.5 - cy) / ry) ** 2 <= 1.0
        if only_empty:
            m &= self.cls == EMPTY
        self.cls[m] = cls

    def thick_line(self, pts, width, cls, only_empty=False):
        """A limb or tail: a polyline swept with a disc."""
        ys, xs = np.mgrid[0:CH, 0:CW]
        m = np.zeros((CH, CW), dtype=bool)
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            dx, dy = x1 - x0, y1 - y0
            L2 = max(1e-6, dx * dx + dy * dy)
            t = np.clip(((xs + 0.5 - x0) * dx + (ys + 0.5 - y0) * dy) / L2, 0, 1)
            px, py = x0 + t * dx, y0 + t * dy
            m |= (xs + 0.5 - px) ** 2 + (ys + 0.5 - py) ** 2 <= (width / 2) ** 2
        if only_empty:
            m &= self.cls == EMPTY
        self.cls[m] = cls

    def poly(self, pts, cls):
        ys, xs = np.mgrid[0:CH, 0:CW]
        inside = np.zeros((CH, CW), dtype=bool)
        n = len(pts)
        for i in range(n):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
            cond = ((y0 > ys + 0.5) != (y1 > ys + 0.5))
            xint = x0 + (ys + 0.5 - y0) * (x1 - x0) / np.where(y1 == y0, 1e-6, (y1 - y0))
            inside ^= cond & (xs + 0.5 < xint)
        self.cls[inside] = cls


def leg(hip, angle_upper, angle_lower, upper, lower):
    """Joint positions for a leg: angles in degrees from straight down,
    positive swinging forward (toward +x)."""
    a1 = math.radians(angle_upper)
    knee = (hip[0] + math.sin(a1) * upper, hip[1] + math.cos(a1) * upper)
    a2 = math.radians(angle_lower)
    paw = (knee[0] + math.sin(a2) * lower, knee[1] + math.cos(a2) * lower)
    return [hip, knee, paw]


def pose(p):
    """Render one pose dict to an RGBA image."""
    rig = Rig()
    bob = p.get('bob', 0.0)
    cx, cy = 19.5, 10.0 + bob          # body centre
    stretch = p.get('stretch', 1.0)
    shoulder = (cx + 9.0 * stretch, cy + 1.5)
    hip = (cx - 9.0 * stretch, cy + 1.0)
    # far-side legs first, a shade darker, so the near ones overlap them
    fl = p['legs']
    rig.thick_line(leg((shoulder[0] - 1.5, shoulder[1]), *fl['front_far'], 4.6, 5.0), 2.6, FAR_LEG)
    rig.thick_line(leg((hip[0] + 1.5, hip[1]), *fl['back_far'], 4.8, 5.0), 2.8, FAR_LEG)
    # tail: from the rump, curving per pose
    t = p.get('tail', (-6, -4, -11, -6))
    rump = (hip[0] - 2.5, cy - 1.5)
    rig.thick_line([rump, (rump[0] + t[0] * 0.5, rump[1] + t[1] * 0.4), (rump[0] + t[0], rump[1] + t[1]),
                    (rump[0] + t[2], rump[1] + t[3])], 1.9, TAIL)
    # the body: haunch, a tucked belly, the deep chest and the shoulder hump
    rig.ellipse(cx - 1.0, cy - 0.4, 11.0 * stretch, 3.7, BODY)
    rig.ellipse(hip[0] + 1.2, cy - 0.6, 4.9, 4.5, BODY)
    rig.ellipse(shoulder[0] - 0.8, cy + 0.1 + p.get('shoulder_dip', 0.0), 4.6, 5.0, BODY)
    rig.ellipse(shoulder[0] - 1.5, cy - 3.6 + p.get('shoulder_dip', 0.0), 3.6, 1.8, BODY)
    # near-side legs over the body
    rig.thick_line(leg(shoulder, *fl['front_near'], 4.6, 5.2), 3.0, NEAR_LEG)
    rig.thick_line(leg(hip, *fl['back_near'], 4.8, 5.2), 3.2, NEAR_LEG)
    # the head, carried per pose
    hx, hy = shoulder[0] + 6.0 + p.get('head_dx', 0.0), cy - 3.3 + p.get('head_dy', 0.0)
    rig.thick_line([(shoulder[0] + 1.5, cy - 2.0), (hx - 1.0, hy + 0.5)], 5.6, BODY)   # neck
    rig.ellipse(hx, hy, 4.5, 4.1, HEAD)
    rig.ellipse(hx - 2.2, hy + 2.0, 2.4, 2.0, HEAD)          # cheek ruff
    tilt = p.get('head_tilt', 0.0)
    mx, my = hx + 3.9, hy + 1.4 + tilt
    rig.ellipse(mx, my, 2.7, 2.1, MUZZLE)
    rig.ellipse(hx - 2.0, hy - 3.6, 1.5, 1.6, EAR)
    rig.ellipse(hx + 1.2, hy - 4.0, 1.5, 1.6, EAR)
    if p.get('roar', 0.0) > 0:
        o = p['roar']
        rig.poly([(mx - 1.2, my + 0.2), (mx + 3.0, my - 0.4 - o * 0.6), (mx + 3.0, my + 1.4 + o)], MOUTH)
        rig.poly([(mx + 1.6, my - 0.1), (mx + 2.4, my - 0.2), (mx + 2.0, my + 0.9)], TEETH)
        rig.poly([(mx + 1.6, my + 1.3 + o * 0.6), (mx + 2.4, my + 1.3 + o * 0.6), (mx + 2.0, my + 0.4 + o * 0.6)], TEETH)
    return colour(rig, p, (hx, hy), (mx, my), cy)


# Stripe centres along the body, relative to its centre: irregular on purpose.
STRIPES = [-12.5, -9.8, -7.4, -4.6, -2.1, 0.6, 3.0, 5.9, 8.4]
STRIPE_W = [1.0, 1.3, 0.9, 1.4, 1.0, 1.3, 0.9, 1.2, 1.0]


def colour(rig, p, head, muzzle, cy):
    img = np.zeros((CH, CW, 4), dtype=np.uint8)
    cls = rig.cls
    hx, hy = head
    mx, my = muzzle
    cx = 19.5
    stretch = p.get('stretch', 1.0)
    top = cy - 4.3
    for y in range(CH):
        for x in range(CW):
            k = cls[y, x]
            if k == EMPTY:
                continue
            c = C['orange']
            if k == BODY:
                rel = y + 0.5 - top
                if rel < 1.8:
                    c = C['lit']
                elif rel > 6.0:
                    c = C['cream'] if rel < 8.2 else C['cream_shade']
                if c is not C['cream'] and c is not C['cream_shade'] and x < hx - 2.5:
                    # tapering bands, leaning back a little as they run down the flank
                    for sx, sw in zip(STRIPES, STRIPE_W):
                        centre = cx + sx * stretch + (rel - 1.0) * 0.35
                        width = sw * max(0.35, 1.0 - abs(rel - 2.4) / 4.5)
                        if abs(x + 0.5 - centre) < width and 1.3 < rel < 6.2:
                            c = C['stripe']
            elif k == HEAD:
                c = C['lit'] if y < hy - 1.8 else C['orange']
                if y > hy + 0.6 and x < hx + 0.5:
                    c = C['cream']            # the ruff
                if abs(x + 0.5 - (hx - 0.6)) < 0.6 and hy - 3.5 < y < hy - 1.2:
                    c = C['stripe']           # forehead mark
                if abs(x + 0.5 - (hx - 3.0)) < 0.7 and hy - 1.0 < y < hy + 1.6:
                    c = C['stripe']           # cheek stripe
            elif k == MUZZLE:
                c = C['cream'] if y >= my - 0.7 else C['orange']
            elif k == EAR:
                c = C['stripe'] if y < hy - 4.3 else C['shade']
            elif k == FAR_LEG:
                c = C['far'] if y < CH - 3 else C['cream_shade']
            elif k == NEAR_LEG:
                c = C['orange']
                if y >= CH - 3:
                    c = C['cream']
                elif y == int(cy + 4):
                    c = C['stripe']
            elif k == TAIL:
                c = C['orange'] if (x + y) % 4 else C['stripe']
            elif k == MOUTH:
                c = C['mouth']
            elif k == TEETH:
                c = C['teeth']
            img[y, x] = c
    # tail tip dark: the tail pixel furthest from the body
    tail = np.argwhere(cls == TAIL)
    if len(tail):
        tip = tail[np.argmin(tail[:, 1])]
        for dy in (0, 1):
            for dx in (0, 1):
                yy, xx = tip[0] + dy, tip[1] + dx
                if 0 <= yy < CH and 0 <= xx < CW and cls[yy, xx] == TAIL:
                    img[yy, xx] = C['stripe']
    # face: a dark brow over the eye, the eye, the nose
    ex, ey = int(round(hx + 1.2)), int(round(hy - 0.6 + p.get('eye_dy', 0.0)))
    if 0 <= ey < CH and 0 <= ex < CW:
        if ey - 1 >= 0 and cls[ey - 1, ex] != EMPTY:
            img[ey - 1, ex] = C['stripe']
        img[ey, ex] = C['pupil'] if p.get('roar', 0) > 0 else C['eye']
        if ex + 1 < CW and cls[ey, ex + 1] != EMPTY and p.get('roar', 0) == 0:
            img[ey, ex + 1] = C['pupil']
    nx, ny = int(round(mx + 2.0)), int(round(my - 1.0))
    if 0 <= ny < CH and 0 <= nx < CW and cls[ny, nx] != EMPTY:
        img[ny, nx] = C['nose']
    # one-pixel outline round the silhouette
    filled = cls != EMPTY
    out = img.copy()
    for y in range(CH):
        for x in range(CW):
            if filled[y, x]:
                continue
            if any(0 <= y + dy < CH and 0 <= x + dx < CW and filled[y + dy, x + dx]
                   for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))):
                out[y, x] = C['outline']
    # a seam where a near leg leaves the body, so the leg reads in front of it
    for y in range(1, CH):
        for x in range(1, CW - 1):
            if cls[y, x] == NEAR_LEG and cls[y, x - 1] == BODY:
                out[y, x - 1] = C['shade']
    return Image.fromarray(out)


def legs(ff, fn, bf, bn):
    return {'front_far': ff, 'front_near': fn, 'back_far': bf, 'back_near': bn}


# Leg angles: (upper, lower) in degrees from vertical, + swings forward.
CLIPS = {
    # A bounding gallop: reach, gather, plant, push.
    'run': [
        dict(legs=legs((55, 70), (62, 78), (-55, -70), (-62, -78)), bob=-0.6, stretch=1.08, tail=(-7, -3, -13, -4)),
        dict(legs=legs((20, -10), (8, -25), (40, 25), (28, 10)), bob=0.4, stretch=0.92, shoulder_dip=0.5,
             tail=(-6, -5, -11, -8)),
        dict(legs=legs((-15, -30), (-5, -20), (25, 45), (40, 55)), bob=0.0, stretch=0.96, tail=(-6, -6, -10, -10)),
        dict(legs=legs((35, 10), (45, 25), (-30, -50), (-40, -60)), bob=-0.8, stretch=1.04, tail=(-7, -4, -12, -6)),
    ],
    # The prowl out of the grass: low, shoulders working.
    'walk': [
        dict(legs=legs((15, 0), (-10, 0), (-5, 0), (15, 5)), bob=0.6, shoulder_dip=0.8, head_dy=1.2,
             tail=(-6, 2, -11, 1)),
        dict(legs=legs((5, 0), (0, 0), (5, 0), (5, 0)), bob=0.8, shoulder_dip=0.4, head_dy=1.5, tail=(-6, 2, -11, 0)),
        dict(legs=legs((-10, 0), (15, 5), (15, 5), (-5, 0)), bob=0.6, shoulder_dip=0.8, head_dy=1.2,
             tail=(-6, 2, -11, 1)),
        dict(legs=legs((0, 0), (5, 0), (5, 0), (5, 0)), bob=0.8, shoulder_dip=0.4, head_dy=1.5, tail=(-6, 2, -11, 2)),
    ],
    'roar': [
        dict(legs=legs((10, 0), (-5, 0), (-5, 0), (10, 0)), bob=0.0, head_dy=-1.5, head_dx=0.5, roar=1.0,
             tail=(-6, -6, -9, -11)),
        dict(legs=legs((10, 0), (-5, 0), (-5, 0), (10, 0)), bob=-0.3, head_dy=-2.0, head_dx=0.8, roar=1.8,
             tail=(-5, -7, -8, -12)),
    ],
    # At the cliff edge, looking down at him: front low, head over the drop.
    'look_down': [
        dict(legs=legs((25, -20), (30, -10), (-5, 0), (5, 0)), bob=0.8, shoulder_dip=1.5, head_dy=3.0, head_dx=0.5,
             head_tilt=1.0, eye_dy=0.8, tail=(-6, -2, -11, -3)),
        dict(legs=legs((25, -20), (30, -10), (-5, 0), (5, 0)), bob=0.8, shoulder_dip=1.5, head_dy=3.3, head_dx=0.5,
             head_tilt=1.0, eye_dy=0.8, tail=(-6, -3, -10, -6)),
    ],
    # At the foot of the cliff, looking up at him.
    'look_up': [
        dict(legs=legs((10, 0), (0, 0), (-10, 0), (0, 0)), bob=0.0, head_dy=-2.3, head_dx=-0.5, head_tilt=-0.8,
             eye_dy=-0.4, tail=(-6, -1, -11, -2)),
        dict(legs=legs((10, 0), (0, 0), (-10, 0), (0, 0)), bob=0.2, head_dy=-2.5, head_dx=-0.5, head_tilt=-0.8,
             eye_dy=-0.4, tail=(-6, -3, -10, -6)),
    ],
}
# Playback, ms per frame.
TIMING = {'run': 85, 'walk': 150, 'roar': 220, 'look_down': 600, 'look_up': 600}


def main():
    FRAMES.mkdir(parents=True, exist_ok=True)
    for old in FRAMES.glob('*.png'):
        old.unlink()
    order = []
    for clip, poses in CLIPS.items():
        for i, p in enumerate(poses):
            path = FRAMES / f'{clip}_{i}.png'
            pose(p).save(path)
            order.append((clip, path))
    # Build the editable Aseprite source, one tag per clip, then export the sheet.
    lua = OUT / 'build_tiger.lua.tmp'
    lines = ['local spr = Sprite(%d, %d, ColorMode.RGB)' % (CW, CH),
             'local layer = spr.layers[1]', 'layer.name = "Tiger"']
    for i, (clip, path) in enumerate(order):
        if i > 0:
            lines.append('spr:newEmptyFrame()')
        lines.append('spr:newCel(layer, %d, Image{ fromFile = "%s" }, Point(0, 0))' % (i + 1, path))
        lines.append('spr.frames[%d].duration = %f' % (i + 1, TIMING[clip] / 1000))
    start = 1
    for clip, poses in CLIPS.items():
        lines.append('do local t = spr:newTag(%d, %d) t.name = "%s" end' % (start, start + len(poses) - 1, clip))
        start += len(poses)
    lines.append('spr:saveAs("%s")' % (OUT / 'tiger.aseprite'))
    lua.write_text('\n'.join(lines) + '\n')
    subprocess.run([ASEPRITE, '-b', '--script', str(lua)], check=True)
    lua.unlink()
    subprocess.run([ASEPRITE, '-b', str(OUT / 'tiger.aseprite'), '--sheet', str(OUT / 'tiger.png'),
                    '--sheet-type', 'horizontal', '--data', str(OUT / 'tiger.json'),
                    '--format', 'json-array', '--list-tags'], check=True)
    data = json.loads((OUT / 'tiger.json').read_text())
    print('tiger: %d frames, tags %s' % (len(data['frames']), [t['name'] for t in data['meta']['frameTags']]))


if __name__ == '__main__':
    main()
