#!/usr/bin/env python3
"""Act 2 sky gardens, second design pass: Act_2_Level_3 .. Act_2_Level_13.

Supersedes the garden half of `rework_act2_precision.py` and the original
`build_act2_expansion.py` baseline. Every room is rebuilt from the explicit
geometry below (never a generator, never random) and every room ships with a
real-input route in `resources/levels/act2_expansion.json` that
`tests/act2_routes_test.tscn` replays entrance-to-exit. A room that cannot be
beaten with ordinary inputs fails that test rather than being found in play.

DESIGN RULES (why the rooms look the way they do — keep to them when editing):

- Act 1 already taught jump, dash, wall-jump and the thought hazards, so no
  room here re-teaches them on safe ground. Every room after the entrance pad
  sits over a LETHAL rose-thorn pit, wall to wall. (The previous pass left an
  80px thorn-free strip at the far end, which was a soft-lock: fall there and
  the only way out was the retry key.)
- One idea per room, in four beats (introduce / develop / twist / conclude):
  the first instance of an element is the cheap one, the last is the test.
- A sawtooth curve, not a ramp: 3 warms up, 4-6 each add one Act 2 mechanic
  (spring dash refills, the side spring, moving carpet gates), 7 is the first
  exam, 8 is a deliberate breather with a hard optional dare, 9-12 escalate,
  13 combines everything.
- A checkpoint after every phrase that is longer than ~10 seconds to replay.
- Lemons are a dare OFF the critical path, visible from it: taking one costs
  a risk the main line does not ask for.
- Drifting thoughts are timed, never random: each one's period is long enough
  to read on sight, and gates in one room are phase-shifted so they never
  move as one wall.

CHILD MOVEMENT these numbers are built against (`tests/act2_feel_measure.tscn`,
re-run it before changing the childhood profile):
  held jump 32px high; running jump 41px high / 70px long; jump + dash ~80-104px
  long; jump + up-dash ~70px high; up spring 71px (+ up-dash ~108px); side
  spring ~98px across at a ~22px apex. Act 2 springs REFILL the dash.

Run with LDtk AND the Godot editor closed:
  python3 tools/redesign_act2_gardens.py [--root PATH]
then re-import (`touch ldtk/hooshang_act2.ldtk` + headless `--import`).
"""
import argparse, json, subprocess, sys, uuid
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from ldtk_preserve_json import update
from act2_grass_terrain import rebake_layer
from act2_ink_hazards import replace_spikes

NS = uuid.UUID('5d0c1f3e-6a43-4b7e-9a35-2b1f0d4e8a77')
H = 320            # every garden room is 40 cells tall
PAD_W = 104        # the entrance pad: the only safe floor in a room
SPRING_UP = 'Up'


class Room:
    """Authoring helpers for one room. Coordinates are room-local px.

    A ledge is `(x, top, w)`: its walkable surface is `top`. Route points are
    `[x, top]` on a surface — the harness subtracts the player's half-height.
    """

    def __init__(self, project, level, title, end_y):
        self.p, self.r, self.title, self.end_y = project, level, title, end_y
        self.W = level['pxWid']
        self.layers = {l['__identifier']: l for l in level['layerInstances']}
        self.edefs = {d['identifier']: d for d in project['defs']['entities']}
        self.ledges, self.springs, self.side_springs = [], [], []
        self.carpets, self.gates, self.crumbles = [], [], []
        self.routes, self.optional = [], []
        self._patches, self._capture = {}, None
        self.branch_fruit = False
        for layer in level['layerInstances']:
            if layer['__type'] == 'IntGrid':
                layer['intGridCsv'] = [0] * len(layer['intGridCsv'])
            if layer['__type'] in ('IntGrid', 'AutoLayer'):
                layer['autoLayerTiles'] = []
            if layer['__type'] == 'Entities':
                layer['entityInstances'] = []

    # -- terrain ---------------------------------------------------------
    def _cells(self, layer, x, y, w, h, value):
        li = self.layers[layer]
        cw = li['__cWid']
        assert all(v % 8 == 0 for v in (x, y, w, h)), (self.r['identifier'], x, y, w, h)
        for yy in range(y // 8, (y + h) // 8):
            for xx in range(x // 8, (x + w) // 8):
                assert 0 <= xx < cw and 0 <= yy < li['__cHei'], (self.r['identifier'], xx, yy)
                li['intGridCsv'][yy * cw + xx] = value

    def solid(self, x, y, w, h):
        """Garden terrain that is not a landing (walls, roofs, pillars)."""
        self._cells('Collisions', x, y, w, h, 10)

    def ledge(self, x, y, w, h=16):
        self.solid(x, y, w, h)
        self.ledges.append([x, y, w])

    def thorns(self, x, y, w, h=8):
        """Lethal rose thicket — floors, ceilings, walls alike."""
        self._cells('InkThoughtHazards', x, y, w, h, 1)

    # -- entities --------------------------------------------------------
    def entity(self, kind, x, y, w=None, h=None, **fields):
        d = self.edefs[kind]
        es = self.layers['Entities']['entityInstances']
        fi = []
        for f in d['fieldDefs']:
            v = fields.get(f['identifier'])
            if v is None and f.get('defaultOverride'):
                v = f['defaultOverride']['params'][0]
            fi.append(dict(__identifier=f['identifier'], __type=f['__type'], __value=v,
                           __tile=None, defUid=f['uid'], realEditorValues=[]))
        x, y = int(round(x)), int(round(y))
        es.append(dict(__identifier=kind, __grid=[x // 8, y // 8], __pivot=[d['pivotX'], d['pivotY']],
                       __tags=d['tags'], __tile=d['tileRect'], __smartColor=d['color'],
                       iid=str(uuid.uuid5(NS, f"{self.r['identifier']}:{kind}:{x},{y}")),
                       width=w or d['width'], height=h or d['height'], defUid=d['uid'], px=[x, y],
                       fieldInstances=fi, __worldX=self.r['worldX'] + x, __worldY=self.r['worldY'] + y))

    def spring(self, x, top):
        """Up spring centred on x, standing on the surface at `top`."""
        self.entity('SpringPlatform', x, top - 4, Facing=SPRING_UP)
        self.springs.append([x, top])

    def side_spring(self, x, top, facing):
        """A spring turned on its side, standing on `top`. 'Right' throws him
        right and is hit by walking LEFT into its face (and vice versa)."""
        self.entity('SpringPlatform', x, top - 8, Facing=facing)
        self.side_springs.append([x, top, facing])

    def crumble(self, x, top, w=32):
        self.entity('CrumblingPlatform', x + w / 2, top + 4, w, 8)
        self.crumbles.append([x, top, w])

    def carpet(self, x, top, w=48, speed=40):
        self.entity('MagicCarpet', x, top + 4, w, 8, CarpetPattern='Ride',
                    CarpetColor='Crimson', Speed=float(speed))
        self.carpets.append([x, top, 'Ride', 0, w])

    def thought(self, x, y, motion='Vertical', amp=0.0, speed=0.25, phase=0.0,
                clockwise=1.0, angle=0.0, kind='LightThought'):
        self.entity(kind, x, y, Motion=motion, Amplitude=float(amp), Speed=float(speed),
                    Phase=float(phase), Clockwise=float(clockwise), Glow=1.0,
                    Angle=float(angle), ChildhoodPalette=1.0)

    def gate(self, x, lane, clear=10, amp=0.0, speed=0.2, phase=0.0, top=8, bottom=296):
        """A column of thoughts with one gap for a carpet riding at `lane` (its
        surface y): the rider (12px above the rug) and the rug (8px below) get
        `clear` px either side of them, and the clouds stack 20px apart beyond
        that — kill boxes 10px tall, so the holes between clouds are too small
        for him. With `amp` the whole column drifts, so the rider has to
        follow the gap rather than park in it."""
        self.gates.append([x, lane])
        y = lane - 12 - clear - 5
        while y >= top:
            self.thought(x, y, 'Vertical', amp, speed, phase)
            y -= 20
        y = lane + 8 + clear + 5
        while y <= bottom:
            self.thought(x, y, 'Vertical', amp, speed, phase)
            y += 20

    def lemon(self, x, y):
        self.entity('Lemon', x, y)

    def checkpoint(self, x, top, tag):
        self.entity('Checkpoint', x, top - 8, CheckpointID=f"{self.r['identifier']}_{tag}")

    # -- routes ----------------------------------------------------------
    def jump(self, a, b, hold=60, opt=False):
        self._route(dict(kind='jump', start=a, target=b, jump_hold=hold), opt)

    def dash(self, a, b, up=None, frame=None, hold=60, opt=False):
        step = dict(kind='dash', start=a, target=b, jump_hold=hold)
        if up is not None:
            step['dash_up'] = up
        if frame is not None:
            step['dash_frame'] = frame
        self._route(step, opt)

    def bounce(self, a, b, opt=False):
        self._route(dict(kind='spring', start=a, target=b), opt)

    def spring_dash(self, a, b, frame=18, opt=False):
        self._route(dict(kind='spring_dash', start=a, target=b, dash_frame=frame), opt)

    def chain(self, a, b, segments, walk=False, hold=60, wait=None, opt=False, trace=False):
        step = dict(kind='chain', start=a, target=b, segments=segments, walk=walk, jump_hold=hold)
        if trace:
            step['trace'] = True
        if wait:
            step['wait'] = wait
        self._route(step, opt)

    def flight(self, carpet_x, start, waypoints, target, jump_x, opt=False):
        self._route(dict(kind='flight', carpet=carpet_x, start=start, waypoints=waypoints,
                         target=target, jump_x=jump_x), opt)

    def weave(self, carpet_x, start, islands, target, jump_x, speed):
        """Build a weave; its route is added later with `weave_route()` so the
        recipe stays in play order."""
        """Needlewind's dismount/recatch passage: a 16px upper slot admits the
        player but not player + rug, the lower one the empty rug but not a rider
        (its floor is thorns). Islands are `[x, w, lane]`."""
        for bx, w, lane in islands:
            left, right = bx - 64, bx + w + 64
            self.solid(left, 0, right - left, lane - 40)
            self.ledge(bx, lane - 24, w, 24)
            self.solid(left, lane + 16, right - left, 312 - (lane + 16))
            self.thorns(left, lane + 8, right - left)
        self._weave = dict(kind='weave', carpet=carpet_x, start=start, islands=islands,
                           target=target, jump_x=jump_x, speed=speed)

    def weave_route(self, reward_lanes=None):
        step = dict(self._weave)
        if reward_lanes:
            step['reward_lanes'] = reward_lanes
        self._route(step, False)

    def _route(self, step, opt):
        if self._capture is not None:
            self._capture.append(step)
        else:
            (self.optional if opt else self.routes).append(step)

    def reward(self, index, *builders):
        """Replace main-route step `index` with the steps the `builders` add,
        in the room's REWARD route: the same run, taking every dare. Each
        builder is a no-argument callable that calls the route helpers above.
        `garden_reward_detour_test` replays it and checks every lemon banks."""
        self._capture = []
        for build in builders:
            build()
        self._patches[index], self._capture = self._capture, None

    def settle(self, frames):
        """Reward-route pause before the next step (an abandoned rug drifting
        clear of a landing it would otherwise block)."""
        self._capture.append(dict(kind='settle', frames=frames))

    # -- frame -----------------------------------------------------------
    def frame(self):
        """Entrance pad, the wall-to-wall lethal pit, the exit and checkpoints."""
        self.solid(0, 288, PAD_W, 32)
        self.solid(PAD_W, 312, self.W - PAD_W, 8)
        self.thorns(PAD_W, 304, self.W - PAD_W)
        self.entity('PlayerStart', 24, 272)
        self.checkpoint(48, 288, 'start')

    def finish(self, number):
        end_x = self.W - 24
        self.entity('Exit', end_x, self.end_y - 32,
                    NextRoom=f'Act_2_Level_{number + 1}' if number < 13 else '')
        return dict(name=self.r['identifier'], title=self.title, width=self.W, ledges=self.ledges,
                    springs=self.springs, carpets=self.carpets, side_springs=self.side_springs,
                    exit=[end_x, self.end_y], gates=self.gates, routes=self.routes,
                    crumbles=self.crumbles, optional_routes=self.optional,
                    reward_routes=[s for i, step in enumerate(self.routes)
                                   for s in self._patches.get(i, [step])],
                    branch_fruit=self.branch_fruit, final=number == 13, advanced=number >= 9)


# ============================================================ the rooms ====

def room_3(R):
    """SAFFRON STEPS — warm-up with stakes. Dash rhythm over the pit, then the
    first drifting thought: it bobs through the gap you have to dash, so the
    lesson is WAIT for it to sink, then go. Lemons sit above the thought's arc
    and over the last gap: an up-dash spent there is a dash not spent landing."""
    R.frame()
    R.ledge(120, 264, 40)
    R.ledge(216, 240, 24)
    R.ledge(288, 248, 88); R.checkpoint(336, 248, 'steps')
    R.thought(408, 216, 'Vertical', 24, 0.35, 0.0)
    R.ledge(440, 232, 32)
    R.ledge(512, 208, 24)
    R.ledge(584, 192, 56)
    R.lemon(408, 172); R.lemon(560, 156)
    R.jump([88, 288], [136, 264])
    R.dash([152, 264], [228, 240], up=True)
    R.dash([232, 240], [304, 248], up=False)
    R.chain([368, 248], [456, 232], [dict(steer=456, dash=[12, 'ur'])],
            wait=dict(thought=[408, 216], window=[0.05, 0.2]))
    R.dash([456, 232], [524, 208], up=True)
    R.dash([528, 208], [600, 192], up=True)
    R.reward(3, lambda: R.chain([368, 248], [456, 232], [dict(steer=456, dash=[16, 'ur'])],
                                wait=dict(thought=[408, 216], window=[0.05, 0.2])))


def room_4(R):
    """THE SPRING RELAY — Act 2 springs refill the dash. Introduce: one spring
    to a ledge. Develop: spring, dash, land on a FLOATING spring, which hands the
    dash back, dash again. Twist: a thorn roof over the next gap that a full
    jump clips and a side spring's flat throw slides under. The lemon above the
    floating spring is the relay's dare: spend the dash going up for it and the
    spring below is the only way to get it back."""
    R.frame()
    R.spring(80, 288)
    R.ledge(104, 232, 56); R.spring(152, 232)
    R.ledge(232, 216, 16, 24); R.spring(240, 216)
    R.ledge(296, 160, 80); R.checkpoint(352, 160, 'relay')
    R.side_spring(300, 160, 'Right')
    R.thorns(344, 112, 64)
    R.ledge(408, 176, 40)
    R.ledge(512, 160, 128)
    R.lemon(240, 120); R.lemon(376, 148)
    R.bounce([80, 288], [128, 232])
    R.chain([120, 232], [320, 160], [dict(steer=170), dict(steer=240, dash=[22, 'r']),
                                      dict(steer=320, dash=[16, 'r'])], walk=True)
    R.chain([320, 160], [424, 176], [dict(steer=290), dict(steer=424)], walk=True)
    R.dash([432, 176], [528, 160], up=True)
    R.reward(1, lambda: R.chain([120, 232], [320, 160], [
        dict(steer=170), dict(steer=240, dash=[22, 'r']), dict(steer=240, dash=[18, 'u']),
        dict(steer=320, dash=[16, 'r'])], walk=True))


def room_5(R):
    """ORCHARD OF CHOICES — a fork. LOW road: three crumbling stones in a row,
    no stopping. HIGH road (optional): a spring into the canopy, an up-dash past
    a circling thought, then a drop. One lemon on each road, so the choice is
    about which risk you prefer, not about the reward. Both roads rejoin at the
    terrace checkpoint. (`orchard_optional_test` walks both.)"""
    R.frame()
    R.spring(80, 288)
    R.ledge(104, 240, 56); R.spring(152, 240)
    R.crumble(192, 256); R.crumble(264, 248); R.crumble(336, 256)
    R.ledge(176, 184, 48)
    R.thought(248, 148, 'Circle', 14, 0.3, 0.0)
    R.ledge(272, 152, 32)
    R.ledge(344, 176, 40)
    R.ledge(408, 232, 64); R.checkpoint(440, 232, 'terrace')
    R.ledge(512, 216, 32)
    R.ledge(584, 200, 56)
    R.lemon(304, 228); R.lemon(316, 128)
    R.branch_fruit = True
    R.bounce([80, 288], [128, 240])
    R.dash([128, 240], [208, 256], up=False)
    R.dash([208, 256], [280, 248], up=False)
    R.dash([280, 248], [352, 256], up=False)
    R.dash([352, 256], [424, 232], up=True)
    R.dash([440, 232], [528, 216], up=True)
    R.dash([528, 216], [600, 200], up=True)
    R.bounce([152, 240], [200, 184], opt=True)
    R.chain([208, 184], [288, 152], [dict(steer=288, dash=[10, 'ur'])],
            wait=dict(thought=[248, 148], window=[0.1, 0.2]), opt=True)
    R.dash([288, 152], [360, 176], up=False, opt=True)
    R.jump([376, 176], [424, 232], opt=True)


def room_6(R):
    """SILK IN THE WIND — carpets through MOVING gates. The first gate drifts
    slowly and alone; the second and third drift out of phase with each other,
    so the gap you are following hands you over to one going the other way.
    Rest on the island, then spring onto the second rug for a circling thought
    at the summit."""
    R.frame()
    R.spring(80, 288)
    R.ledge(104, 240, 56)
    R.carpet(192, 240, 48, 40)
    R.gate(280, 216, 10, 16, 0.15, 0.0)
    R.gate(360, 192, 10, 18, 0.2, 0.5)
    R.ledge(408, 184, 64); R.checkpoint(432, 184, 'island'); R.spring(456, 184)
    R.carpet(504, 136, 48, 40)
    R.gate(544, 136, 12, 10, 0.2, 0.25)
    R.ledge(584, 104, 56)
    R.lemon(328, 186); R.lemon(456, 96)
    R.bounce([80, 288], [128, 240])
    R.flight(192, [144, 240], [[280, 216, 280], [320, 200], [360, 192, 360]], [432, 184], 384)
    R.bounce([456, 184], [504, 136])
    R.flight(504, None, [[544, 136, 544], [580, 136]], [616, 104], 572)
    R.reward(1, lambda: R.flight(192, [144, 240], [[280, 216, 280], [304, 190], [360, 192, 360]],
                                 [432, 184], 384))
    R.reward(2, lambda: R.chain([432, 184], [504, 136], [dict(steer=470), dict(steer=456, dash=[24, 'u']),
                                                          dict(steer=504)], walk=True))


def room_7(R):
    """THE GARDEN THRESHOLD — first exam. No spring to start: an up-dash. Two
    crumbling stones, a relay off a floating spring, then a rug through one
    drifting gate to a rest, and a final crumbling step to the door."""
    R.frame()
    R.ledge(120, 248, 48)
    R.crumble(208, 224); R.crumble(288, 232)
    R.ledge(352, 224, 64); R.checkpoint(376, 224, 'stones'); R.spring(400, 224)
    R.ledge(472, 216, 16, 24); R.spring(480, 216)
    R.ledge(536, 144, 48)
    R.carpet(608, 144, 40, 44)
    R.gate(648, 120, 10, 14, 0.25, 0.4)
    R.ledge(704, 104, 64); R.checkpoint(728, 104, 'summit')
    R.lemon(248, 192); R.lemon(480, 128)
    R.dash([80, 288], [136, 248], up=True, frame=16)
    R.dash([152, 248], [224, 224], up=True)
    R.dash([224, 224], [304, 232], up=False)
    R.dash([304, 232], [368, 224], up=False)
    R.chain([384, 224], [552, 144], [dict(steer=400), dict(steer=480, dash=[22, 'r']),
                                      dict(steer=552, dash=[20, 'ur'])], walk=True)
    R.flight(608, [568, 144], [[648, 120, 648]], [720, 104], 676)
    R.reward(4, lambda: R.chain([384, 224], [552, 144], [
        dict(steer=400), dict(steer=480, dash=[22, 'r']), dict(steer=480, dash=[18, 'u']),
        dict(steer=552, dash=[20, 'ur'])], walk=True))


def room_8(R):
    """GARDEN OF KINGS — the breather after the exam. Broad landings and a lazy
    rug. The dare: a spring at the island's far end throws him up to a lemon
    alcove that a slow circling thought keeps sweeping."""
    R.frame()
    R.spring(80, 288)
    R.ledge(112, 240, 56)
    R.carpet(208, 240, 56, 40)
    R.ledge(352, 160, 112); R.checkpoint(392, 160, 'kings')
    R.spring(456, 160)
    R.ledge(472, 96, 40)
    R.thought(492, 72, 'Circle', 18, 0.18, 0.0)
    R.ledge(488, 176, 64)
    R.ledge(584, 168, 56)
    R.lemon(492, 84); R.lemon(280, 150)
    R.bounce([80, 288], [128, 240])
    R.flight(208, [152, 240], [[288, 180], [336, 180]], [384, 160], 328)
    R.dash([432, 160], [512, 176], up=False)
    R.dash([536, 176], [616, 168], up=True)
    R.reward(1, lambda: R.flight(208, [152, 240], [[264, 158], [304, 180]], [384, 160], 328))
    R.reward(2, lambda: R.chain([432, 160], [492, 96], [dict(steer=456), dict(steer=492)], walk=True,
                                wait=dict(thought=[492, 72], window=[0.55, 0.65])),
             lambda: R.chain([496, 96], [520, 176], [dict(steer=520)], walk=True))

def room_9(R):
    """APEX RELAY — relays over the pit with a thorn roof that forbids the easy
    up-dash, then a crumbling descent onto a side spring whose flat throw is the
    only way under the second roof."""
    R.frame()
    R.spring(80, 288)
    R.crumble(128, 216, 56)
    R.ledge(240, 232, 16, 24); R.spring(248, 232)
    R.ledge(336, 216, 16, 24); R.spring(344, 216)
    R.thorns(216, 120, 152)
    R.ledge(408, 176, 64); R.checkpoint(432, 176, 'relay')
    R.crumble(504, 152); R.crumble(584, 168)
    R.ledge(648, 144, 48); R.side_spring(652, 144, 'Right')
    R.thorns(696, 112, 72)
    R.ledge(768, 184, 40)
    R.ledge(824, 168, 56)
    R.thought(488, 150, 'Vertical', 22, 0.3, 0.0)
    R.lemon(384, 112); R.lemon(720, 136)
    R.spring_dash([80, 288], [160, 216], 18)
    R.chain([160, 216], [424, 176], [dict(steer=248, dash=[14, 'r']), dict(steer=344, dash=[20, 'r']),
                                      dict(steer=424, dash=[20, 'r'])])
    R.chain([456, 176], [520, 152], [dict(steer=520, dash=[12, 'ur'])],
            wait=dict(thought=[488, 150], window=[0.1, 0.2]))
    R.dash([520, 152], [600, 168], up=False)
    R.dash([600, 168], [672, 144], up=True)
    R.chain([680, 144], [784, 184], [dict(steer=640), dict(steer=784)], walk=True)
    R.dash([792, 184], [856, 168], up=True)
    R.reward(2, lambda: R.chain([416, 176], [424, 176], [dict(steer=398, dash=[14, 'u'], steer_after=424)]),
             lambda: R.chain([456, 176], [520, 152], [dict(steer=520, dash=[12, 'ur'])],
                             wait=dict(thought=[488, 150], window=[0.1, 0.2])))


def room_10(R):
    """NEEDLEWIND PASSAGE — leave a fast rug, cross an island, catch the same
    rug on the far side, three times. The middle island rides HIGHER than the
    other two, so between passages there is a short open stretch to change lane
    in, and the rug does not slow down while you do it."""
    R.frame()
    R.spring(80, 288)
    R.ledge(112, 240, 56)
    R.carpet(200, 217, 24, 52)
    R.weave(200, [152, 240], [[272, 40, 216], [504, 48, 184], [744, 40, 216]], [912, 192], 864, 52)
    R.ledge(896, 192, 64); R.checkpoint(920, 192, 'needle'); R.spring(944, 192)
    R.ledge(1000, 120, 32)
    R.ledge(1056, 120, 64)
    R.lemon(392, 200); R.lemon(648, 196)
    R.bounce([80, 288], [128, 240])
    R.weave_route()
    R.spring_dash([944, 192], [1016, 120], 22)
    R.reward(1, lambda: R.weave_route(reward_lanes=[[376, 396, 206]]))
    R.dash([1016, 120], [1080, 120], up=False)


def room_11(R):
    """THE TURNING STAIR — up, then back down. A spring-dash to a floor ledge,
    then a two-wall chimney climbed by wall-jumps (Act 1's skill, now with a
    pit below the shaft's open bottom), out over the top to a rest, and a
    crumbling descent back down to the right before a spring-dash to the door.
    The lemon hangs above the chimney's mouth: one kick more than you need."""
    R.frame()
    R.spring(80, 288)
    R.ledge(128, 216, 120)
    R.solid(176, 56, 16, 128)
    R.solid(224, 128, 16, 88)
    R.ledge(240, 112, 72); R.checkpoint(272, 112, 'stair')
    R.crumble(360, 144); R.crumble(440, 168)
    R.ledge(512, 192, 56); R.checkpoint(528, 192, 'landing'); R.spring(552, 192)
    R.ledge(616, 128, 40)
    R.ledge(704, 112, 96)
    R.lemon(208, 40); R.lemon(400, 104)
    R.spring_dash([80, 288], [160, 216], 18)
    R.chain([208, 216], [272, 112], [dict(steer=170, wall=True), dict(steer=250, wall=True),
                                     dict(steer=170, wall=True), dict(steer=250, wall=True),
                                     dict(steer=170, wall=True), dict(steer=272)])
    R.dash([296, 112], [376, 144], up=False)
    R.dash([376, 144], [456, 168], up=False)
    R.dash([456, 168], [528, 192], up=False)
    R.spring_dash([552, 192], [632, 128], 20)
    R.dash([640, 128], [720, 112], up=True)
    chimney = [dict(steer=170, wall=True), dict(steer=250, wall=True), dict(steer=170, wall=True),
               dict(steer=250, wall=True), dict(steer=170, wall=True), dict(steer=272)]
    R.reward(1, lambda: R.chain([208, 216], [272, 112], chimney),
             lambda: R.chain([248, 112], [208, 216], [dict(steer=208, dash=[14, 'u'])]),
             lambda: R.chain([208, 216], [272, 112], chimney))


def room_12(R):
    """UNDER THE THORNS — a thorn roof low over three crumbling stones: a full
    jump off the middle one clips it, so hop. Then a spring under a thorn roof
    with one gap in it — the needle's eye — over a ledge where a full jump is
    fatal and only a hop is safe. Then a perch, and a ledge that a thought
    keeps dropping onto like a piston: land on its near edge, wait, go."""
    R.frame()
    R.spring(80, 288)
    R.ledge(112, 240, 56)
    R.crumble(208, 240); R.crumble(288, 224); R.crumble(368, 240)
    R.solid(184, 160, 248, 16); R.thorns(184, 176, 248)
    R.ledge(448, 224, 136); R.checkpoint(472, 224, 'eye'); R.spring(576, 224)
    R.solid(456, 168, 104, 8); R.thorns(456, 176, 104)
    R.ledge(592, 160, 48); R.thorns(592, 176, 48)
    R.ledge(680, 160, 32)
    R.ledge(752, 144, 40)
    R.thought(780, 112, 'Vertical', 18, 0.25, 0.0)
    R.crumble(824, 160)
    R.ledge(872, 176, 56)
    R.lemon(256, 194); R.lemon(724, 108)
    R.bounce([80, 288], [128, 240])
    R.dash([152, 240], [224, 240], up=False)
    R.dash([224, 240], [304, 224], up=False)
    R.dash([304, 224], [384, 240], up=False, hold=6)
    R.dash([384, 240], [464, 224], up=False)
    R.chain([512, 224], [616, 160], [dict(steer=600), dict(steer=616)], walk=True)
    R.dash([632, 160], [696, 160], up=False)
    R.dash([696, 160], [760, 144], up=False)
    R.chain([760, 144], [840, 160], [dict(steer=840, dash=[14, 'r'])],
            wait=dict(thought=[780, 112], window=[0.62, 0.75]))
    R.dash([840, 160], [896, 176], up=False)
    R.reward(2, lambda: R.chain([224, 240], [304, 224], [dict(steer=304, dash=[22, 'r'])]))
    R.reward(7, lambda: R.chain([696, 160], [760, 144], [dict(steer=760, dash=[12, 'ur'])]))


def room_13(R):
    """CROWN OF THE WIND — the finale. Phrase 1: a relay (room 4/9). Phrase 2:
    the rug weave (room 10) with a moving gate. Phrase 3: a thorn roof and a
    side spring (room 12/9), then crumbling stones to the door. A checkpoint
    between every phrase."""
    R.frame()
    R.spring(80, 288)
    R.crumble(128, 216, 56)
    R.ledge(232, 224, 16, 24); R.spring(240, 224)
    R.ledge(304, 216, 72); R.checkpoint(336, 216, 'crown')
    R.carpet(408, 217, 24, 56)
    R.weave(408, [360, 216], [[480, 40, 216], [680, 56, 192], [904, 40, 216]], [1072, 192], 1024, 56)
    R.ledge(1056, 192, 72); R.checkpoint(1080, 192, 'wind'); R.spring(1112, 192)
    R.ledge(1160, 136, 40); R.side_spring(1164, 136, 'Right')
    R.thorns(1200, 104, 56)
    R.ledge(1256, 176, 40)
    R.crumble(1320, 168)
    R.ledge(1392, 160, 56)
    R.lemon(200, 164); R.lemon(600, 180); R.lemon(1232, 128)
    R.spring_dash([80, 288], [160, 216], 18)
    R.chain([168, 216], [328, 216], [dict(steer=240, dash=[12, 'r']), dict(steer=328, dash=[22, 'r'])])
    R.weave_route()
    R.spring_dash([1112, 192], [1184, 136], 18)
    R.chain([1184, 136], [1272, 176], [dict(steer=1150), dict(steer=1272)], walk=True)
    R.dash([1280, 176], [1336, 168], up=True)
    R.dash([1336, 168], [1424, 160], up=True)
    R.reward(1, lambda: R.chain([168, 216], [328, 216], [dict(steer=240, dash=[10, 'ur']),
                                                          dict(steer=328, dash=[22, 'r'])]))
    R.reward(2, lambda: R.weave_route(reward_lanes=[[586, 612, 186]]))


ROOMS = {
    3: ('Saffron Steps', 192, room_3),
    4: ('The Spring Relay', 160, room_4),
    5: ('Orchard of Choices', 200, room_5),
    6: ('Silk in the Wind', 104, room_6),
    7: ('The Garden Threshold', 104, room_7),
    8: ('Garden of Kings', 168, room_8),
    9: ('Apex Relay', 168, room_9),
    10: ('Needlewind Passage', 120, room_10),
    11: ('The Turning Stair', 112, room_11),
    12: ('Under the Thorns', 176, room_12),
    13: ('Crown of the Wind', 160, room_13),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default=str(Path(__file__).resolve().parents[1]))
    ap.add_argument('--allow-open-editors', action='store_true',
                    help='only for a scratch copy of the project')
    args = ap.parse_args()
    root = Path(args.root)
    path = root / 'ldtk/hooshang_act2.ldtk'
    if not args.allow_open_editors:
        ps = subprocess.check_output(['ps', 'ax', '-o', 'command'], text=True)
        assert 'LDtk.app/Contents/MacOS/LDtk' not in ps, 'Close LDtk first (it rewrites the whole project on save)'
        assert not any(l.split() and l.split()[0].endswith('/MacOS/Godot') and '--editor' in l
                       for l in ps.splitlines()), 'Close the Godot editor first'
    raw = path.read_text()
    project = json.loads(raw)
    levels = {l['identifier']: l for l in project['levels']}
    before = {k: json.dumps(v, sort_keys=True) for k, v in levels.items()}
    coll = next(l for l in project['defs']['layers'] if l['identifier'] == 'Collisions')
    rules = [r for g in coll['autoRuleGroups'] if g['active'] for r in g['rules'] if r['active']]
    groups = {v['value']: v['groupUid'] for v in coll['intGridValues']}
    ink = next(l for l in project['defs']['layers'] if l['identifier'] == 'InkThoughtHazards')
    recipes = []
    for n, (title, end_y, build) in ROOMS.items():
        level = levels[f'Act_2_Level_{n}']
        assert level['pxHei'] == H, level['identifier']
        R = Room(project, level, title, end_y)
        build(R)
        # The exit landing runs to the room's right wall, so a return trip
        # from the next room always lands on solid ground.
        # It must also be at least 56px wide: walking back in from the next
        # room lands him ~21px inside the door (LdtkWorld._re_entry_point),
        # and a 40px ledge put that landing over the pit.
        assert any(x + w == R.W and y == end_y and w >= 56 for x, y, w in R.ledges), \
            (n, 'exit ledge must reach the wall and be >= 56px wide')
        recipes.append(R.finish(n))
        replace_spikes(level, ink)
        rebake_layer(R.layers['Collisions'], rules, groups)
    touched = {f'Act_2_Level_{n}' for n in ROOMS}
    for k, v in levels.items():
        if k not in touched:
            assert json.dumps(v, sort_keys=True) == before[k], f'{k} must not change'
    path.write_text(update(raw, project))
    (root / 'resources/levels/act2_expansion.json').write_text(json.dumps(recipes, indent=2) + '\n')
    print(f'Rebuilt {len(recipes)} garden rooms in {path}')


if __name__ == '__main__':
    main()
