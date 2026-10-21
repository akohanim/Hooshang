"""The hub's old TV + console, and the sprite sheet for the game inside it.

Two deliberately different art languages in one file:

* `assets/props/retro_tv/tv.png` — the PROP in the prison hub: a boxy CRT on
  a wooden stand with rabbit-ear antennae, and a chunky grey console with its
  controller on the floor beside it. Drawn in the hub's own register (soft
  shading, warm wood, Act 2 palette) like any other prop.
* `assets/props/retro_tv/pc.png` — the hub's SECOND machine: a beige 90s PC on
  a desk over a Persian rug, which runs SIMORGH (scenes/minigame/simorgh_game.gd;
  that game draws everything in a shader, so it has no sheet here).
* `assets/minigame/retro_sheet.png` — the GAME on that TV, "HOOSHANG 64". This
  one is intentionally flat, limited-palette retro, the exception the art
  direction's "not 8-bit" rule makes room for: it is a game-within-the-game,
  and the whole point is that it looks like the old console it runs on. All
  original art — a little Hooshang, dust-bunny enemies, star blocks — nothing
  taken from any real game.

    python3 tools/gen_retro_tv.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def tv_prop():
    W, H = 76, 60
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    outline = (34, 26, 30, 255)
    # rabbit ears
    d.line((22, 12, 14, 1), fill=(150, 150, 158, 255))
    d.line((26, 12, 33, 0), fill=(150, 150, 158, 255))
    d.point((14, 1), fill=(210, 210, 220, 255)); d.point((33, 0), fill=(210, 210, 220, 255))
    d.ellipse((19, 10, 29, 15), fill=(60, 56, 62, 255), outline=outline)
    # cabinet / stand (wood)
    d.rectangle((2, 46, 50, 59), fill=(120, 74, 46, 255), outline=outline)
    d.rectangle((3, 47, 49, 48), fill=(166, 108, 66, 255))
    d.rectangle((6, 51, 25, 57), fill=(98, 58, 36, 255), outline=(70, 42, 28, 255))
    d.rectangle((27, 51, 46, 57), fill=(98, 58, 36, 255), outline=(70, 42, 28, 255))
    d.point((24, 54), fill=(214, 180, 96, 255)); d.point((28, 54), fill=(214, 180, 96, 255))
    # CRT box
    d.rectangle((4, 13, 48, 46), fill=(92, 84, 78, 255), outline=outline)
    d.rectangle((5, 14, 47, 15), fill=(132, 122, 112, 255))
    d.rectangle((5, 44, 47, 45), fill=(66, 60, 58, 255))
    # bezel + screen well (the live screen is drawn by retro_tv.gd at 8,17 32x24)
    d.rectangle((6, 15, 41, 43), fill=(40, 36, 40, 255), outline=(26, 22, 26, 255))
    d.rectangle((8, 17, 39, 40), fill=(12, 14, 18, 255))
    # side panel: knobs + speaker grille
    d.ellipse((42, 18, 46, 22), fill=(170, 160, 150, 255), outline=outline)
    d.ellipse((42, 25, 46, 29), fill=(170, 160, 150, 255), outline=outline)
    for y in range(32, 43, 2):
        d.line((42, y, 46, y), fill=(52, 46, 46, 255))
    d.point((44, 20), fill=outline); d.point((44, 27), fill=outline)
    # console on the floor beside the stand
    d.rectangle((54, 51, 73, 59), fill=(120, 120, 128, 255), outline=outline)
    d.rectangle((55, 52, 72, 53), fill=(168, 168, 176, 255))
    d.rectangle((57, 55, 64, 57), fill=(70, 70, 78, 255))      # cartridge slot
    d.rectangle((58, 49, 63, 54), fill=(150, 64, 56, 255), outline=outline)  # cartridge
    d.point((70, 55), fill=(220, 60, 50, 255))                  # power light
    d.rectangle((67, 55, 68, 57), fill=(90, 90, 98, 255))
    # cable to the TV
    d.line((54, 56, 50, 56), fill=(30, 30, 34, 255))
    out = ROOT / 'assets/props/retro_tv/tv.png'
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out


def pc_prop():
    """The second machine in the hub: a beige 90s PC on a wooden desk, a glass
    of tea beside it, a Persian rug underneath. It runs SIMORGH; the live
    screen is drawn by retro_tv.gd at (10, 8) 32x24, like the TV's."""
    W, H = 72, 58
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    outline = (34, 26, 30, 255)
    beige, light, dark = (200, 190, 164, 255), (226, 218, 194, 255), (150, 140, 118, 255)
    # rug: navy border, crimson field, gold and ivory motifs, fringe at the ends
    d.rectangle((0, 54, 71, 57), fill=(140, 28, 36, 255))
    d.line((0, 54, 71, 54), fill=(28, 34, 84, 255)); d.line((0, 57, 71, 57), fill=(28, 34, 84, 255))
    for x in range(3, 70, 4):
        d.point((x, 55), fill=(236, 186, 80, 255)); d.point((x + 2, 56), fill=(240, 228, 196, 255))
    for y in range(54, 58):
        d.point((0, y), fill=(240, 228, 196, 255)); d.point((71, y), fill=(240, 228, 196, 255))
    # desk
    d.rectangle((2, 39, 57, 41), fill=(120, 74, 46, 255), outline=outline)
    d.line((3, 40, 56, 40), fill=(166, 108, 66, 255))
    d.rectangle((3, 42, 56, 44), fill=(98, 58, 36, 255), outline=(70, 42, 28, 255))
    d.rectangle((20, 42, 38, 44), fill=(110, 66, 40, 255), outline=(70, 42, 28, 255))
    d.point((29, 43), fill=(214, 180, 96, 255))
    d.rectangle((4, 45, 6, 53), fill=(98, 58, 36, 255), outline=outline)
    d.rectangle((53, 45, 55, 53), fill=(98, 58, 36, 255), outline=outline)
    # monitor
    d.rectangle((19, 36, 32, 38), fill=dark, outline=outline)
    d.rectangle((5, 2, 46, 35), fill=beige, outline=outline)
    d.line((6, 3, 45, 3), fill=light); d.line((6, 3, 6, 34), fill=light)
    d.line((6, 34, 45, 34), fill=dark); d.line((45, 4, 45, 34), fill=dark)
    d.rectangle((9, 7, 42, 32), fill=(70, 66, 60, 255), outline=dark)
    d.rectangle((10, 8, 41, 31), fill=(12, 14, 18, 255))
    for i, col in enumerate(((220, 60, 50), (240, 180, 50), (60, 170, 90), (60, 110, 210))):
        d.point((12 + i, 33), fill=col + (255,))
    d.rectangle((38, 33, 39, 33), fill=dark)
    d.point((41, 33), fill=(90, 230, 110, 255))
    # tea: an estekan on its saucer
    d.line((47, 38, 54, 38), fill=(214, 170, 80, 255))
    d.rectangle((49, 33, 52, 37), fill=(176, 70, 30, 255))
    d.line((49, 33, 52, 33), fill=(236, 200, 120, 255))
    d.point((50, 35), fill=(220, 120, 60, 255))
    # tower on the rug
    d.rectangle((59, 22, 70, 53), fill=beige, outline=outline)
    d.line((60, 23, 69, 23), fill=light); d.line((60, 23, 60, 52), fill=light)
    d.line((61, 27, 68, 27), fill=outline)
    d.rectangle((61, 30, 68, 32), fill=dark)
    d.line((62, 31, 67, 31), fill=outline)
    d.ellipse((63, 43, 66, 46), fill=dark, outline=outline)
    d.point((68, 49), fill=(90, 230, 110, 255)); d.point((66, 49), fill=(240, 160, 50, 255))
    # cable from the tower up to the monitor
    d.line((58, 38, 58, 30), fill=(30, 30, 34, 255)); d.line((58, 30, 47, 30), fill=(30, 30, 34, 255))
    out = ROOT / 'assets/props/retro_tv/pc.png'
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out


# --- the game's sheet: 8px tiles on row 0, sprites below -------------------

SKY = (96, 152, 248)
P = {
    'k': (24, 20, 28), 'w': (252, 252, 248), 'skin': (248, 196, 148), 'hair': (40, 32, 36),
    'red': (216, 48, 40), 'redd': (152, 28, 28), 'blue': (40, 88, 200), 'blued': (24, 52, 136),
    'brown': (176, 96, 40), 'brownd': (112, 56, 24), 'tan': (240, 176, 96), 'gold': (252, 200, 56),
    'goldd': (200, 128, 24), 'teal': (48, 168, 152), 'teald': (24, 104, 96), 'tealh': (136, 224, 200),
    'grey': (160, 152, 168), 'greyd': (96, 88, 108), 'pink': (248, 152, 168),
}


def px(d, x, y, rows, colors):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != '.':
                d.point((x + i, y + j), fill=colors[ch] + (255,))


def sheet():
    im = Image.new('RGBA', (128, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = {k: v for k, v in P.items()}
    # 0 ground top, 1 ground fill
    d.rectangle((0, 0, 7, 7), fill=c['brown'] + (255,)); d.rectangle((0, 0, 7, 1), fill=c['tan'] + (255,))
    d.point((2, 4), fill=c['brownd'] + (255,)); d.point((6, 6), fill=c['brownd'] + (255,)); d.point((5, 3), fill=c['tan'] + (255,))
    d.rectangle((8, 0, 15, 7), fill=c['brown'] + (255,))
    for x, y in ((9, 2), (13, 5), (11, 6), (14, 1)): d.point((x, y), fill=c['brownd'] + (255,))
    # 2 brick
    d.rectangle((16, 0, 23, 7), fill=c['red'] + (255,))
    mortar = c['redd'] + (255,)
    for y in (3, 7): d.line((16, y, 23, y), fill=mortar)
    d.line((20, 0, 20, 3), fill=mortar); d.line((17, 4, 17, 7), fill=mortar)
    d.line((16, 0, 23, 0), fill=(240, 120, 96, 255))
    # 3,4 star block (two shimmer frames), 5 used block
    for i, glint in ((3, c['w']), (4, c['tan'])):
        x0 = i * 8
        d.rectangle((x0, 0, x0 + 7, 7), fill=c['gold'] + (255,), outline=c['goldd'] + (255,))
        px(d, x0 + 1, 1, ['..k...', '..k...', 'kkkkk.', '.kkk..', '.k.k..'], {'k': c['brownd']})
        d.point((x0 + 1, 1), fill=glint + (255,))
    d.rectangle((40, 0, 47, 7), fill=c['brownd'] + (255,), outline=c['k'] + (255,))
    d.point((41, 1), fill=c['brown'] + (255,)); d.point((46, 6), fill=c['brown'] + (255,))
    # 6,7,8 coin spin
    px(d, 49, 0, ['..yy..', '.yyyy.', 'yyywyy', 'yyywyy', 'yyywyy', 'yyyyyy', '.yyyy.', '..yy..'], {'y': c['gold'], 'w': c['w']})
    px(d, 58, 0, ['.yy.', 'yyyy', 'yywy', 'yywy', 'yywy', 'yyyy', 'yyyy', '.yy.'], {'y': c['gold'], 'w': c['w']})
    px(d, 67, 0, ['yy', 'yy', 'yy', 'yw', 'yy', 'yy', 'yy', 'yy'], {'y': c['goldd'], 'w': c['gold']})
    # 9,10 chimney top L/R, 11,12 chimney body L/R
    for i, top in ((9, True), (10, True), (11, False), (12, False)):
        x0 = i * 8
        d.rectangle((x0, 0, x0 + 7, 7), fill=c['teal'] + (255,))
        if i in (9, 11): d.line((x0, 0, x0, 7), fill=c['k'] + (255,)); d.line((x0 + 2, 0, x0 + 2, 7), fill=c['tealh'] + (255,))
        if i in (10, 12): d.line((x0 + 7, 0, x0 + 7, 7), fill=c['k'] + (255,)); d.line((x0 + 5, 0, x0 + 6, 7), fill=c['teald'] + (255,))
        if top:
            d.line((x0, 0, x0 + 7, 0), fill=c['k'] + (255,)); d.line((x0, 1, x0 + 7, 1), fill=c['tealh'] + (255,))
            d.line((x0, 6, x0 + 7, 6), fill=c['teald'] + (255,)); d.line((x0, 7, x0 + 7, 7), fill=c['k'] + (255,))
    # 13 hard block (stairs)
    d.rectangle((104, 0, 111, 7), fill=c['brownd'] + (255,), outline=c['k'] + (255,))
    d.line((105, 1, 110, 1), fill=c['tan'] + (255,)); d.line((105, 1, 105, 6), fill=c['tan'] + (255,))

    # Little Hooshang, 12x16, row y=16: idle, run1, run2, jump, dead, win
    body = {'h': c['hair'], 's': c['skin'], 'r': c['red'], 'R': c['redd'], 'b': c['blue'], 'B': c['blued'], 'k': c['k'], 'w': c['w']}
    head = ['...hhhhh....', '..hhhhhhh...', '..hhsssshh..', '..hsskskh...', '..ssssssss..', '...ssskks...', '....ssss....']
    frames = {
        'idle': head + ['...rrrrrr...', '..rrrRrrrr..', '..srrrrrrs..', '..s.rrrr.s..', '....bbbb....', '...bb..bb...', '...bb..bb...', '..kkk..kkk..'],
        'run1': head + ['...rrrrrr...', '..rrrRrrrrs.', '.srrrrrrr...', '....rrrr....', '...bbbbbb...', '..bb....bb..', '.kk......bb.', '.k.......kk.'],
        'run2': head + ['...rrrrrr...', '..rrrRrrrr..', '..srrrrrrs..', '....rrrr....', '....bbbb....', '....bbbb....', '....bkkb....', '....kk.kk...'],
        'jump': ['..s....hhhhh', '..s...hhhhhhh'[:12], '..s..hhsssshh'[:12], '..s.hsskskh.', '..rrssssssss'[:12], '..rrrssskks.', '..rrrrssss..',
                 '..rrrrrrr...', '..rrrRrrrr..', '...rrrrrrs..', '...rrrr..s..', '...bbbbbb...', '..bb...bb...', '.kk.....bb..', '.k......kk..', '............'],
        'dead': ['....hhhh....', '..hhhhhhhh..', '..hssssssh..', '..skksskks..', '..ssssssss..', '...sskkss...', '....ssss....',
                 's..rrrrrr..s', 'srrrrRrrrrrs', '...rrrrrr...', '....rrrr....', '....bbbb....', '...bb..bb...', '...bb..bb...', '..kkk..kkk..', '............'],
        'win': ['s..hhhhh...s', 's.hhhhhhh..s', 's.hhsssshh.s', 's.hsskskh..s', 'rrssssssssrr', 'rr.ssskks.rr', '.rr.ssss.rr.',
                '..rrrrrrrr..', '..rrrRrrrr..', '...rrrrrr...', '....rrrr....', '....bbbb....', '...bb..bb...', '...bb..bb...', '..kkk..kkk..', '............'],
    }
    for i, name in enumerate(['idle', 'run1', 'run2', 'jump', 'dead', 'win']):
        px(d, i * 12, 16, frames[name], body)
    # Dust bunny enemy, 12x12, row y=32: walk1, walk2, squashed
    bun = {'g': c['grey'], 'G': c['greyd'], 'w': c['w'], 'k': c['k'], 'p': c['pink']}
    walk1 = ['....g..g....', '...gg.gg....', '..gggggggg..', '.gggggggggg.', 'ggwkggggwkgg', 'ggwkggggwkgg', 'gggggggggggg', 'ggggpppggggg',
             '.gggggggggg.', '..GGGGGGGG..', '.GG......GG.', 'kk........kk']
    walk2 = ['....g..g....', '....gg.gg...', '..gggggggg..', '.gggggggggg.', 'ggwkggggwkgg', 'ggwkggggwkgg', 'gggggggggggg', 'ggggpppggggg',
             '.gggggggggg.', '..GGGGGGGG..', '...GG..GG...', '...kk..kk...']
    flat = ['............'] * 8 + ['.gggggggggg.', 'ggxggggggxgg', 'gggggggggggg', 'GGGGGGGGGGGG']
    px(d, 0, 32, walk1, bun); px(d, 12, 32, walk2, bun); px(d, 24, 32, flat, {**bun, 'x': c['k']})
    out = ROOT / 'assets/minigame/retro_sheet.png'
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return out


if __name__ == '__main__':
    for path in (tv_prop(), pc_prop(), sheet()):
        print('Wrote', path.relative_to(ROOT))
