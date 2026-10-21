#!/usr/bin/env python3
"""Act III's sprite sheets -> assets/act3/sea/.

Two kinds of art, drawn by hand in code (the project's rule: geometry is
procedural and native-resolution, never reduced from a generated bitmap):

  - LIVING / PRECIOUS things in their own colour: the jellyfish (pale bell,
    RED tentacles — red is lethal everywhere in this game), the air bubble,
    and the memories Hooshang finds in the wreck (name plate, photograph,
    ticket, letter, spray can, the pearl).
  - SET DRESSING in Act III's LINE language, white contour on black with grey
    for shading (decor.png). SeaDecor draws it through the same depth shader as
    the terrain (assets/shaders/act3_depth_tint.gdshader), which maps luminance
    0..1 onto that depth's fill..line, so one drawing is line art on the shore
    and gold at the floor.

Pixellab's subscription lapsed (memory: hooshang-asset-import-workarounds), so
there is no swatch here; the palettes are chosen to sit on the depth ramp in
scripts/act3/sea_palette.gd.

    python3 tools/gen_act3_sea_art.py
"""
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/act3/sea'
CLEAR = (0, 0, 0, 0)


def rgba(hexstr, a=255):
    hexstr = hexstr.lstrip('#')
    return tuple(int(hexstr[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), c)


def blend(img, x, y, c):
    if not (0 <= x < img.width and 0 <= y < img.height):
        return
    r, g, b, a = img.getpixel((int(x), int(y)))
    if a == 0:
        img.putpixel((int(x), int(y)), c)
        return
    t = c[3] / 255
    img.putpixel((int(x), int(y)), (round(r + (c[0] - r) * t), round(g + (c[1] - g) * t),
                                    round(b + (c[2] - b) * t), max(a, c[3])))


# ------------------------------------------------------------- jellyfish ---

BELL_RIM = rgba('cdf6ff')
BELL_HI = rgba('ffffff')
BELL_BODY = rgba('7fc8ec', 215)
BELL_SHADE = rgba('4f8fc4', 225)
BELL_CORE = rgba('ff9ccf', 235)
STING = rgba('ff3d29')
STING_DARK = rgba('a8182a')
STING_TIP = rgba('ffb08a')


def jellyfish():
    """4 frames, 16x20. Bell rows 1..7 (centre x 7.5), tentacles 8..19."""
    sheet = Image.new('RGBA', (64, 20), CLEAR)
    for f in range(4):
        img = Image.new('RGBA', (16, 20), CLEAR)
        pulse = [0, 1, 1, 0][f]          # the bell contracts on frames 1-2
        half = 7 - pulse * 0.6
        top = 1 + pulse
        for y in range(top, 8):
            t = (y - top) / max(7 - top, 1)
            w = half * math.sqrt(max(0.0, 1.0 - (1.0 - t) ** 2 * 0.95))
            if y == 7:
                w = half + 0.4
            x0, x1 = round(7.5 - w), round(7.5 + w) - 1
            for x in range(x0, x1 + 1):
                edge = x in (x0, x1) or y == top
                inner = abs(x - 7.5) < w * 0.35 and 3 + pulse <= y <= 6
                c = BELL_RIM if edge else (BELL_CORE if inner else (BELL_SHADE if x > 7.5 + w * 0.4 else BELL_BODY))
                put(img, x, y, c)
        # Highlight: two pixels upper left.
        put(img, 4, top + 2, BELL_HI)
        put(img, 5, top + 1, BELL_HI)
        # The scalloped skirt along the bell's lip.
        for x in range(round(7.5 - half), round(7.5 + half)):
            if (x + f) % 3 == 0:
                put(img, x, 8, BELL_RIM)
        # Tentacles: five strands, each swaying on its own phase.
        for i, sx in enumerate((3, 5, 7, 9, 12)):
            length = 9 + (i % 2) * 2 - pulse
            for k in range(length):
                y = 9 + k
                if y >= 20:
                    break
                sway = round(math.sin((k * 0.55) + f * math.pi / 2 + i * 1.3) * (0.4 + k * 0.12))
                c = STING_TIP if k == length - 1 else (STING_DARK if (k + i) % 4 == 3 else STING)
                put(img, sx + sway, y, c)
        sheet.paste(img, (f * 16, 0), img)
    return sheet


# ------------------------------------------------------------ air bubble ---

def air_bubble():
    sheet = Image.new('RGBA', (64, 16), CLEAR)
    rim = rgba('d8f6ff')
    fill = rgba('9fe4ff', 60)
    hi = rgba('ffffff')
    for f in range(4):
        img = Image.new('RGBA', (16, 16), CLEAR)
        sx = 5.6 + [0, 0.35, 0, -0.35][f]
        sy = 5.6 - [0, 0.35, 0, -0.35][f]
        for y in range(16):
            for x in range(16):
                d = ((x - 7.5) / sx) ** 2 + ((y - 7.5) / sy) ** 2
                if d <= 1.0:
                    put(img, x, y, fill)
                if 0.72 <= d <= 1.08:
                    put(img, x, y, rim)
        put(img, 5, 5, hi)
        put(img, 6, 4, hi)
        put(img, 4, 6, hi)
        put(img, 10, 11, rgba('ffffff', 160))
        sheet.paste(img, (f * 16, 0), img)
    return sheet


# --------------------------------------------------------------- memories --

def memories():
    sheet = Image.new('RGBA', (96, 16), CLEAR)

    def frame(i):
        return Image.new('RGBA', (16, 16), CLEAR), i

    out = []
    # 0 name plate: a brass desk plate on a dark wood wedge, two lines of type.
    img, _ = frame(0)
    wood, wood_d = rgba('6b3f22'), rgba('3e2414')
    brass, brass_h, brass_d = rgba('e8bf5a'), rgba('fff0a8'), rgba('a37a28')
    ink = rgba('3a2a12')
    for x in range(2, 14):
        for y in range(9, 13):
            put(img, x, y, wood if y < 12 else wood_d)
    for x in range(2, 14):
        for y in range(5, 10):
            edge = x in (2, 13) or y in (5, 9)
            put(img, x, y, brass_d if edge else brass)
    for x in range(3, 13):
        put(img, x, 6, brass_h)
    for x in (4, 5, 6, 8, 9, 10, 11):
        put(img, x, 7, ink)
    for x in (5, 6, 7, 9, 10):
        put(img, x, 8, ink)
    out.append(img)
    # 1 photograph: white border, sky, two small figures by a pond.
    img, _ = frame(1)
    paper, shade = rgba('f4efe2'), rgba('c9c1ad')
    sky, pond, grass = rgba('9ed2f0'), rgba('3f86c8'), rgba('6aa84f')
    for x in range(2, 14):
        for y in range(2, 14):
            put(img, x, y, paper)
    for x in range(3, 13):
        for y in range(3, 11):
            put(img, x, y, sky if y < 7 else (grass if y < 9 else pond))
    for x in range(8, 13):
        put(img, x, 9, pond)
    for (fx, c) in ((5, rgba('d84a3a')), (7, rgba('f2c46d'))):
        put(img, fx, 6, rgba('3a2a1e'))
        put(img, fx, 7, c)
        put(img, fx, 8, c)
    for x in range(2, 14):
        put(img, x, 13, shade)
    for y in range(2, 14):
        put(img, 13, y, shade)
    out.append(img)
    # 2 ticket: cream card, red band, perforated stub, a plane mark.
    img, _ = frame(2)
    card, card_d, band = rgba('f6ead0'), rgba('cbb88f'), rgba('c8323a')
    for x in range(1, 15):
        for y in range(4, 12):
            put(img, x, y, card)
    for x in range(1, 15):
        put(img, x, 5, band)
        put(img, x, 11, card_d)
    for y in range(4, 12):
        if y % 2 == 0:
            put(img, 11, y, card_d)
    for x, y in ((4, 8), (5, 8), (6, 8), (5, 7), (5, 9), (3, 8)):
        put(img, x, y, rgba('2e3a5c'))
    for x in (7, 8, 9):
        put(img, x, 9, rgba('8a7a5a'))
    out.append(img)
    # 3 letter: an envelope, flap open, never sent.
    img, _ = frame(3)
    env, env_d, line = rgba('efe6d2'), rgba('bfb193'), rgba('9a8a6a')
    for x in range(1, 15):
        for y in range(4, 13):
            put(img, x, y, env)
    for x in range(1, 15):
        put(img, x, 12, env_d)
        d = abs(x - 7.5)
        put(img, x, 4 + round(min(d, 7.5) * 0.0) + round((7.5 - d) * 0.55), env_d)
    for x in range(4, 12):
        put(img, x, 10, line)
    put(img, 12, 6, rgba('c8323a'))
    put(img, 12, 7, rgba('c8323a'))
    out.append(img)
    # 4 spray can: rusted through, teal paint dried down one side.
    img, _ = frame(4)
    rust, rust_d, rust_h = rgba('9a5a32'), rgba('5e331c'), rgba('c98a54')
    teal = rgba('3fb8a8')
    for y in range(4, 15):
        for x in range(5, 11):
            c = rust_d if x == 10 else (rust_h if x == 6 else rust)
            if (x * 7 + y * 3) % 11 == 0:
                c = rust_d
            put(img, x, y, c)
    for x in range(6, 10):
        put(img, x, 3, rgba('8c8c8c'))
    put(img, 7, 2, rgba('d0d0d0'))
    put(img, 8, 2, rgba('d0d0d0'))
    for y in range(6, 12):
        put(img, 5, y, teal)
    put(img, 6, 12, teal)
    out.append(img)
    # 5 pearl: white, faintly pink, lit from inside.
    img, _ = frame(5)
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 7.5)
            if d <= 4.2:
                t = d / 4.2
                c = (round(255 - 25 * t), round(246 - 40 * t), round(250 - 30 * t), 255)
                put(img, x, y, c)
            elif d <= 6.2:
                put(img, x, y, (255, 240, 220, round(90 * (1 - (d - 4.2) / 2))))
    put(img, 6, 6, (255, 255, 255, 255))
    put(img, 6, 5, (255, 255, 255, 255))
    out.append(img)
    for i, img in enumerate(out):
        sheet.paste(img, (i * 16, 0), img)
    return sheet


# ------------------------------------------------------------------ decor --
# White = the depth's LINE colour, black = its FILL, grey between. Transparent
# around everything.

W = (255, 255, 255, 255)
K = (0, 0, 0, 255)
G1 = (170, 170, 170, 255)
G2 = (95, 95, 95, 255)


def decor():
    img = Image.new('RGBA', (96, 72), CLEAR)

    def at(cx, cy):
        return cx * 8, cy * 8

    # kelp cap (0,0) and stem (0,1): a central stipe with alternating blades.
    ox, oy = at(0, 0)
    for y in range(8):
        put(img, ox + 4, oy + y, W)
    for (x, y) in ((3, 1), (2, 2), (5, 3), (6, 4), (3, 5), (2, 6), (1, 7)):
        put(img, ox + x, oy + y, G1)
    put(img, ox + 4, oy, G1)
    ox, oy = at(0, 1)
    for y in range(8):
        put(img, ox + 4, oy + y, W)
    for (x, y) in ((3, 0), (2, 1), (5, 3), (6, 4), (7, 5), (3, 6), (2, 7)):
        put(img, ox + x, oy + y, G1)
    for (x, y) in ((5, 1), (3, 4), (5, 6)):
        put(img, ox + x, oy + y, G2)
    # reed cap (1,0) and stem (1,1)
    ox, oy = at(1, 0)
    for y in range(2, 8):
        put(img, ox + 3, oy + y, W)
    for y in range(0, 4):
        put(img, ox + 4, oy + y, G1)
    put(img, ox + 3, oy + 1, W)
    put(img, ox + 3, oy + 2, G1)
    ox, oy = at(1, 1)
    for y in range(8):
        put(img, ox + 3, oy + y, W)
        if y > 3:
            put(img, ox + 5, oy + y, G2)
    put(img, ox + 4, oy + 2, G1)
    put(img, ox + 6, oy + 4, G2)
    # sea-grass (2,0)
    ox, oy = at(2, 0)
    for base, lean, h in ((1, -1, 5), (3, 1, 7), (5, 0, 4), (6, 1, 6)):
        for k in range(h):
            put(img, ox + base + round(lean * k / 4), oy + 7 - k, W if k < h - 1 else G1)
    # coral (3,0) 16x16: branching, thick at the base.
    ox, oy = at(3, 0)
    branches = [((8, 15), (8, 9)), ((8, 11), (4, 6)), ((8, 10), (12, 4)), ((4, 6), (3, 2)),
                ((4, 6), (7, 3)), ((12, 4), (11, 1)), ((12, 4), (14, 6)), ((8, 9), (9, 5))]
    for (x0, y0), (x1, y1) in branches:
        n = max(abs(x1 - x0), abs(y1 - y0))
        for k in range(n + 1):
            x = round(x0 + (x1 - x0) * k / n)
            y = round(y0 + (y1 - y0) * k / n)
            put(img, ox + x, oy + y, W)
            put(img, ox + x + 1, oy + y, G2)
    for x, y in ((3, 2), (7, 3), (11, 1), (14, 6), (9, 5)):
        put(img, ox + x, oy + y, G1)
    for x in range(6, 11):
        put(img, ox + x, oy + 15, W)
    # sea fan (5,0) 16x16: ribs radiating from a short stalk, a scalloped rim.
    ox, oy = at(5, 0)
    for k in range(7):
        a = math.radians(-62 + k * 124 / 6)
        for s in range(3, 13):
            x = 7.5 + math.sin(a) * s
            y = 14 - math.cos(a) * s
            put(img, ox + round(x), oy + round(y), W if s < 11 else G1)
    for k in range(40):
        a = math.radians(-64 + k * 128 / 39)
        r = 12.5 + (0.8 if k % 5 < 2 else 0)
        put(img, ox + round(7.5 + math.sin(a) * r), oy + round(14 - math.cos(a) * r), G1)
    for y in range(12, 16):
        put(img, ox + 7, oy + y, W)
        put(img, ox + 8, oy + y, G2)
    # rock (7,0) 16x8: a boulder, outlined, a crack.
    ox, oy = at(7, 0)
    for y in range(8):
        for x in range(16):
            dx, dy = (x - 7.5) / 7.8, (y - 8) / 6.5
            d = dx * dx + dy * dy
            if d <= 1.0:
                put(img, ox + x, oy + y, K)
            if 0.8 <= d <= 1.0:
                put(img, ox + x, oy + y, W)
    for x, y in ((6, 4), (7, 5), (7, 6), (10, 3)):
        put(img, ox + x, oy + y, G1)
    # shell (9,0): a scallop.
    ox, oy = at(9, 0)
    for y in range(3, 8):
        for x in range(1, 7):
            dx, dy = (x - 3.5) / 3.2, (y - 7.5) / 4.6
            if dx * dx + dy * dy <= 1.0:
                put(img, ox + x, oy + y, W if (x % 2 == 0 or y == 3) else G2)
    # desk (0,2) 24x16: top, two legs, a drawer, a monitor.
    ox, oy = at(0, 2)
    for x in range(1, 23):
        put(img, ox + x, oy + 8, W)
        put(img, ox + x, oy + 9, G1)
    for y in range(10, 16):
        put(img, ox + 2, oy + y, W)
        put(img, ox + 21, oy + y, W)
    for x in range(14, 21):
        for y in range(10, 14):
            put(img, ox + x, oy + y, W if y in (10, 13) or x in (14, 20) else K)
    put(img, ox + 17, oy + 11, G1)
    for x in range(4, 12):
        for y in range(1, 7):
            put(img, ox + x, oy + y, W if y in (1, 6) or x in (4, 11) else G2)
    put(img, ox + 7, oy + 7, W)
    put(img, ox + 8, oy + 7, W)
    # filing cabinet (3,2) 16x24: three drawers with handles.
    ox, oy = at(3, 2)
    for y in range(1, 24):
        for x in range(2, 14):
            edge = x in (2, 13) or y in (1, 23)
            put(img, ox + x, oy + y, W if edge else K)
    for d in range(3):
        y = 2 + d * 7
        for x in range(3, 13):
            put(img, ox + x, oy + y + 6, G1)
        for x in range(6, 10):
            put(img, ox + x, oy + y + 2, W)
    # partition (5,2) 8x24: a fabric panel on a frame.
    ox, oy = at(5, 2)
    for y in range(2, 24):
        put(img, ox + 1, oy + y, W)
        put(img, ox + 6, oy + y, W)
        for x in range(2, 6):
            put(img, ox + x, oy + y, G2 if (x + y) % 4 == 0 else K)
    for x in range(1, 7):
        put(img, ox + x, oy + 2, W)
    # chair (6,2) 16x16
    ox, oy = at(6, 2)
    for y in range(1, 8):
        put(img, ox + 5, oy + y, W)
        put(img, ox + 10, oy + y, W)
    for x in range(5, 11):
        put(img, ox + x, oy + 1, W)
        put(img, ox + x, oy + 8, W)
        put(img, ox + x, oy + 9, G1)
    for y in range(10, 14):
        put(img, ox + 8, oy + y, W)
    for x in (4, 6, 8, 10, 12):
        put(img, ox + x, oy + 15, W)
    for x in range(5, 12):
        put(img, ox + x, oy + 14, G1)
    # tube (8,2) 24x8: a fluorescent fixture hanging from two wires.
    ox, oy = at(8, 2)
    for y in range(0, 4):
        put(img, ox + 4, oy + y, G1)
        put(img, ox + 19, oy + y, G1)
    for x in range(1, 23):
        put(img, ox + x, oy + 4, W)
        put(img, ox + x, oy + 6, W)
        put(img, ox + x, oy + 5, W if x % 5 else G1)
    put(img, ox + 1, oy + 5, W)
    put(img, ox + 22, oy + 5, W)
    # whale rib (0,5) 16x32: a long curved bone.
    ox, oy = at(0, 5)
    for k in range(32):
        t = k / 31
        x = 3 + math.sin(t * math.pi * 0.9) * 9
        put(img, ox + round(x), oy + 31 - k, W)
        put(img, ox + round(x) + 1, oy + 31 - k, G1)
    # whale skull (2,5) 32x24
    ox, oy = at(2, 5)
    for y in range(24):
        for x in range(32):
            dx, dy = (x - 14) / 14, (y - 15) / 9
            d = dx * dx + dy * dy
            if d <= 1.0 and y > 5:
                put(img, ox + x, oy + y, K)
                if d >= 0.78:
                    put(img, ox + x, oy + y, W)
    for x in range(18, 31):
        y = 18 + round((x - 18) * 0.25)
        put(img, ox + x, oy + y, W)
        put(img, ox + x, oy + y - 4 + round((x - 18) * 0.1), W)
    for x, y in ((9, 12), (10, 12), (9, 13), (10, 13)):
        put(img, ox + x, oy + y, G1)
    for x in range(4, 20, 3):
        put(img, ox + x, oy + 21, G1)
    # anchor (6,5) 16x24
    ox, oy = at(6, 5)
    for y in range(3, 21):
        put(img, ox + 7, oy + y, W)
        put(img, ox + 8, oy + y, G1)
    for x in range(4, 12):
        put(img, ox + x, oy + 6, W)
    for k in range(-6, 7):
        put(img, ox + 7 + k, oy + 21 - round(abs(k) * 0.6), W)
    for x, y in ((6, 1), (7, 0), (8, 0), (9, 1), (6, 2), (9, 2)):
        put(img, ox + x, oy + y, W)
    # lantern (8,5) 8x16: a glowing bulb on a stalk (the reef's own lights).
    ox, oy = at(8, 5)
    for y in range(9, 16):
        put(img, ox + 4, oy + y, G1)
    for y in range(2, 9):
        for x in range(1, 8):
            dx, dy = (x - 4) / 3.2, (y - 5.5) / 3.5
            d = dx * dx + dy * dy
            if d <= 1.0:
                put(img, ox + x, oy + y, W if d < 0.45 else G1)
    # pier post (9,5) 8x24: a weathered piling, rope wrap.
    ox, oy = at(9, 5)
    for y in range(24):
        for x in range(2, 6):
            edge = x in (2, 5)
            put(img, ox + x, oy + y, W if edge else (G2 if (y * 3 + x) % 7 == 0 else K))
    for y in (6, 8):
        for x in range(1, 7):
            put(img, ox + x, oy + y, G1)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    jellyfish().save(OUT / 'jellyfish.png')
    air_bubble().save(OUT / 'air_bubble.png')
    memories().save(OUT / 'memories.png')
    decor().save(OUT / 'decor.png')
    for name in ('jellyfish', 'air_bubble', 'memories', 'decor'):
        im = Image.open(OUT / f'{name}.png')
        im.resize((im.width * 6, im.height * 6), Image.NEAREST).save(
            Path('/private/tmp/claude-501/-Users-ari--claude-spares-spare-sC4Tp7/ddddc3e1-397e-4e1b-afcc-69bde08d6833/scratchpad') / f'{name}_x6.png')
    print('wrote', ', '.join(p.name for p in sorted(OUT.glob('*.png'))))


if __name__ == '__main__':
    main()
