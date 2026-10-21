#!/usr/bin/env python3
"""Build Act III — the sea — into ldtk/hooshang_act3.ldtk.

The rooms are DRAWN in tools/act3_rooms.py, as character grids plus a few calls
for the things a character cannot say (a current's flow, a jellyfish's path,
what a memory remembers). This script turns them into the project:

  - the semantic `Collision` IntGrid (1 solid, 2 one-way, 4 water) the game
    collides with (scenes/props/sea/sea_room.gd reads it at runtime),
  - the visible `Collisions` IntGrid in the existing Act 3 brushes (brick =
    rock, Grass = seabed, Scaffolding = pier / wreck), with its auto-layer tiles
    baked by act3_connected_terrain.rebake — the same rules LDtk itself runs, so
    the rooms stay editable there,
  - every entity, including the sea's own (Current, AirBubble, Jellyfish,
    Memory, InkFlood, SeaDecor, Marker), whose definitions it adds if missing,
  - resources/levels/act3_rooms.json (per-room title/chapter/palette for the
    import, scripts/act3/sea_import.gd),
  - resources/levels/act3_routes.json (each room's proven route, replayed with
    real input by tests/act3_routes_test.tscn),
  - docs/act3/act3_rooms.md (ASCII map + intended moves, regenerated each run).

The two old sketch rooms (Act3_Level_0/1 as they stood) are kept, renamed
Act3_Sketch_A/B and moved off to the side; LdtkWorld.SHELVED_ROOMS keeps them
out of the route.

    python3 tools/build_act3_world.py            # write everything
    python3 tools/build_act3_world.py --check    # validate + print maps only

LDtk and the Godot editor must be CLOSED (both hold the project in memory and
write it back wholesale). Re-import afterwards — see CLAUDE.md.
"""
import copy
import json
import random
import subprocess
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import act3_connected_terrain as terrain  # noqa: E402
from ldtk_preserve_json import update  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'ldtk/hooshang_act3.ldtk'
ROOMS_JSON = ROOT / 'resources/levels/act3_rooms.json'
ROUTES_JSON = ROOT / 'resources/levels/act3_routes.json'
DOC = ROOT / 'docs/act3/act3_rooms.md'
NS = uuid.UUID('a3c0ffee-5ea0-4a3e-9d0f-0c3a2f6f7a33')
CELL = 8

SOLID = {'#': 2, 'g': 5, 's': 6}       # visible brush per terrain char
SEMANTIC = {'#': 1, 'g': 1, 's': 1, 'x': 1, '=': 2}
ENTITY_GLYPHS = set('P@objTLGmR^v<>cH')


# ------------------------------------------------------------------ rooms ---

class Room:
    """One Act III room: a character grid, a few entity specs and its route.

    Terrain: '#' rock, 'g' seabed, 's' pier/wreck, 'x' invisible solid (an open
    sky's lid), '=' one-way plank, '.' open, ',' open and never water, '~'
    open and always water. Open cells at or below `water` (a row) are water.
    Entity glyphs stand on open cells: P start, @ checkpoint, o lemon,
    b air bubble, j jellyfish, T/L/G dark/light/grey thought, m memory,
    R Rumi, ^ v < > cone spikes (pointing), c crumbling, H ladder.
    Glyphs that need settings take them, in reading order, from `params`.
    """

    def __init__(self, name, title, chapter, pos, rows, water=None, horizon=-1,
                 fixed_depth=-1.0):
        self.name, self.title, self.chapter = name, title, chapter
        self.pos = pos
        self.rows = rows
        self.h = len(rows)
        self.w = len(rows[0])
        self.water = water
        self.horizon = horizon
        self.fixed_depth = fixed_depth
        self.params = {}
        self.extra = []      # extra entity specs (currents, markers, decor...)
        self.route = []
        self.chain = []
        self.notes = []
        self.decor_density = 1.0
        self.mode = ''       # '' sea, 'sunrise' the real sea, 'dawn' the office
        self.width_problems = [f'{name}: row {y} is {len(row)} wide, not {self.w}'
                               for y, row in enumerate(rows) if len(row) != self.w]

    # -- reading
    def ch(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.rows[y][x]
        return '#'

    def terrain(self, x, y):
        c = self.ch(x, y)
        if c in ENTITY_GLYPHS:
            return '.'
        return c

    def is_solid(self, x, y):
        return self.terrain(x, y) in SEMANTIC and self.terrain(x, y) != '='

    def is_water(self, x, y):
        t = self.terrain(x, y)
        if t == '~':
            return True
        if t in ('.',) and self.water is not None and y >= self.water:
            return True
        return False

    def semantic(self, x, y):
        t = self.terrain(x, y)
        if t in SEMANTIC:
            return SEMANTIC[t]
        return 4 if self.is_water(x, y) else 0

    # -- authoring
    def set(self, glyph, *items):
        self.params[glyph] = list(items)
        return self

    def current(self, x0, y0, x1, y1, fx, fy):
        w, h = (x1 - x0 + 1) * CELL, (y1 - y0 + 1) * CELL
        self.extra.append(('Current', ((x0 * CELL + w / 2), (y0 * CELL + h / 2)), (w, h),
                           {'FlowX': float(fx), 'FlowY': float(fy)}))

    def mark(self, name, x, y):
        self.extra.append(('Marker', (x * CELL + 4, y * CELL + 4), (8, 8), {'Name': name}))

    def decor(self, kind, x, y, height=1, flip=False):
        """`(x, y)` is the cell the decor STANDS on (its base sits on that
        cell's top edge)."""
        self.extra.append(('SeaDecor', (x * CELL + 4, y * CELL), (8, 8),
                           {'Kind': kind, 'Height': float(height), 'Flip': 1.0 if flip else 0.0}))

    def ink(self, speed, accel=0.0, start=4.0):
        self.extra.append(('InkFlood', (self.w * CELL / 2, self.h * CELL / 2), (self.w * CELL, self.h * CELL),
                           {'Speed': float(speed), 'Acceleration': float(accel), 'StartDepth': float(start)}))

    # -- routes (tests/act3_routes_test.gd)
    def step(self, frm, to, moves=('jump',), dash=(), dive=(), **kw):
        """One leg of the proven route. `frm`/`to` are (x, floor_row) for a
        standing point, ('w', x, y) for a point in the water, or `to` a dict
        {'portal': room}. dash/dive list directions ('r','ul',...)."""
        def point(p):
            if p[0] == 'w':
                return {'water': True, 'x': p[1] * CELL + 4, 'y': p[2] * CELL + 4}
            return {'x': p[0] * CELL + 4, 'y': p[1] * CELL}
        spec = {'from': point(frm), 'moves': list(moves), 'dash': list(dash), 'dive': list(dive)}
        if isinstance(to, dict):
            spec['to'] = dict(to)
        else:
            spec['to'] = point(to)
            spec['to']['tol'] = to[3] if to[0] == 'w' and len(to) > 3 else (to[2] if to[0] != 'w' and len(to) > 2 else 8)
        for key, value in kw.items():
            if key in ('steer', 'steer_first'):
                value = value * CELL + 4
            if key == 'steer_y':
                value = value * CELL + 4
            spec[key] = value
        self.route.append(spec)

    def ascii(self):
        out = []
        for y in range(self.h):
            row = ''
            for x in range(self.w):
                c = self.ch(x, y)
                if c == '.' and self.is_water(x, y):
                    c = '~'
                row += c
            out.append(f'{y:2d} {row}')
        ruler = '   ' + ''.join(str(x // 10) if x % 10 == 0 else ' ' for x in range(self.w))
        return '\n'.join([ruler] + out)


# ------------------------------------------------------------ definitions ---

def _field(uid, ident, ftype, default, doc, multiline=False):
    type_id = {'Float': 'F_Float', 'String': 'F_Text' if multiline else 'F_String'}[ftype]
    d = {'id': 'V_Float' if ftype == 'Float' else 'V_String', 'params': [default]}
    return {
        'identifier': ident, 'doc': doc, '__type': ftype, 'uid': uid, 'type': type_id,
        'isArray': False, 'canBeNull': False, 'arrayMinLength': None, 'arrayMaxLength': None,
        'editorDisplayMode': 'NameAndValue', 'editorDisplayScale': 1, 'editorDisplayPos': 'Above',
        'editorLinkStyle': 'ArrowsLine', 'editorDisplayColor': None, 'editorAlwaysShow': False,
        'editorShowInWorld': True, 'editorCutLongValues': True, 'editorTextSuffix': None,
        'editorTextPrefix': None, 'useForSmartColor': False, 'exportToToc': False,
        'searchable': False, 'min': None, 'max': None, 'regex': None, 'acceptFileTypes': None,
        'defaultOverride': d, 'textLanguageMode': 'LangPython' if multiline else None,
        'symmetricalRef': False, 'autoChainRef': False, 'allowOutOfLevelRef': False,
        'allowedRefs': 'Any', 'allowedRefsEntityUid': None, 'allowedRefTags': [], 'tilesetUid': None,
    }


# identifier -> (w, h, resizable, colour, render, doc, [(field, type, default, doc, multiline)])
SEA_ENTITIES = {
    'Current': (32, 32, True, '#4FB6D6', 'Rectangle',
                'Act III: a river in the sea. While he swims inside it, (FlowX, FlowY) px/s is added to his stroke. Flow upward draws as a bubble column.',
                [('FlowX', 'Float', 80.0, 'Horizontal flow, px/s (+ right).', False),
                 ('FlowY', 'Float', 0.0, 'Vertical flow, px/s (+ down; negative = a bubble column).', False)]),
    'AirBubble': (16, 16, False, '#D8F4FF', 'Ellipse',
                  'Act III: a breath of air. Touch it to refill the Dive and the dash; it pops and grows back.', []),
    'Jellyfish': (16, 20, False, '#FF7AA8', 'Ellipse',
                  'Act III: a drifting thought on DarkThought\'s paths. The BELL bounces and refills; the TENTACLES kill.',
                  [('Motion', 'Enum', 'Vertical', 'Path (ThoughtMotion).', False),
                   ('Amplitude', 'Float', 16.0, 'Half the travel, px.', False),
                   ('Speed', 'Float', 0.4, 'Cycles per second.', False),
                   ('Phase', 'Float', 0.0, 'Start offset, 0..1 of a cycle.', False),
                   ('Angle', 'Float', 0.0, 'Degrees, for Linear.', False),
                   ('Clockwise', 'Float', 1.0, '1 = clockwise, for Circle.', False)]),
    'Memory': (16, 16, False, '#F2C46D', 'Ellipse',
               'Act III: one of the things he kept. Kind = nameplate/photo/ticket/letter/can/pearl. Lines = what he says, a DialogueScript in his voice.',
               [('Kind', 'String', 'nameplate', 'Which object.', False),
                ('Lines', 'String', '', 'What he remembers. (state) names his face.', True)]),
    'InkFlood': (320, 384, True, '#2B1640', 'Rectangle',
                 'Act III: Darkshang pouring down the trench. Covers the room; its front descends at Speed once he commits.',
                 [('Speed', 'Float', 34.0, 'Front speed, px/s.', False),
                  ('Acceleration', 'Float', 0.0, 'Extra px/s per second.', False),
                  ('StartDepth', 'Float', 4.0, 'Front start, px below the room top.', False)]),
    'SeaDecor': (8, 8, False, '#7FA38B', 'Rectangle',
                 'Act III set dressing (no collision). Kind: kelp, reed, seagrass, coral, fan, rock, shell, desk, cabinet, partition, chair, tube, rib, skull, anchor, lantern, pier_post.',
                 [('Kind', 'String', 'kelp', 'Which piece.', False),
                  ('Height', 'Float', 1.0, 'Cells tall, for kelp and reeds.', False),
                  ('Flip', 'Float', 0.0, '1 = mirrored.', False)]),
    'Marker': (8, 8, False, '#FFFFFF', 'Cross',
               'Act III: a named point for the story script (scripts/act3/act3_beats.gd).',
               [('Name', 'String', 'Marker', 'What the story calls it.', False)]),
}


def ensure_defs(project):
    defs = project['defs']
    have = {e['identifier']: e for e in defs['entities']}
    motion_enum = next(e for e in defs['enums'] if e['identifier'] == 'ThoughtMotion')
    template = have['DarkThought']
    for ident, (w, h, resizable, colour, render, doc, fields) in SEA_ENTITIES.items():
        if ident in have:
            continue
        e = copy.deepcopy(template)
        e.update({'identifier': ident, 'uid': project['nextUid'], 'doc': doc, 'width': w, 'height': h,
                  'resizableX': resizable, 'resizableY': resizable, 'color': colour,
                  'renderMode': render, 'tilesetId': None, 'tileRect': None, 'uiTileRect': None,
                  'fillOpacity': 0.25 if resizable else 0.6, 'hollow': False, 'showName': True})
        project['nextUid'] += 1
        e['fieldDefs'] = []
        for fname, ftype, default, fdoc, multiline in fields:
            if ftype == 'Enum':
                f = copy.deepcopy(next(f for f in template['fieldDefs'] if f['identifier'] == 'Motion'))
                f['uid'] = project['nextUid']
                f['defaultOverride'] = {'id': 'V_String', 'params': [default]}
                f['type'] = f'F_Enum({motion_enum["uid"]})'
            else:
                f = _field(project['nextUid'], fname, ftype, default, fdoc, multiline)
            project['nextUid'] += 1
            e['fieldDefs'].append(f)
        defs['entities'].append(e)
    # The semantic grid's value 4 is WATER in Act III (an Act I relic,
    # UnderworldTrigger, before). Same number Act II uses for water.
    coll = next(l for l in defs['layers'] if l['identifier'] == 'Collision')
    for v in coll['intGridValues']:
        if v['value'] == 4:
            v['identifier'] = 'Water'
            v['color'] = '#2F7FD0'


# ------------------------------------------------------------------ write ---

def ldtk_running():
    try:
        out = subprocess.run(['ps', 'ax', '-o', 'command'], capture_output=True, text=True).stdout
    except Exception:
        return False
    return any('LDtk.app/Contents/MacOS/LDtk' in line for line in out.splitlines())


def iid(*parts):
    return str(uuid.uuid5(NS, '/'.join(str(p) for p in parts)))


def field_instances(d, values):
    out = []
    for f in d['fieldDefs']:
        if f['identifier'] in values:
            v = values[f['identifier']]
            if f['__type'] == 'Float':
                v = float(v)
                real = [{'id': 'V_Float', 'params': [v]}]
            else:
                real = [{'id': 'V_String', 'params': [v]}]
        else:
            dflt = f.get('defaultOverride')
            v = dflt['params'][0] if dflt else None
            real = []
        out.append({'__identifier': f['identifier'], '__type': f['__type'], '__value': v,
                    '__tile': None, 'defUid': f['uid'], 'realEditorValues': real})
    return out


def entity_instance(project, level, room, key, ident, px, size, values):
    d = next(e for e in project['defs']['entities'] if e['identifier'] == ident)
    px = [int(round(px[0])), int(round(px[1]))]
    return {
        '__identifier': ident, '__grid': [px[0] // CELL, px[1] // CELL],
        '__pivot': [d['pivotX'], d['pivotY']], '__tags': list(d.get('tags', [])),
        '__tile': dict(d['tileRect']) if d.get('tileRect') else None,
        '__smartColor': d['color'], 'iid': iid(room.name, key),
        'width': int(size[0]), 'height': int(size[1]), 'defUid': d['uid'], 'px': px,
        'fieldInstances': field_instances(d, values),
        '__worldX': level['worldX'] + px[0], '__worldY': level['worldY'] + px[1]}


def stand_px(room, x, y):
    """Body centre for an entity glyph at cell (x, y): standing on the cell
    below if it is solid ground, else floating at the cell's centre."""
    if room.terrain(x, y + 1) in SEMANTIC:
        return (x * CELL + 4, (y + 1) * CELL - 6)
    return (x * CELL + 4, y * CELL + 4)


def room_entities(room):
    """Every entity spec in a room: (ident, px, size, fields, key)."""
    specs = []
    counters = {}

    def take(glyph):
        i = counters.get(glyph, 0)
        counters[glyph] = i + 1
        seq = room.params.get(glyph, [])
        return seq[i] if i < len(seq) else {}

    seen = set()
    for y in range(room.h):
        for x in range(room.w):
            c = room.ch(x, y)
            if c not in ENTITY_GLYPHS or (x, y) in seen:
                continue
            if c == 'P':
                specs.append(('PlayerStart', stand_px(room, x, y), (16, 16), {'SpawnID': 'start'}))
            elif c == '@':
                specs.append(('Checkpoint', stand_px(room, x, y), (16, 16), {}))
            elif c == 'o':
                specs.append(('Lemon', (x * CELL + 4, y * CELL + 4), (16, 16), {}))
            elif c == 'b':
                specs.append(('AirBubble', (x * CELL + 4, y * CELL + 4), (16, 16), {}))
            elif c in 'TLG':
                p = take(c)
                ident = {'T': 'DarkThought', 'L': 'LightThought', 'G': 'GreyThought'}[c]
                specs.append((ident, (x * CELL + 4, y * CELL + 4), (16, 16), {
                    'Motion': p.get('motion', 'Vertical'), 'Amplitude': p.get('amp', 16.0),
                    'Speed': p.get('speed', 0.4), 'Phase': p.get('phase', 0.0),
                    'Angle': p.get('angle', 0.0), 'Clockwise': p.get('cw', 1.0),
                    'PsychedelicPalette': 1.0, 'Glow': 1.0}))
            elif c == 'j':
                p = take(c)
                specs.append(('Jellyfish', (x * CELL + 4, y * CELL + 4), (16, 20), {
                    'Motion': p.get('motion', 'Vertical'), 'Amplitude': p.get('amp', 16.0),
                    'Speed': p.get('speed', 0.4), 'Phase': p.get('phase', 0.0),
                    'Angle': p.get('angle', 0.0), 'Clockwise': p.get('cw', 1.0)}))
            elif c == 'm':
                p = take(c)
                specs.append(('Memory', (x * CELL + 4, y * CELL + 4), (16, 16),
                              {'Kind': p.get('kind', 'nameplate'), 'Lines': p.get('lines', '')}))
            elif c == 'R':
                p = take(c)
                # Rumi is invisible until his trigger fires, so a swimmer must not
                # be able to go round it: `w` widens the (room-tall) trigger.
                specs.append(('RumiTrigger', (x * CELL + 4, y * CELL + 4), (p.get('w', 24), 32),
                              {'DialogueLine': p.get('text', '')}))
            elif c in '^v<>':
                horizontal = c in '^v'
                n = 0
                while room.ch(x + (n if horizontal else 0), y + (0 if horizontal else n)) == c:
                    seen.add((x + (n if horizontal else 0), y + (0 if horizontal else n)))
                    n += 1
                ident = {'^': 'ConeSpikes', 'v': 'ConeSpikesCeiling', '>': 'ConeSpikesLeftWall',
                         '<': 'ConeSpikesRightWall'}[c]
                if horizontal:
                    px, size = ((x + n / 2) * CELL, y * CELL + 4), (n * CELL, CELL)
                else:
                    px, size = (x * CELL + 4, (y + n / 2) * CELL), (CELL, n * CELL)
                specs.append((ident, px, size, {'PsychedelicPalette': 1.0}))
            elif c == 'c':
                n = 0
                while room.ch(x + n, y) == 'c':
                    seen.add((x + n, y))
                    n += 1
                specs.append(('CrumblingPlatform', ((x + n / 2) * CELL, y * CELL + 4), (n * CELL, CELL), {}))
            elif c == 'H':
                n = 0
                while room.ch(x, y + n) == 'H':
                    seen.add((x, y + n))
                    n += 1
                specs.append(('Ladder', (x * CELL + 4, (y + n / 2) * CELL), (CELL, n * CELL),
                              {'PsychedelicPalette': 1.0}))
    # A room drawn without a P starts where its proven route starts.
    if not any(room.ch(x, y) == 'P' for y in range(room.h) for x in range(room.w)) and room.route:
        start = room.route[0]['from']
        at = (start['x'], start['y']) if start.get('water') else (start['x'], start['y'] - 6)
        specs.append(('PlayerStart', at, (16, 16), {'SpawnID': 'start'}))
    for ident, px, size, fields in room.extra:
        specs.append((ident, px, size, fields))
    specs.extend(auto_decor(room))
    return specs


def auto_decor(room):
    """Sea-grass and kelp on exposed seabed, coral and fans on the reef — hashed
    from the cell so a rebuild is stable. Never on a cell an entity uses, and
    only where there is open water (or a shore) above to grow into."""
    out = []
    if room.decor_density <= 0:
        return out
    rng_base = room.name
    occupied = {(round((px[0] - 4) / CELL), round(px[1] / CELL)) for _, px, _, f in room.extra}
    for y in range(1, room.h):
        for x in range(1, room.w - 1):
            if room.terrain(x, y) != 'g' or room.terrain(x, y - 1) in SEMANTIC:
                continue
            if room.ch(x, y - 1) in ENTITY_GLYPHS or (x, y) in occupied:
                continue
            rng = random.Random(f'{rng_base}:{x}:{y}')
            r = rng.random() / room.decor_density
            wet = room.is_water(x, y - 1)
            if room.chapter == 4 and wet:
                if r < 0.07:
                    out.append(('SeaDecor', (x * CELL + 4, y * CELL), (8, 8), {'Kind': 'coral', 'Height': 1.0, 'Flip': float(rng.random() < 0.5)}))
                elif r < 0.12:
                    out.append(('SeaDecor', (x * CELL + 4, y * CELL), (8, 8), {'Kind': 'fan', 'Height': 1.0, 'Flip': float(rng.random() < 0.5)}))
                elif r < 0.3:
                    out.append(('SeaDecor', (x * CELL + 4, y * CELL), (8, 8), {'Kind': 'seagrass', 'Height': 1.0, 'Flip': 0.0}))
            elif wet and room.chapter >= 2:
                clear = all(not room.is_solid(x, y - k) for k in range(1, 5))
                if r < 0.07 and clear:
                    out.append(('SeaDecor', (x * CELL + 4, y * CELL), (8, 8), {'Kind': 'kelp', 'Height': float(2 + int(rng.random() * 3)), 'Flip': 0.0}))
                elif r < 0.24:
                    out.append(('SeaDecor', (x * CELL + 4, y * CELL), (8, 8), {'Kind': 'seagrass', 'Height': 1.0, 'Flip': float(rng.random() < 0.5)}))
                elif r < 0.27:
                    out.append(('SeaDecor', (x * CELL + 4, y * CELL), (8, 8), {'Kind': 'shell', 'Height': 1.0, 'Flip': 0.0}))
            elif room.chapter == 1 and not wet:
                if r < 0.05:
                    out.append(('SeaDecor', (x * CELL + 4, y * CELL), (8, 8), {'Kind': 'shell', 'Height': 1.0, 'Flip': 0.0}))
                elif r < 0.09:
                    out.append(('SeaDecor', (x * CELL + 4, y * CELL), (8, 8), {'Kind': 'reed', 'Height': float(1 + int(rng.random() * 2)), 'Flip': 0.0}))
    return out


def blank_level(project, template, room, uid):
    level = copy.deepcopy(template)
    level['identifier'] = room.name
    level['iid'] = iid(room.name, 'level')
    level['uid'] = uid
    level['worldX'], level['worldY'] = room.pos
    level['pxWid'], level['pxHei'] = room.w * CELL, room.h * CELL
    level['fieldInstances'] = []
    level['__neighbours'] = []
    level['bgColor'] = level['__bgColor'] = '#000000'
    for li in level['layerInstances']:
        li['iid'] = iid(room.name, li['__identifier'])
        li['levelId'] = uid
        li['__cWid'], li['__cHei'] = room.w, room.h
        li['seed'] = random.Random(room.name + li['__identifier']).randint(0, 9999999)
        li['autoLayerTiles'] = []
        li['gridTiles'] = []
        li['entityInstances'] = []
        if li['__type'] == 'IntGrid':
            li['intGridCsv'] = [0] * (room.w * room.h)
        else:
            li['intGridCsv'] = []
    return level


def validate(rooms):
    problems = []
    by_name = {r.name: r for r in rooms}
    names = [r.name for r in rooms]
    assert len(names) == len(set(names))
    for r in rooms:
        problems.extend(r.width_problems)
    if problems:
        return problems
    for r in rooms:
        if not any(r.ch(x, y) == 'P' for y in range(r.h) for x in range(r.w)) and not r.route:
            problems.append(f'{r.name}: no P (PlayerStart) and no route to take one from')
        for glyph, seq in r.params.items():
            count = sum(1 for y in range(r.h) for x in range(r.w) if r.ch(x, y) == glyph)
            if count != len(seq):
                problems.append(f'{r.name}: {count} "{glyph}" glyphs but {len(seq)} params')
    # Portals: every open border cell must face an open cell of a neighbour,
    # or the opening is a dead end (or a fall out of the world).
    for a in rooms:
        ax, ay = a.pos
        for y in range(a.h):
            for x in range(a.w):
                if not (x in (0, a.w - 1) or y in (0, a.h - 1)):
                    continue
                if a.is_solid(x, y) or a.terrain(x, y) == '=':
                    continue
                wx, wy = ax + x * CELL, ay + y * CELL
                # the cell just outside, in each direction this cell borders
                outs = []
                if x == 0: outs.append((wx - CELL, wy))
                if x == a.w - 1: outs.append((wx + CELL, wy))
                if y == 0: outs.append((wx, wy - CELL))
                if y == a.h - 1: outs.append((wx, wy + CELL))
                for ox, oy in outs:
                    hit = None
                    for b in rooms:
                        bx, by = b.pos
                        if bx <= ox < bx + b.w * CELL and by <= oy < by + b.h * CELL:
                            hit = b
                    if hit is None:
                        if a.fixed_depth < 0 or True:
                            problems.append(f'{a.name}: border cell ({x},{y}) opens onto nothing')
                        continue
                    cx, cy = (ox - hit.pos[0]) // CELL, (oy - hit.pos[1]) // CELL
                    if hit.is_solid(cx, cy):
                        problems.append(f'{a.name}: border cell ({x},{y}) meets solid in {hit.name} ({cx},{cy})')
                    elif hit.is_water(cx, cy) != a.is_water(x, y):
                        problems.append(f'{a.name}: ({x},{y}) water={a.is_water(x, y)} meets {hit.name} ({cx},{cy}) water={hit.is_water(cx, cy)}')
    return problems


def build(rooms, check_only=False):
    problems = validate(rooms)
    for p in problems:
        print('  !!', p)
    if check_only:
        for r in rooms:
            print(f'\n== {r.name} — {r.title}\n{r.ascii()}')
        return not problems
    assert not ldtk_running(), 'Close LDtk before rebuilding Act III'
    text = PATH.read_text()
    project = json.loads(text)
    ensure_defs(project)
    layer_defs = {d['identifier']: d for d in project['defs']['layers']}
    levels = project['levels']
    # Keep the old sketches, renamed and moved out of the way.
    for lv in levels:
        if lv['identifier'] in ('Act3_Level_0', 'Act3_Level_1') and not lv.get('__act3_built'):
            if any(li['__identifier'] == 'Entities' and len(li['entityInstances']) == 2
                   and {e['__identifier'] for e in li['entityInstances']} == {'PlayerStart', 'Ladder'}
                   for li in lv['layerInstances']):
                letter = 'A' if lv['identifier'].endswith('0') else 'B'
                lv['identifier'] = f'Act3_Sketch_{letter}'
                lv['worldX'] = -1400 if letter == 'A' else -680
                lv['worldY'] = -800
                for li in lv['layerInstances']:
                    for e in li['entityInstances']:
                        e['__worldX'] = lv['worldX'] + e['px'][0]
                        e['__worldY'] = lv['worldY'] + e['px'][1]
    built = {r.name for r in rooms}
    template = next(l for l in levels if l['pxWid'] == 320 and l['pxHei'] == 192)
    existing = {l['identifier']: l for l in levels}
    out_levels = [l for l in levels if l['identifier'] not in built]
    for r in rooms:
        old = existing.get(r.name)
        uid = old['uid'] if old else project['nextUid']
        if not old:
            project['nextUid'] += 1
        level = blank_level(project, template, r, uid)
        layers = {li['__identifier']: li for li in level['layerInstances']}
        layers['Collision']['intGridCsv'] = [r.semantic(x, y) for y in range(r.h) for x in range(r.w)]
        vis = layers['Collisions']
        vis['intGridCsv'] = [SOLID.get(r.terrain(x, y), 0) for y in range(r.h) for x in range(r.w)]
        terrain.rebake(vis, layer_defs['Collisions'])
        ents = []
        for i, (ident, px, size, fields) in enumerate(room_entities(r)):
            ents.append(entity_instance(project, level, r, f'{ident}:{i}', ident, px, size, fields))
        layers['Entities']['entityInstances'] = ents
        out_levels.append(level)
    project['levels'] = out_levels
    PATH.write_text(update(text, project))
    meta = {r.name: {'title': r.title, 'chapter': r.chapter, 'fixed_depth': r.fixed_depth,
                     'horizon': r.horizon, 'mode': r.mode} for r in rooms}
    ROOMS_JSON.write_text(json.dumps(meta, indent=1) + '\n')
    routes = {r.name: r.route for r in rooms if r.route}
    ROUTES_JSON.write_text(json.dumps(routes, indent=1) + '\n')
    write_doc(rooms)
    print('Built', len(rooms), 'Act III rooms,', sum(len(room_entities(r)) for r in rooms), 'entities')
    return True


def write_doc(rooms):
    out = ['# Act III rooms', '',
           '_Generated by `tools/build_act3_world.py` from `tools/act3_rooms.py`. Edit the tool, not this file._',
           '', 'See `docs/act3/ACT3_DESIGN.md` for the act. Legend: `#` rock, `g` seabed, `s` pier/wreck,',
           '`x` invisible lid, `=` one-way, `~` water, `,` dry pocket, `P` start, `@` checkpoint, `o` lemon,',
           '`b` air bubble, `j` jellyfish, `T/L/G` thoughts, `m` memory, `R` Rumi, `^ v < >` spikes,',
           '`c` crumbling, `H` ladder. Currents, markers and decor are listed under each map.', '']
    chapter_names = {1: 'I · THE INK SHORE', 2: 'II · THE SHALLOWS', 3: 'III · THE DROWNED OFFICE',
                     4: 'IV · THE REEF OF LANTERNS', 5: 'V · THE FLOOR OF LIGHT', 6: 'EPILOGUE'}
    chapter = None
    for r in rooms:
        if r.chapter != chapter:
            chapter = r.chapter
            out += [f'## {chapter_names.get(chapter, chapter)}', '']
        out += [f'### {r.name} — {r.title}', '', '```', r.ascii(), '```', '']
        currents = [e for e in r.extra if e[0] == 'Current']
        for _, px, size, f in currents:
            out.append(f'- current at {int(px[0] - size[0] / 2) // 8},{int(px[1] - size[1] / 2) // 8} '
                       f'({int(size[0]) // 8}x{int(size[1]) // 8} cells) flow ({f["FlowX"]:.0f}, {f["FlowY"]:.0f})')
        if r.chain:
            out.append('- route: ' + ' → '.join(r.chain))
        for n in r.notes:
            out.append(f'- {n}')
        out.append('')
    DOC.parent.mkdir(parents=True, exist_ok=True)
    DOC.write_text('\n'.join(out))


if __name__ == '__main__':
    from act3_rooms import ROOMS
    ok = build(ROOMS, check_only='--check' in sys.argv)
    sys.exit(0 if ok else 1)
