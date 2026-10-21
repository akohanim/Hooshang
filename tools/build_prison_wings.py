"""Build the prison hub and its four key wings (v3: precision chains).

The rooms are DRAWN here, in code, and this script writes them into
`ldtk/hooshang_act2.ldtk`: the semantic `Collision` IntGrid, both auto-layers
that render it (`Tiles` for one-way/hazard/water, `PrisonMasonry` for solid),
and every entity. Run it again after changing a room; it rebuilds all 17
prison levels from scratch and touches nothing else in the project.

    python3 tools/build_prison_wings.py           # write the .ldtk
    python3 tools/build_prison_wings.py --doc     # also rewrite docs/prison_wings_v3.md

`docs/prison_wings_v3.md` is GENERATED from the same room data (ASCII map +
intended move chain per room), so the plan cannot drift from what is built.

Design numbers (child Hooshang, `tests/act2_feel_measure.tscn` + a wall-jump
sweep, all in px; a cell is 8):
  running jump   apex 40, reach 70      -> 4 rows up / 7-col gap comfortable
  jump + dash    reach 84-104           -> 10-col gap comfortable, 11-12 tight
  jump + up-dash rise 60-75             -> 7 rows comfortable
  ground dash    47
  spring         rise 71, +up-dash 108  -> 8 rows / 13 rows
  wall-jump      zigzag climbs a two-wall shaft 3-9 cols wide, ~3 rows a kick;
                 he cannot climb a single wall
  water          dash straight out of the water (prison only, prison_world.gd):
                 an up-dash lifts the feet ~45 above the surface, a diagonal
                 ~27 up and ~30 across.
                 Prison water REFILLS the dash (prison_world.gd), as in Celeste.

Close LDtk and the Godot editor before running, then re-import the project.
"""
import json
import math
import random
import re
import sys
import uuid
from pathlib import Path

from fix_masonry_edges import matches
from ldtk_add_ceiling_tile import array_end, ldtk_running, object_span

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'ldtk/hooshang_act2.ldtk'
DOC = ROOT / 'docs/prison_wings_v3.md'
ROUTES = ROOT / 'resources/levels/prison_wings_routes.json'
NS = uuid.UUID('5b1f0c8e-4a51-4a7e-9d0f-3c0a2f6f7a11')
WIDE, TALL = 40, 24


# ----------------------------------------------------------------- drawing --

class Room:
    """One prison level as a character grid plus entity specs.

    Grid: '#' solid, '=' one-way, '~' water, '.' air. Entities are placed by
    cell and also stamped into `glyphs` so the generated doc can show them.
    """

    def __init__(self, name, wing, title, w=WIDE, h=TALL):
        self.name, self.wing, self.title = name, wing, title
        self.w, self.h = w, h
        self.g = [['#' if x in (0, w - 1) or y in (0, h - 1) else '.' for x in range(w)] for y in range(h)]
        self.ents = []
        self.glyphs = {}
        self.chain = []
        self.notes = []
        self.route = []

    # geometry
    def fill(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                assert 0 <= x < self.w and 0 <= y < self.h, (self.name, x, y)
                self.g[y][x] = ch

    def solid(self, x0, y0, x1=None, y1=None):
        self.fill(x0, y0, x0 if x1 is None else x1, y0 if y1 is None else y1, '#')

    def clear(self, x0, y0, x1, y1):
        self.fill(x0, y0, x1, y1, '.')

    def oneway(self, x0, y, x1):
        self.fill(x0, y, x1, y, '=')

    def scaffold(self, x0, y0, x1=None, y1=None):
        """Act 2's turquoise/brass scaffolding: solid like masonry (physics is
        the prison's own Collision grid) but drawn from the Collisions layer's
        'scaffolding' brush. The general-purpose platform material."""
        self.fill(x0, y0, x0 if x1 is None else x1, y0 if y1 is None else y1, 's')

    def step(self, frm, to, moves=('jump',), dash=(), **kw):
        """One leg of this room's proven route (tests/prison_wings_routes_test).
        `frm` is (cell x, floor row) he stands on; `to` is (cell x, floor row
        [, tol px]), or a dict: {'swim': x}, {'portal': room}, {'key': colour}."""
        def stand(p):
            return [p[0] * 8 + 4, p[1] * 8]
        spec = {'from': stand(frm), 'moves': list(moves), 'dash': list(dash)}
        if isinstance(to, dict):
            t = dict(to)
            if 'swim' in t:
                t = {'swim': True, 'x': t['swim'] * 8 + 4, 'tol': t.get('tol', 16)}
            spec['to'] = t
        else:
            spec['to'] = {'x': to[0] * 8 + 4, 'y': to[1] * 8, 'tol': to[2] if len(to) > 2 else 8}
        for key, value in kw.items():
            if key in ('steer', 'steer_first'): value = value * 8 + 4
            spec[key] = value
        self.route.append(spec)

    def water(self, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                assert self.g[y][x] != '#', (self.name, 'water in wall', x, y)
                self.g[y][x] = '~'

    def opening(self, side, a, b):
        """Carve a border aperture. Portals form where two rooms' apertures meet."""
        for i in range(a, b + 1):
            if side == 'T': self.g[0][i] = '.'
            if side == 'B': self.g[self.h - 1][i] = '.'
            if side == 'L': self.g[i][0] = '.'
            if side == 'R': self.g[i][self.w - 1] = '.'

    def at(self, x, y):
        c = self.g[y][x] if 0 <= x < self.w and 0 <= y < self.h else '#'
        return '#' if c == 's' else c

    # entities
    def ent(self, ident, px, size, fields=None, cells=(), glyph='?', key=None):
        spec = dict(ident=ident, px=[float(px[0]), float(px[1])], size=list(size), fields=fields or {},
                    key=key or f'{ident}:{len(self.ents)}')
        self.ents.append(spec)
        for cell in cells: self.glyphs[cell] = glyph
        return spec

    def spikes(self, facing, x0, y0, n):
        """ConeSpikes strip of n cells. 'up' sits on a floor, 'down' hangs
        from a ceiling, 'right' grows out of a wall on its LEFT, 'left' out
        of a wall on its right."""
        horizontal = facing in ('up', 'down')
        cells = [(x0 + i, y0) if horizontal else (x0, y0 + i) for i in range(n)]
        for x, y in cells:
            assert self.at(x, y) == '.', (self.name, 'spike in', x, y, self.at(x, y))
            support = {'up': (x, y + 1), 'down': (x, y - 1), 'right': (x - 1, y), 'left': (x + 1, y)}[facing]
            assert self.at(*support) == '#', (self.name, 'unsupported spike', facing, x, y)
        ident = {'up': 'ConeSpikes', 'down': 'ConeSpikesCeiling', 'right': 'ConeSpikesLeftWall', 'left': 'ConeSpikesRightWall'}[facing]
        if horizontal:
            px, size = ((x0 + n / 2) * 8, y0 * 8 + 4), (n * 8, 8)
        else:
            px, size = (x0 * 8 + 4, (y0 + n / 2) * 8), (8, n * 8)
        self.ent(ident, px, size, {'ChildhoodPalette': 1.0}, cells, {'up': '^', 'down': 'v', 'right': '>', 'left': '<'}[facing])

    def spring(self, x, y, facing='Up'):
        """A 16x8 spring in cells (x, y)-(x+1, y), standing on the floor below.
        A side spring is the same pad turned on its edge: it occupies
        (x, y)-(x, y+1) against a wall."""
        if facing == 'Up':
            assert self.at(x, y + 1) == '#' and self.at(x + 1, y + 1) == '#', (self.name, 'spring needs floor', x, y)
            cells, px = [(x, y), (x + 1, y)], ((x + 1) * 8, y * 8 + 4)
            glyph = 'S'
        else:
            cells, px = [(x, y), (x, y + 1)], (x * 8 + 4, (y + 1) * 8)
            glyph = '}' if facing == 'Right' else '{'
        for cx, cy in cells: assert self.at(cx, cy) == '.', (self.name, 'spring cell', cx, cy)
        self.ent('SpringPlatform', px, (16, 8), {'Facing': facing}, cells, glyph)

    def crumble(self, x0, y, n, ident='CrumblingPlatform', gate=None):
        cells = [(x0 + i, y) for i in range(n)]
        for cx, cy in cells: assert self.at(cx, cy) in '.~', (self.name, 'crumble cell', cx, cy)
        fields = {'Gate': gate} if gate else {}
        self.ent(ident, ((x0 + n / 2) * 8, y * 8 + 4), (n * 8, 8), fields, cells, 'c' if ident != 'SwimCrumblingPlatform' else 'w')

    def lemon(self, x, y):
        self.ent('Lemon', (x * 8 + 4, y * 8 + 4), (16, 16), {}, [(x, y)], 'o')

    def standing(self, x, floor_row):
        """Player-centre height standing on top of row `floor_row`."""
        return (x * 8 + 4, floor_row * 8 - 6)

    def spawn(self, x, floor_row):
        assert self.at(x, floor_row) in '#=', (self.name, 'spawn not on floor', x, floor_row)
        self.ent('PlayerSpawn', (x * 8 + 4, floor_row * 8 - 8), (8, 16), {}, [], 'P')
        self.glyphs[(x, floor_row - 1)] = 'P'

    def checkpoint(self, x, floor_row):
        assert self.at(x, floor_row) in '#=', (self.name, 'checkpoint not on floor', x, floor_row)
        self.ent('Checkpoint', self.standing(x, floor_row), (16, 16), {}, [(x, floor_row - 1)], '@')

    def key(self, x, floor_row, colour):
        assert self.at(x, floor_row) == '#', (self.name, 'key not on floor', x, floor_row)
        return self.ent('Key', (x * 8 + 4, floor_row * 8 - 7), (10, 14), {'KeyID': '1', 'KeyId': colour},
                        [(x, floor_row - 1)], 'K', key='Key')

    def thought(self, x, y, motion='Vertical', amplitude=16.0, speed=1.0, phase=0.0):
        self.ent('DarkThought', (x * 8 + 4, y * 8 + 4), (16, 16),
                 {'Motion': motion, 'Amplitude': float(amplitude), 'Speed': float(speed), 'Phase': float(phase),
                  'ChildhoodPalette': 1.0}, [(x, y)], 'T')

    def sign(self, px, text):
        self.ent('PrisonSign', px, (8, 8), {'Text': text}, [], '')

    def ascii(self):
        rows = []
        for y in range(self.h):
            row = ''.join(self.glyphs.get((x, y), self.g[y][x]) for x in range(self.w))
            rows.append(f'{y:2d} {row}')
        ruler = '   ' + ''.join(str(x // 10) if x % 10 == 0 else ' ' for x in range(self.w))
        return '\n'.join([ruler] + rows)


def ref(name):
    """An entity reference resolved after every room exists: (room, key)."""
    return ('@ref', name)


# ------------------------------------------------------------------- rooms --
# Apertures are the existing portal pairs (unchanged world positions):
#   Hub L16-19 <-> R01, L40-43 <-> R04, T10-14 <-> G01, T50-54 <-> G04,
#   B10-14 <-> B04, B50-54 <-> B01, R16-19 <-> Y01, R40-43 <-> Y04.

ROOMS = {}


def room(name, wing, title):
    def deco(fn):
        r = Room(name, wing, title)
        fn(r)
        ROOMS[name] = r
        return fn
    return deco


# ---------------------------------------------------------------- GREEN ----
# The library: tall shelving. Wall-jump zigzags between book stacks and dashes
# between them. Every move is a CLIMB or a CROSSING; nothing times you.
# Thought periods below are frames for one full swing (60 * pi / speed).

def period(speed):
    return int(math.ceil(60 * math.pi / speed))


@room('Prison_G01', 'Green', 'Library stacks — the first climb')
def g01(r):
    r.opening('B', 10, 14); r.opening('T', 29, 33)
    r.solid(7, 10, 7, 20)               # shaft A's right wall (border is its left); walk in under it
    r.scaffold(7, 9, 13, 9)             # shelf at the top of shaft A
    r.scaffold(19, 9, 24, 9)            # ledge B across the gap
    r.solid(28, 1, 28, 9)               # exit shaft, left wall (short: slip under it)
    r.solid(34, 1, 38, 13)              # exit shaft, right wall + filler
    r.scaffold(29, 14, 33, 14)          # ledge C under the exit shaft
    r.spikes('up', 16, 22, 11)          # under the gap only
    r.spikes('down', 13, 1, 7)          # over the lemon
    r.lemon(16, 3)
    r.spawn(8, 23)
    r.chain = ['walk L under the wall into shaft A', 'wall-jump zigzag up (~4 kicks) onto the shelf',
               'running jump (or jump + dash) R to ledge B',
               'walk off B and slip under the exit shaft\'s short wall onto ledge C',
               'zigzag up the exit shaft and out the top']
    r.notes = ['Lemon: from the shelf, a short hop + dash UR under the ceiling spikes, then still make ledge B.']
    r.step((8, 23), (3, 23), ('walk',))
    r.step((3, 23), (9, 9), wall=True)
    r.step((11, 9), (21, 9), dash=('r',))
    r.step((21, 9), (31, 14), ('walk',))
    r.step((31, 14), {'portal': 'Prison_G02'}, wall=True, steer=29)


@room('Prison_G02', 'Green', 'Reading gallery — down, across, up and over')
def g02(r):
    r.opening('B', 29, 33); r.opening('R', 4, 7)
    r.solid(7, 12, 38, 13)              # the gallery floor dividing the room
    r.solid(7, 14, 7, 19)               # pillar: the shaft's right wall, open below
    r.scaffold(14, 20, 17, 20)          # book cart
    r.spikes('up', 11, 22, 3); r.spikes('up', 18, 22, 7)
    r.spikes('up', 12, 11, 21)          # gallery floor is spiked past its first few cells
    r.scaffold(12, 10, 16, 10)          # shelf A
    r.scaffold(24, 7, 26, 7)            # shelf B
    r.solid(31, 8, 38, 8)               # exit ledge
    r.lemon(21, 16)
    r.spawn(34, 23)
    r.chain = ['hop L over the entry hole', 'jump + dash L up onto the book cart',
               'jump L off the cart: bump the pillar and drop to its foot', 'walk L into the shaft',
               'zigzag up (~4 kicks) onto the gallery end', 'jump R onto shelf A',
               'jump + dash R onto shelf B', 'jump R onto the exit ledge']
    r.notes = ['Lemon: hangs over the lower hall between the cart and the landing.']
    r.step((34, 23), (26, 23))
    r.step((26, 23), (16, 20), dash=('l', 'ul'))
    r.step((15, 20), (8, 23, 12))
    r.step((8, 23), (3, 23), ('walk',))
    r.step((3, 23), (8, 12), wall=True)
    r.step((9, 12), (14, 10), dash=('r', 'ur'))
    r.step((15, 10), (25, 7), dash=('r', 'ur'))
    r.step((25, 7), (35, 8, 16), dash=('r',))
    r.step((35, 8), {'portal': 'Prison_G03'}, ('walk',), steer=40)


@room('Prison_G03', 'Green', 'Archive — over the stacks, down the chimney')
def g03(r):
    r.opening('L', 4, 7); r.opening('B', 29, 33)
    r.solid(1, 8, 5, 9)                 # entry ledge
    r.solid(9, 8, 10, 21)               # stack T1
    r.solid(15, 6, 16, 21)              # stack T2 (also the chimney's left wall)
    r.solid(22, 6, 22, 16)              # chimney right wall, above the window
    r.solid(22, 21, 22, 22)             # chimney right wall, below the window
    r.solid(22, 12, 38, 12)             # vault roof
    r.crumble(20, 10, 2)                # loose shelf S1
    r.scaffold(17, 15, 18, 15)          # shelf S2
    r.spikes('right', 17, 17, 5)        # left wall, below S2
    r.spikes('up', 1, 22, 8); r.spikes('up', 11, 22, 4); r.spikes('up', 17, 22, 5)
    r.spikes('up', 27, 22, 2)           # vault floor between the window and the key
    r.solid(25, 10, 26, 10)             # step on the roof (lemon detour home)
    r.lemon(34, 10)
    r.key(36, 23, 'Green')
    r.spawn(3, 8)
    r.chain = ['jump R onto stack T1', 'jump R over T2 and drop onto the loose shelf',
               'walk off it L onto shelf S2 before it falls', 'walk off S2 R and slide through the window',
               'jump + dash R over the vault spikes to the Green key', 'drop through the floor']
    r.notes = ['Lemon: from T1, jump + dash R over the chimney wall onto the vault roof; the step gets you home.']
    r.step((3, 8), (9, 8, 6))
    r.step((9, 8), (21, 10, 10), dash=('r', 'dr'))
    r.step((21, 10), (17, 15), ('walk',), steer=17, hurry=True)
    r.step((17, 15), (24, 23, 12), ('walk',), steer=24)
    r.step((25, 23), {'key': 'Green'}, dash=('r',), steer=36)
    r.step((36, 23), {'portal': 'Prison_G04'}, ('walk',), steer=31)


@room('Prison_G04', 'Green', 'Librarian\'s stair — shortcut home')
def g04(r):
    r.opening('T', 29, 33); r.opening('B', 10, 14)
    r.oneway(28, 4, 34)                 # the hatch landing: hop up THROUGH it on the way back
    for row, a in ((7, 21), (10, 14), (13, 21), (16, 14), (19, 21)):
        r.scaffold(a, row, a + 7, row)  # each step overlaps the one below by a cell
    r.scaffold(1, 12, 5, 12)
    r.lemon(3, 10)
    r.spawn(31, 4)
    r.chain = ['calm: step down the stair and through the floor to the hub']
    r.step((31, 4), (25, 7), ('walk',))
    r.step((23, 7), (18, 10), ('walk',))
    r.step((20, 10), (25, 13), ('walk',))
    r.step((23, 13), (18, 16), ('walk',))
    r.step((20, 16), (25, 19), ('walk',))
    r.step((23, 19), (16, 23), ('walk',))
    r.step((16, 23), {'portal': 'Prison_Hub'}, ('walk',), steer=12)


# ------------------------------------------------------------------ RED ----
# The cafeteria: RHYTHM. Crumbling trays that give way 0.6s after you land,
# thoughts that bob on fixed clocks, and a lever that opens a shutter for a
# few seconds. The route is never in doubt; WHEN to go is the whole puzzle.

@room('Prison_R01', 'Red', 'Serving line — crumbling trays')
def r01(r):
    r.opening('R', 16, 19); r.opening('L', 16, 19)
    r.solid(1, 1, 38, 8)                # low cafeteria ceiling
    r.solid(32, 20, 38, 22)             # start counter
    r.solid(1, 20, 6, 22)               # far counter
    r.spikes('up', 7, 22, 25)
    r.crumble(24, 18, 4)
    r.crumble(16, 17, 4)
    r.crumble(8, 18, 4)
    r.thought(13, 15, 'Vertical', 20, 0.9)
    r.lemon(22, 11)
    r.spawn(36, 20)
    r.chain = ['wait on the counter for the right moment', 'jump L onto tray 1 (it starts to crumble)',
               'jump L onto tray 2 without stopping', 'jump L past the bobbing thought onto tray 3',
               'jump L to the far counter']
    r.notes = ['Lemon: jump straight up from tray 2 for it, then drift onto tray 3 before tray 2 is gone.']
    r.step((36, 20), (26, 18, 12))
    r.step((26, 18), (18, 17, 12), hurry=True)
    r.step((18, 17), (10, 18, 12), wait=period(0.9), wait_at=0, hurry=True)
    r.step((10, 18), (3, 20, 12), hurry=True)
    r.step((3, 20), {'portal': 'Prison_R02'}, ('walk',), steer=-1)


@room('Prison_R02', 'Red', 'Kitchen shutter — beat the clock')
def r02(r):
    r.opening('R', 16, 19); r.opening('B', 9, 13)
    r.solid(1, 1, 38, 9)                # kitchen ceiling
    r.solid(31, 20, 38, 22)             # lever counter
    r.solid(16, 10, 16, 18)             # pantry wall above the shutter
    r.spikes('up', 21, 22, 10)          # the hot floor
    r.ent('TimedGate', (16 * 8 + 4, 20 * 8 + 8), (8, 32), {'PuzzleId': 'red_kitchen', 'Duration': 8.0},
          [(16, y) for y in range(19, 23)], 'G', key='Gate')
    r.ent('TimedLever', (34 * 8 + 4, 20 * 8 - 8), (16, 16), {'Gate': ref('Gate'), 'CanBank': True}, [(34, 19)], 'L')
    r.crumble(26, 17, 3, 'CrumblingShelf', ref('Gate'))
    r.scaffold(20, 14, 23, 14)          # shelf 2: solid, a place to watch the thought from
    r.thought(18, 17, 'Horizontal', 16, 0.6)
    r.ent('TimedRelay', (14 * 8 + 4, 23 * 8 - 8), (16, 16), {'Gate': ref('Gate')}, [(14, 22)], 'r')
    r.ent('TimedLever', (3 * 8 + 4, 23 * 8 - 8), (16, 16), {'Gate': ref('Gate'), 'CanBank': False}, [(3, 22)], 'L')
    r.lemon(25, 11)
    r.spawn(36, 20)
    r.chain = ['run into the lever: the shutter opens for 8s (and the loose shelf comes back)',
               'jump L onto the loose shelf', 'jump up-L onto the high shelf',
               'drop past the bobbing thought to the floor before the shutter',
               'run L through the open shutter and over the relay (banks it for good)',
               'drop through the pantry floor']
    r.notes = ['A second lever inside the pantry reopens the shutter from that side, so nobody is ever shut in.',
               'Lemon: up over the high shelf.']
    r.step((36, 20), (32, 20), ('walk',))
    r.step((32, 20), (27, 17), timer='red_kitchen')
    r.step((27, 17), (21, 14), timer='red_kitchen', hurry=True)
    r.step((21, 14), (18, 23, 12), ('walk', 'jump'), steer=18, wait=period(0.6), timer='red_kitchen')
    r.step((18, 23), {'portal': 'Prison_R03'}, ('walk',), steer=11, timer='red_kitchen')


@room('Prison_R03', 'Red', 'Dish pit — three shifts, one rhythm')
def r03(r):
    r.opening('T', 9, 13); r.opening('R', 16, 19)
    r.solid(7, 5, 15, 5)                # landing under the hatch
    r.solid(1, 9, 26, 9)                # D1: upper shift / middle shift
    r.spikes('up', 16, 8, 11)
    r.crumble(18, 6, 3)
    r.crumble(23, 6, 3)
    r.solid(12, 14, 38, 14)             # D2: middle shift / lower shift
    r.solid(32, 12, 38, 13)             # ledge R (checkpoint)
    r.spikes('up', 12, 13, 20)
    for i in range(10):
        r.crumble(12 + 2 * i, 12, 2)    # the crumbling dish rack
    # The thoughts only DIP into the rack corridor for a moment each swing.
    r.thought(25, 9, 'Vertical', 12, 0.7, 0.0)
    r.thought(18, 9, 'Vertical', 12, 0.7, 3.1)
    r.solid(2, 19, 8, 19)               # ledge M (checkpoint)
    r.spikes('up', 1, 22, 32)
    r.scaffold(13, 20, 16, 20)
    r.crumble(20, 20, 4)
    r.scaffold(27, 20, 30, 20)
    r.thought(32, 17, 'Horizontal', 8, 0.7)
    r.solid(33, 20, 38, 22)             # exit counter
    r.key(36, 20, 'Red')
    r.checkpoint(35, 12)
    r.checkpoint(4, 19)
    r.lemon(6, 3)
    r.spawn(11, 5)
    r.chain = ['jump R onto stone 1', 'jump R onto stone 2', 'drop R onto ledge R (checkpoint)',
               'watch the two thoughts dip, then RUN L along the crumbling rack without stopping',
               'drop L onto ledge M (checkpoint)', 'jump R onto the first cart',
               'jump R across the crumbling cart', 'jump R onto the last cart',
               'hop R past the sweeping thought onto the exit counter', 'take the Red key']
    r.notes = ['Lemon: up-left from the hatch landing, a jump into the corner before you start.']
    r.step((11, 5), (19, 6))
    r.step((19, 6), (24, 6), hurry=True)
    r.step((24, 6), (35, 12, 18), dash=('r',), hurry=True)
    r.step((35, 12), (6, 19, 14), ('walk',), wait=period(0.7), steer=6)
    r.step((7, 19), (14, 20, 10), dash=('r',))
    r.step((15, 20), (21, 20, 10), dash=('r',))
    r.step((22, 20), (28, 20, 10), dash=('r',), hurry=True)
    r.step((29, 20), {'key': 'Red'}, dash=('r',), wait=period(0.7), steer=36)
    r.step((36, 20), {'portal': 'Prison_R04'}, ('walk',), steer=40)


@room('Prison_R04', 'Red', 'Staff corridor — shortcut home')
def r04(r):
    r.opening('L', 16, 19); r.opening('R', 16, 19)
    r.solid(1, 1, 38, 11)
    r.solid(1, 20, 38, 22)
    r.scaffold(18, 17, 21, 17)
    r.lemon(19, 15)
    r.spawn(3, 20)
    r.chain = ['calm: walk R to the hub']
    r.step((3, 20), {'portal': 'Prison_Hub'}, ('walk',), steer=40)


# ----------------------------------------------------------------- BLUE ----
# The flooded basement. Water is SAFE and it REFILLS the dash: every pool is a
# reset point, and the moves are the jumps between them — kick out, dash,
# splash down, kick out again. Hazards live in the air, never in the water.

@room('Prison_B01', 'Blue', 'Boiler steps — the first splash')
def b01(r):
    r.opening('T', 10, 14); r.opening('B', 23, 27)
    r.solid(7, 5, 16, 6)                # landing under the hatch
    r.solid(18, 14, 18, 22)             # pool 1's right wall
    r.scaffold(18, 13, 20, 13)          # ledge on top of it
    r.water(1, 15, 17, 22)              # pool 1
    r.solid(21, 16, 21, 22); r.spikes('up', 21, 15, 1)
    r.solid(35, 16, 38, 22)
    r.water(22, 17, 34, 22)             # pool 2, drains through the floor
    r.lemon(10, 9)
    r.spawn(12, 5)
    r.chain = ['walk off the landing and splash into pool 1 (dash refilled)',
               'dash UR out of the water onto the ledge', 'jump R into pool 2 over its spiked rim',
               'dive down through the drain']
    r.notes = ['Lemon: straight up out of pool 1 — an up-dash from the water.']
    r.step((12, 5), {'swim': 8, 'tol': 40}, ('walk',), steer=4)
    r.step((14, 16), (19, 13, 10), ('float',), dash=('ur', 'u', 'r'), steer=19)
    r.step((19, 13), {'swim': 27, 'tol': 40}, dash=('r',))
    r.step((25, 18), {'portal': 'Prison_B02'}, ('dive',), steer=25)


@room('Prison_B02', 'Blue', 'Flooded corridor — under, up, over')
def b02(r):
    r.opening('T', 23, 27); r.opening('L', 16, 19)
    r.solid(21, 5, 29, 6)               # landing under the drain
    r.solid(31, 1, 38, 22)              # boiler block
    r.solid(20, 1, 20, 18)              # wall W2 — swim UNDER it
    r.solid(10, 15, 10, 22); r.spikes('up', 10, 14, 1)    # wall W3, flush with the water, spiked top
    r.solid(1, 1, 19, 7); r.spikes('down', 1, 8, 19)      # low ceiling over the west half
    r.water(1, 16, 9, 22); r.water(11, 15, 19, 22); r.water(20, 19, 20, 22); r.water(21, 15, 30, 22)
    r.water(0, 16, 0, 19)               # the doorway is flooded too
    r.thought(25, 18, 'Vertical', 12, 0.6)
    r.thought(14, 11, 'Horizontal', 20, 0.5)
    r.lemon(17, 11)
    r.spawn(25, 5)
    r.chain = ['drop into the east pool', 'dive past the underwater thought and swim W under wall W2',
               'surface; wait for the sweeping thought',
               'dash UL out of the water over the spiked top of wall W3',
               'swim W out through the flooded doorway']
    r.notes = ['Lemon: between the sweeping thought and the ceiling spikes in the middle pool.']
    r.step((25, 5), {'swim': 30, 'tol': 24}, ('walk',), steer=30)
    r.step((27, 17), {'swim': 15, 'tol': 24}, ('dive',), steer=15, wait=period(0.6))
    r.step((14, 16), {'swim': 5, 'tol': 32}, ('float',), dash=('ul', 'u'), steer=4, wait=period(0.5))
    r.step((5, 17), {'portal': 'Prison_B03'}, ('swim',), steer=-2)


@room('Prison_B03', 'Blue', 'Pump store — climb the cisterns')
def b03(r):
    r.opening('R', 16, 19); r.opening('T', 10, 14)
    r.solid(26, 11, 26, 22)             # cistern wall
    r.water(27, 15, 38, 22)             # entry cistern (the corridor floods in)
    r.water(39, 16, 39, 19)
    r.crumble(29, 13, 4, 'SwimCrumblingPlatform')
    r.solid(17, 12, 17, 14); r.solid(24, 12, 24, 14); r.solid(17, 15, 24, 15)
    r.water(18, 12, 23, 14)             # hanging cistern
    r.scaffold(11, 12, 14, 12)          # a solid step: wait here for the thought
    r.thought(9, 12, 'Vertical', 10, 0.9)
    r.solid(2, 9, 7, 10)                # ledge
    r.scaffold(9, 6, 15, 6)             # key landing under the hatch
    r.spikes('up', 1, 22, 25)
    r.key(15, 6, 'Blue')
    r.lemon(33, 3)
    r.spawn(36, 23)
    r.chain = ['dash out of the entry cistern onto the stone', 'jump + dash L into the hanging cistern (refill)',
               'dash UL out of the water onto the step', 'jump L past the bobbing thought onto the ledge',
               'jump + dash UR onto the key landing', 'take the Blue key, jump up through the hatch']
    r.notes = ['Lemon: high over the first stone — a full jump + up-dash from it.']
    r.step((34, 17), (31, 13, 14), ('float',), dash=('u', 'ul', 'l'), steer=31, steer_air=True)
    r.step((30, 13), {'swim': 20, 'tol': 20}, dash=('l',), hurry=True)
    r.step((21, 14), (13, 12, 10), ('float',), dash=('ul', 'l', 'u'), steer=13)
    r.step((12, 12), (4, 9, 12), dash=('l', 'ul'), wait=period(0.9))
    r.step((6, 9), (11, 6, 16), dash=('u', 'ur'), steer=11)
    r.step((11, 6), {'key': 'Blue'}, ('walk',), steer=16)
    r.step((14, 6), {'portal': 'Prison_B04'}, dash=('u', 'ul'), steer=12)


@room('Prison_B04', 'Blue', 'Service stair — shortcut home')
def b04(r):
    r.opening('B', 10, 14); r.opening('T', 10, 14)
    for row, a in ((20, 3), (17, 15), (14, 3), (11, 15), (8, 3)):
        r.scaffold(a, row, a + 4, row)
    r.oneway(8, 5, 15)                  # under the hatch: hop up THROUGH it from the step below
    r.scaffold(30, 14, 38, 14)
    r.lemon(34, 12)
    r.spawn(16, 23)
    r.chain = ['calm: hop up the stair, through the hatch landing and out to the hub']
    r.step((9, 23), (5, 20))
    r.step((7, 20), (16, 17))
    r.step((15, 17), (5, 14))
    r.step((7, 14), (16, 11))
    r.step((15, 11), (5, 8))
    r.step((5, 8), (11, 5, 12), steer=11)
    r.step((12, 5), {'portal': 'Prison_Hub'}, dash=('u',), steer=12)


# ----------------------------------------------------------------- GOLD ----
# The gym: the capstone. Springs and a pressure plate, then every verb from
# the other wings in one long chain — zigzags, crumbling, thoughts and water.

@room('Prison_Y01', 'Gold', 'Gym floor — springboards')
def y01(r):
    r.opening('L', 16, 19); r.opening('R', 16, 19)
    r.solid(1, 20, 6, 22)
    r.solid(8, 19, 11, 22); r.spring(9, 18)
    r.scaffold(15, 11, 19, 11)
    r.solid(26, 18, 29, 22); r.spring(27, 17)
    r.solid(31, 11, 31, 22); r.spikes('up', 31, 10, 1)
    r.solid(33, 20, 38, 22)
    r.spikes('up', 7, 22, 1); r.spikes('up', 12, 22, 14); r.spikes('up', 30, 22, 1); r.spikes('up', 32, 22, 1)
    r.lemon(10, 4)
    r.spawn(3, 20)
    r.chain = ['hop onto the springboard', 'steer R onto the high ledge',
               'jump R and drop onto the second springboard',
               'bounce and steer R over the spike-topped wall onto the far mat']
    r.notes = ['Lemon: springboard + up-dash straight up from the first spring.']
    r.step((3, 20), (17, 11, 16), steer_first=9.5)
    r.step((18, 11), (35, 20, 16), dash=('r',), steer_first=27.5)
    r.step((35, 20), {'portal': 'Prison_Y02'}, ('walk',), steer=40)


@room('Prison_Y02', 'Gold', 'Equipment hall — the plate and the shutter')
def y02(r):
    r.opening('L', 16, 19); r.opening('B', 29, 33)
    r.solid(1, 20, 8, 22)               # entry mat
    r.solid(9, 4, 9, 17)                # shaft left wall (walk in under it)
    r.solid(10, 21, 11, 22); r.spring(10, 20)
    r.solid(15, 7, 15, 22)              # shaft right wall
    r.scaffold(15, 6, 18, 6)            # T1
    r.crumble(22, 7, 3)
    r.thought(26, 4, 'Vertical', 16, 1.0)
    r.scaffold(29, 8, 34, 8)            # T2
    r.solid(30, 9, 34, 15)              # T2's base down to the pocket roof
    r.solid(21, 16, 34, 16)             # pocket roof
    r.solid(21, 17, 21, 22)             # pocket left wall
    r.solid(35, 9, 35, 16)              # chute wall
    r.ent('TimedGate', (35 * 8 + 4, 20 * 8), (8, 48), {'PuzzleId': 'gold_hall', 'Duration': 9.0},
          [(35, y) for y in range(17, 23)], 'G', key='Gate')
    r.ent('PressurePlate', (5 * 8 + 4, 20 * 8 - 3), (24, 8), {'Gate': ref('Gate')}, [(4, 19), (5, 19), (6, 19)], '_')
    r.ent('TimedRelay', (34 * 8 + 4, 23 * 8 - 8), (16, 16), {'Gate': ref('Gate')}, [(34, 22)], 'r')
    r.ent('TimedLever', (23 * 8 + 4, 23 * 8 - 8), (16, 16), {'Gate': ref('Gate'), 'CanBank': False}, [(23, 22)], 'L')
    r.spikes('up', 12, 22, 3); r.spikes('up', 16, 22, 5)
    r.spikes('up', 22, 15, 8)
    r.lemon(12, 2)
    r.spawn(2, 20)
    r.chain = ['stand on the plate: the shutter at the bottom right opens; step off and it holds 9s',
               'run R onto the springboard inside the shaft', 'zigzag up and land on T1',
               'jump R onto the crumbling bar', 'jump R past the bobbing thought onto T2',
               'walk off T2 over the chute wall and drop to the mat outside the shutter',
               'run L through the shutter over the relay (banks it), drop through the floor']
    r.notes = ['A lever inside the pocket reopens the shutter from that side.',
               'Lemon: top of the shaft — up-dash after the kicks, then still make T1 in time.']
    p = period(1.0)
    r.step((2, 20), (5, 20), ('walk',))
    r.step((5, 20), (16, 6, 12), ('walk', 'jump'), wall=True, timer='gold_hall')
    r.step((17, 6), (23, 7), timer='gold_hall')
    r.step((23, 7), (31, 8, 12), dash=('r',), wait=p, wait_at=2, timer='gold_hall', hurry=True)
    r.step((32, 8), (37, 23, 12), ('walk',), steer=37, timer='gold_hall')
    r.step((37, 23), {'portal': 'Prison_Y03'}, ('walk',), steer=31, timer='gold_hall')


@room('Prison_Y03', 'Gold', 'Trophy room — everything at once')
def y03(r):
    r.opening('T', 29, 33); r.opening('L', 16, 19)
    r.solid(27, 4, 38, 5)               # landing under the hatch (only its left edge drops)
    r.solid(22, 1, 22, 9)               # wall keeping the hatch landing apart
    r.solid(23, 14, 23, 22)             # pool wall
    r.water(24, 16, 38, 22)             # the plunge pool
    r.thought(25, 11, 'Horizontal', 16, 0.9)
    r.crumble(18, 15, 3)
    r.solid(14, 17, 15, 22); r.spring(14, 16)
    r.solid(11, 8, 11, 12)              # shaft left wall (low: one kick clears it)
    r.solid(17, 1, 17, 11)              # shaft right wall
    r.scaffold(6, 8, 10, 8)             # ledge L
    r.crumble(3, 12, 3)
    r.thought(4, 16, 'Horizontal', 16, 1.0)
    r.solid(1, 20, 6, 22)               # exit mat
    r.spikes('up', 7, 22, 7); r.spikes('up', 16, 22, 7)
    r.key(2, 20, 'Gold')
    r.lemon(19, 6)
    r.spawn(31, 4)
    r.chain = ['wait for the thought, then drop into the plunge pool (refill)',
               'dash UL out of the pool over its wall onto the crumbling bar',
               'step off L under the wall onto the springboard, bounce up the shaft',
               'one wall-jump off the right wall, over the left wall onto ledge L',
               'walk off L onto the crumbling bar', 'drop past the sweeping thought onto the exit mat',
               'take the Gold key']
    r.notes = ['Lemon: from the crumbling bar, jump + up-dash into the alcove — then the spring before the bar is gone.']
    r.step((31, 4), {'swim': 26, 'tol': 24}, ('walk',), steer=25, wait=period(0.9))
    r.step((27, 17), (19, 15, 10), ('float',), dash=('ul', 'l'), steer=19)
    r.step((19, 15), (8, 8, 14), ('walk', 'run'), wall=True, steer_first=14.5, hurry=True)
    r.step((7, 8), (4, 12, 10), ('walk',), steer=4)
    r.step((4, 12), {'key': 'Gold'}, ('walk',), steer=1, wait=period(1.0), wait_at=3, hurry=True)
    r.step((2, 20), {'portal': 'Prison_Y04'}, ('walk',), steer=-1)


@room('Prison_Y04', 'Gold', 'Locker room — shortcut home')
def y04(r):
    r.opening('R', 16, 19); r.opening('L', 16, 19)
    r.solid(1, 1, 38, 9)
    r.solid(1, 20, 38, 22)
    r.spring(19, 19)
    r.lemon(20, 12)
    r.spawn(36, 20)
    r.chain = ['calm: walk L to the hub (the springboard is for the lemon)']
    r.step((36, 20), {'portal': 'Prison_Hub'}, ('walk',), steer=-1)


# ------------------------------------------------------------------ HUB ----
# Scaffolding everywhere a platform is just a platform. The one hatch through
# the upper floor is an open gap (up AND down); one-ways are kept for the
# wing rooms' hatch landings, where hopping up through the floor is the point.

@room('Prison_Hub', 'Hub', 'Assembly hall — the cage and four wings')
def hub(r):
    r.w, r.h = 80, 48
    r.g = [['#' if x in (0, 79) or y in (0, 47) else '.' for x in range(80)] for y in range(48)]
    for side, a, b in (('T', 10, 14), ('T', 50, 54), ('B', 10, 14), ('B', 50, 54),
                       ('L', 16, 19), ('L', 40, 43), ('R', 16, 19), ('R', 40, 43)):
        r.opening(side, a, b)
    r.solid(1, 20, 35, 20); r.solid(43, 20, 78, 20)          # upper floor, central gap cols 36-42
    r.scaffold(1, 44, 8, 44); r.scaffold(71, 44, 78, 44)     # lower doorway ledges
    for row, a in ((44, 31), (41, 25), (38, 31), (35, 25), (32, 31), (29, 25), (26, 31)):
        r.scaffold(a, row, a + 4, row)                       # the central stair, 3 rows a step
    for row, a in ((44, 47), (41, 53), (38, 47), (35, 53), (32, 47), (29, 53), (26, 47)):
        r.scaffold(a, row, a + 4, row)                       # the east stair: the far side of the cage
    r.scaffold(37, 23, 45, 23)                               # under the gap; both stairs top out here
    r.scaffold(60, 32, 73, 32)                               # the TV stage: HOOSHANG 64 (PrisonWorld._add_minigames), a hop off the east stair
    r.scaffold(8, 32, 21, 32)                                # the PC stage: SIMORGH, a hop off the central stair
    for row, a in ((17, 10), (14, 4), (11, 10), (8, 4), (5, 10)):   # up to the library hatch
        r.scaffold(a, row, a + 4, row)
    for row, a in ((17, 50), (14, 44), (11, 50), (8, 44), (5, 50)):  # up to the librarian's stair
        r.scaffold(a, row, a + 4, row)
    r.ent('Cage', (336, 356), (64, 40), {'Lock1': 'Red', 'Lock2': 'Green', 'Lock3': 'Blue', 'Lock4': 'Gold'}, [], '', key='Cage')
    r.ent('Jamshid', (336, 376), (12, 16), {'DialogueLine': '(excited) Hooshang! Cousin joon!', 'TriggerRadius': 50.0, 'FaceLeft': 1.0}, [], '')
    r.spawn(18, 47)
    r.ent('CastlePassage', (40, 352), (32, 48), {'Destination': 'Act_2_Level_15'}, [], '')
    r.sign((320, 292), 'FREE JAMSHID  /  FOUR KEYS')
    r.sign((40, 118), '< RED  CAFETERIA')
    r.sign((600, 118), 'GOLD  GYM >')
    r.sign((96, 18), 'GREEN  LIBRARY  ^')
    r.sign((420, 366), 'BLUE  BASEMENT  v')
    r.chain = ['hub: the cage sits on the lower floor; a scaffold stair climbs to the gap in the upper floor',
               'the library hatch and the librarian\'s stair hatch are reached by scaffold steps above']


HUB_ROUTES = {}


def hub_route(name, steps):
    r = Room('Prison_Hub', 'Hub', '', 80, 48)
    for args, kw in steps:
        r.step(*args, **kw)
    HUB_ROUTES[name] = r.route


def S(*args, **kw):
    return (args, kw)


hub_route('Prison_Hub#R01', [
    S((18, 47), (29, 47), ('walk',)), S((29, 47), (33, 44)), S((33, 44), (27, 41)), S((27, 41), (33, 38)),
    S((33, 38), (27, 35)), S((27, 35), (33, 32)), S((33, 32), (27, 29)), S((27, 29), (33, 26)),
    S((34, 26), (39, 23)), S((38, 23), (34, 20, 10), dash=('ul', 'u'), steer=34),
    S((34, 20), {'portal': 'Prison_R01'}, ('walk',), steer=-1)])
hub_route('Prison_Hub#G01', [
    S((34, 20), (16, 20), ('walk',)), S((16, 20), (12, 17)), S((11, 17), (6, 14)),
    S((7, 14), (12, 11)), S((11, 11), (6, 8)), S((7, 8), (12, 5)),
    S((12, 5), {'portal': 'Prison_G01'}, steer=12)])
hub_route('Prison_Hub#B01', [
    S((18, 47), (29, 47), ('walk',)), S((29, 47), (33, 44)), S((33, 44), (27, 41)), S((27, 41), (33, 38)),
    S((34, 38), {'portal': 'Prison_B01'}, ('walk',), steer=52)])
hub_route('Prison_Hub#Y01', [
    S((40, 23), (44, 20, 10), dash=('ur', 'u'), steer=44), S((44, 20), {'portal': 'Prison_Y01'}, ('walk',), steer=81)])

# Every wing's way back into the hub must reach every other wing: no key order.
# Each return point climbs to the upper floor, the hub's crossroads (R01 and Y01
# doors, the library climb, and the gap down to both stairs and the B01 hole).
hub_route('Prison_Hub#fromR04', [
    S((4, 44), (18, 47, 12), ('jump', 'walk'), dash=('r',)), S((18, 47), (29, 47), ('walk',)), S((29, 47), (33, 44)),
    S((33, 44), (27, 41)), S((27, 41), (33, 38)), S((33, 38), (27, 35)), S((27, 35), (33, 32)),
    S((33, 32), (27, 29)), S((27, 29), (33, 26)), S((34, 26), (39, 23)),
    S((38, 23), (34, 20, 10), dash=('ul', 'u'), steer=34)])
hub_route('Prison_Hub#fromY04', [
    S((75, 44), (56, 47, 10), ('walk',), steer=56), S((56, 47), (49, 44)),
    S((49, 44), (55, 41)), S((55, 41), (49, 38)), S((49, 38), (55, 35)), S((55, 35), (49, 32)),
    S((49, 32), (55, 29)), S((55, 29), (49, 26)), S((48, 26), (43, 23)),
    S((40, 23), (44, 20, 10), dash=('ur', 'u'), steer=44)])
hub_route('Prison_Hub#fromG04', [
    S((52, 5), (46, 8), ('walk', 'jump')), S((47, 8), (52, 11)), S((52, 11), (46, 14)), S((47, 14), (52, 17)),
    S((52, 17), (57, 20, 10), ('walk',), steer=57), S((57, 20), {'portal': 'Prison_Y01'}, ('walk',), steer=81)])
hub_route('Prison_Hub#fromB04', [
    S((15, 47), (29, 47), ('walk',)), S((29, 47), (33, 44)), S((33, 44), (27, 41)), S((27, 41), (33, 38)),
    S((33, 38), (27, 35)), S((27, 35), (33, 32)), S((33, 32), (27, 29)), S((27, 29), (33, 26)),
    S((34, 26), (39, 23)), S((38, 23), (34, 20, 10), dash=('ul', 'u'), steer=34)])

ROUTE_ORDER = ['Prison_Hub#R01', 'Prison_R01', 'Prison_R02', 'Prison_R03', 'Prison_R04',
               'Prison_Hub#G01', 'Prison_G01', 'Prison_G02', 'Prison_G03', 'Prison_G04',
               'Prison_Hub#B01', 'Prison_B01', 'Prison_B02', 'Prison_B03', 'Prison_B04',
               'Prison_Hub#Y01', 'Prison_Y01', 'Prison_Y02', 'Prison_Y03', 'Prison_Y04',
               # each shortcut's way back into the hub
               'Prison_Hub#fromR04', 'Prison_Hub#fromY04', 'Prison_Hub#fromG04', 'Prison_Hub#fromB04']


# ------------------------------------------------------------- shortcuts ----
# Each wing's fourth room is a calm way home, OPEN from the start like every
# other passage: no ShortcutDoor is placed, so no portal is gated and the keys
# can be fetched in any order by any route. (The builder rewrites these
# levels' entities, so a rebuild also clears doors an older build placed.)


# ------------------------------------------------------------------ write ---

def iid_for(room_name, key):
    return str(uuid.uuid5(NS, f'{room_name}/{key}'))


def real_values(ftype, value):
    if value is None: return []
    if ftype == 'Float': return [{'id': 'V_Float', 'params': [value]}]
    if ftype == 'Bool': return [{'id': 'V_Bool', 'params': [value]}]
    if ftype == 'EntityRef': return [{'id': 'V_String', 'params': [value['entityIid']]}]
    return [{'id': 'V_String', 'params': [value]}]


def default_value(field):
    d = field.get('defaultOverride')
    if not d: return None
    v = d['params'][0]
    return float(v) if field['__type'] == 'Float' else v


def bake(layer_def, cells, w, h, tileset_cols, only_groups=None, seed=''):
    """LDtk's auto-layer pass, done here so the .ldtk ships with the tiles it
    would paint: rules in order, modulo phases, chance, a random variant per
    cell (seeded by room + cell so a rebuild is stable), breakOnMatch."""
    rules = [r for g in layer_def['autoRuleGroups'] if g['active']
             and (only_groups is None or g['name'].startswith(only_groups)) for r in g['rules'] if r['active']]
    tiles = []
    for index, value in enumerate(cells):
        if not value: continue
        x, y = index % w, index // w
        rng = random.Random(f'{seed}:{x}:{y}')
        for rule in rules:
            if rule['xModulo'] > 1 and (x - rule['xOffset']) % rule['xModulo'] != 0: continue
            if rule['yModulo'] > 1 and (y - rule['yOffset']) % rule['yModulo'] != 0: continue
            if not matches(rule, cells, w, h, x, y, {}): continue
            if rule['chance'] < 1 and rng.random() >= rule['chance']: continue
            t = rng.choice(rule['tileRectsIds'])[0]
            tiles.append({'px': [x * 8, y * 8], 'src': [t % tileset_cols * 8, t // tileset_cols * 8],
                          'f': 0, 't': t, 'd': [rule['uid'], index], 'a': 1})
            if rule['breakOnMatch']: break
    tiles.sort(key=lambda t: (t['px'][1], t['px'][0]))
    return tiles


def array_span(text, layer_iid, key):
    start, end = object_span(text, text.index('"iid": "' + layer_iid + '"'))
    opening = text.index('[', text.index('"' + key + '":', start, end))
    return opening, array_end(text, opening) + 1


def formatted(items):
    if not items: return '[]'
    return '[\n' + ',\n'.join('\t' * 6 + json.dumps(item, separators=(',', ':')) for item in items) + '\n' + '\t' * 5 + ']'


def build():
    assert not ldtk_running(), 'Close LDtk before rebuilding the prison'
    text = PATH.read_text()
    project = json.loads(text)
    defs = {d['identifier']: d for d in project['defs']['entities']}
    layer_defs = {d['identifier']: d for d in project['defs']['layers']}
    tilesets = {t['uid']: t for t in project['defs']['tilesets']}
    levels = {l['identifier']: l for l in project['levels']}
    world_iid = project.get('dummyWorldIid') or project['iid']
    code = {'.': 0, '#': 1, 's': 1, '=': 2, '~': 4}

    replacements = []
    for name, r in ROOMS.items():
        level = levels[name]
        assert (level['pxWid'], level['pxHei']) == (r.w * 8, r.h * 8), name
        layers = {li['__identifier']: li for li in level['layerInstances']}
        coll = layers['Collision']
        cells = [code[r.g[y][x]] for y in range(r.h) for x in range(r.w)]
        coll['intGridCsv'] = cells
        start, end = array_span(text, coll['iid'], 'intGridCsv')
        cursor = iter(cells)
        new_array = re.sub(r'(?<!\d)\d+(?!\d)', lambda _m: str(next(cursor)), text[start:end])
        replacements.append((start, end, new_array))
        # Masonry is never drawn under scaffolding; scaffolding is the Act 2
        # Collisions brush (value 5), visual only — the prison's own grid above
        # carries its collision.
        masonry_cells = [0 if r.g[y][x] == 's' else c for (y, x), c in
                         zip(((y, x) for y in range(r.h) for x in range(r.w)), cells)]
        scaffold_cells = [5 if r.g[y][x] == 's' else 0 for y in range(r.h) for x in range(r.w)]
        for lname, source, groups in (('Tiles', cells, None), ('PrisonMasonry', masonry_cells, None),
                                      ('Collisions', scaffold_cells, 'scaffolding')):
            ld = layer_defs[lname]
            ts = tilesets[ld['tilesetDefUid']]
            layers[lname]['autoLayerTiles'] = bake(ld, source, r.w, r.h, ts['pxWid'] // 8, groups, name)
            s, e = array_span(text, layers[lname]['iid'], 'autoLayerTiles')
            replacements.append((s, e, formatted(layers[lname]['autoLayerTiles'])))
        visual = layers['Collisions']
        visual['intGridCsv'] = scaffold_cells
        s, e = array_span(text, visual['iid'], 'intGridCsv')
        cursor = iter(scaffold_cells)
        replacements.append((s, e, re.sub(r'(?<!\d)\d+(?!\d)', lambda _m: str(next(cursor)), text[s:e])))

        ent_layer = layers['Entities']
        instances = []
        for spec in r.ents:
            d = defs[spec['ident']]
            w, h = spec['size']
            px = spec['px']
            # LDtk stores whole pixels; keep the half-cell centres exact.
            px = [int(round(px[0])), int(round(px[1]))]
            fields = []
            for f in d['fieldDefs']:
                if f['identifier'] in spec['fields']:
                    v = spec['fields'][f['identifier']]
                    if isinstance(v, tuple) and v[0] == '@ref':
                        target = next(s for s in r.ents if s['key'] == v[1])
                        v = {'entityIid': iid_for(name, target['key']), 'layerIid': ent_layer['iid'],
                             'levelIid': level['iid'], 'worldIid': world_iid}
                    elif isinstance(v, tuple) and v[0] == '@key':
                        other = levels[v[1]]
                        v = {'entityIid': iid_for(v[1], 'Key'),
                             'layerIid': next(li['iid'] for li in other['layerInstances'] if li['__identifier'] == 'Entities'),
                             'levelIid': other['iid'], 'worldIid': world_iid}
                    elif f['__type'] == 'Float':
                        v = float(v)
                    real = real_values(f['__type'], v)
                else:
                    v, real = default_value(f), []
                fields.append({'__identifier': f['identifier'], '__type': f['__type'], '__value': v,
                               '__tile': None, 'defUid': f['uid'], 'realEditorValues': real})
            instances.append({
                '__identifier': spec['ident'], '__grid': [px[0] // 8, px[1] // 8],
                '__pivot': [d['pivotX'], d['pivotY']], '__tags': list(d.get('tags', [])),
                '__tile': dict(d['tileRect']) if d.get('tileRect') else None, '__smartColor': d['color'],
                'iid': iid_for(name, spec['key']), 'width': w, 'height': h, 'defUid': d['uid'],
                'px': px, 'fieldInstances': fields,
                '__worldX': level['worldX'] + px[0], '__worldY': level['worldY'] + px[1]})
        ent_layer['entityInstances'] = instances
        s, e = array_span(text, ent_layer['iid'], 'entityInstances')
        replacements.append((s, e, formatted(instances)))

    for start, end, value in sorted(replacements, reverse=True):
        text = text[:start] + value + text[end:]
    assert json.loads(text) == project
    PATH.write_text(text)
    routes = {}
    for key in ROUTE_ORDER:
        base = key.split('#')[0]
        routes[key] = HUB_ROUTES[key] if base == 'Prison_Hub' else ROOMS[base].route
    ROUTES.write_text(json.dumps(routes, indent=1) + '\n')
    print('Built', len(ROOMS), 'prison rooms,', sum(len(r.ents) for r in ROOMS.values()), 'entities')


def write_doc():
    out = ['# Prison wings v3 — precision chains', '',
           '_Generated by `tools/build_prison_wings.py --doc` from the same room data that is',
           'built into `ldtk/hooshang_act2.ldtk`. Edit the tool, not this file._', '',
           'Every room is a CHAIN of precise moves; the route reads at a glance and the',
           'challenge is executing it. Chain length grows per wing: room 1 ~3-4 moves,',
           'room 2 ~5-7, room 3 ~8-12 ending on the key; room 4 is a calm shortcut home.',
           'Nothing is locked: every wing and every shortcut is open from the start, so the',
           'keys come in any order. Every room entry is a checkpoint; long rooms add `@`.', '',
           '## Wings', '',
           '- **Green / Library — wall-jump + dash.** Book-stack shafts to zigzag up, gaps to',
           '  dash, a spiked chimney to wall-slide down. Nothing times you; it is all climbing',
           '  and crossing.',
           '- **Red / Cafeteria — rhythm.** Crumbling trays (0.6s), thoughts bobbing on fixed',
           '  clocks, a lever-timed shutter. The route is obvious; WHEN to go is the puzzle.',
           '- **Blue / Flooded basement — water <-> air.** Water is safe and refills the dash',
           '  (Celeste rule, `prison_world.gd`). Kick out, dash, splash down, kick out again.',
           '- **Gold / Gym — capstone.** Springboards and a pressure-plate shutter, then every',
           '  verb from the other wings in one chain.', '',
           '## Child Hooshang\'s numbers (px; a cell is 8)', '',
           '| move | measured | design rule |', '|---|---|---|',
           '| running jump | apex 40, reach 70 | 4 rows up, 7-col gap |',
           '| jump + dash | reach 84-104 | 10-col gap (11-12 tight) |',
           '| jump + up-dash | rise 60-75 | 7 rows |',
           '| spring / + up-dash | 71 / 108 | 8 / 13 rows |',
           '| wall-jump zigzag | ~24-27 per kick | shaft 4-9 cols wide; no single-wall climb |',
           '| up-dash out of water | feet 45 above surface | 4 rows |', '',
           '**Legend:** `#` wall, `=` one-way, `~` water, `^ v > <` spikes (pointing), `c` crumbling,',
           '`w` crumbling stone that comes back when you swim, `S` springboard, `T` thought',
           '(moving hazard, centre of its path), `o` lemon, `K` key, `P` spawn, `@` checkpoint,',
           '`L` lever, `G` timed shutter, `r` relay, `_` pressure plate.', '']
    order = ['Prison_Hub'] + [f'Prison_{w}0{i}' for w in 'GRBY' for i in range(1, 5)]
    for name in order:
        r = ROOMS[name]
        out += [f'## {name} — {r.title}', '', '```', r.ascii(), '```', '']
        if r.chain:
            out += ['Chain: ' + ' → '.join(r.chain), '']
        for note in r.notes: out += [f'- {note}']
        if r.notes: out.append('')
    DOC.write_text('\n'.join(out))
    print('Wrote', DOC.relative_to(ROOT))


if __name__ == '__main__':
    if '--doc' in sys.argv: write_doc()
    if '--doc-only' not in sys.argv: build()
