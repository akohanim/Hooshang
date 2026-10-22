"""Act III's rooms, drawn. Built by tools/build_act3_world.py — read its Room
docstring for the legend. docs/act3/ACT3_DESIGN.md is the act; this is the
architecture.

Numbers the rooms are built against (adult Hooshang, tests/feel_measure.tscn,
Act III's sea profile in scripts/act3/sea_world.gd), px, a cell is 8:
  running jump      apex 34, reach 44    -> 3 rows up comfortable, 4 max; 4-col gap
  jump + dash       reach ~85            -> 8-col gap comfortable
  jump + up-dash    rise 49-83           -> 6 rows
  swim              62 px/s, any direction; neutral in deep water
  the Dive          ~55 px per Dive (215 px/s for 0.2s + drag), one per breath
  breach            Dive up through a surface: ~40 above it, air dash on top
  bell bounce       230 px/s up in water, 250 in air, refills both
Water (and a bell, and a bubble) refills the air dash.

Two rules the route proof taught (tests/act3_routes_test.tscn):
  - ONE Dive crosses a current at most 5 cells wide (55px, his own width included).
  - A room that NEEDS the Dive has a refill on its approach — a surface, a bubble
    or a bell reachable without diving — or a Dive wasted at the door is a soft-lock.
"""
from build_act3_world import Room

ROOMS = []

LID = 'x' * 40
SKY = 'x' + '.' * 38 + 'x'


def room(*args, **kw):
    r = Room(*args, **kw)
    ROOMS.append(r)
    return r


# ====================================================== I · THE INK SHORE ===
# Monochrome. Open sky (an invisible lid), the sea of lines on the horizon.

r = room('Act3_Level_0', 'The Tide', 1, (0, 0), [
    LID, SKY, SKY, SKY, SKY, SKY, SKY, SKY, SKY, SKY, SKY,
    'x...........................o..........x',
    SKY,
    SKY,
    'x..........................###..........',
    'x..........................###..........',
    'x..........gg..............###..........',
    'x.........gggg.......###...###..........',
    'x.P......gggggg......###...###....R.....',
    'gggggggggggggggggg~~~~gggggggggggggggggg',
    'gggggggggggggggggg~~~~gggggggggggggggggg',
    'gggggggggggggggggg~~~~gggggggggggggggggg',
    'g' * 40,
    'g' * 40,
], horizon=76)
r.set('R', {'text': ''})  # the meeting is staged by act3_beats.gd
r.mark('Wall', 6, 18)
r.mark('Rumi', 34, 18)
r.chain = ['wake on the shore', 'over the dune', 'hop the tide pool onto the low rock',
           'jump up the high rock (lemon above it)', 'down to Rumi at the water\'s edge', 'walk on']
r.step((2, 19), (6, 19), ('walk',))
r.step((6, 19), (11, 16))
r.step((11, 16), (17, 19), ('walk',))
r.step((17, 19), (22, 17))
r.step((22, 17), (28, 14))
r.step((28, 14), (34, 19), ('walk',))
r.step((34, 19), {'portal': 'Act3_Level_1'}, ('walk',), steer=41)

r = room('Act3_Level_1', 'Tide Pools', 1, (320, 0), [
    LID, SKY, SKY, SKY, SKY, SKY, SKY, SKY, SKY, SKY, SKY, SKY,
    SKY,
    'x...................o..................x',
    '.' * 40,
    '...........................G............',
    '.' * 40,
    '.' * 40,
    '.' * 40,
    'gggggggg##~~~~~~~~~ggg~~~~~~~~~~##gggggg',
    'gggggggg##~~~~~~~~~ggg~~~~~~~~~~##gggggg',
    'gggggggg##~~~~~~~~~ggg~~~~~~~~~~##gggggg',
    'gggggggg##~~~~~~~~~ggg~~~~~~~~~~##gggggg',
    'g' * 40,
], horizon=76)
r.set('G', {'motion': 'Horizontal', 'amp': 20.0, 'speed': 0.22})
r.chain = ['onto the rock', 'into the first pool, swim, climb out on the middle rock',
           'the second pool under the drifting thought', 'climb out, walk on']
r.step((3, 19), ('w', 14, 20, 40), ('walk', 'jump'), steer=14)
r.step(('w', 14, 20), (20, 19), ('swim',))
r.step((20, 19), ('w', 26, 20, 40), ('walk', 'jump'), steer=26)
r.step(('w', 26, 20), (33, 19), ('swim',))
r.step((33, 19), {'portal': 'Act3_Level_2'}, ('walk',), steer=41)

r = room('Act3_Level_2', 'The Pier', 1, (640, 0), [
    LID, SKY, SKY, SKY, SKY, SKY, SKY, SKY, SKY, SKY,
    'x.......................................',
    'x.................o.....................',
    'x.......................................',
    'x...............................T.......',
    '.' * 40,
    '.' * 40,
    '.' * 40,
    '........ssssssssH.....cccc...=======H...',
    '.........s....s.H..............s..s.H...',
    'gggggggg.s....s.H..............s..s.H...',
    'gggggggg.s....s.H..............s..s.H...',
    'gggggggg.s....s.H..............s..s.H...',
    'gggggggg.s....s................s..s.....',
    'g' * 40,
], water=19, horizon=76)
r.set('T', {'motion': 'Vertical', 'amp': 8.0, 'speed': 0.35})
r.chain = ['step up onto the pier', 'jump + dash the broken span (lemon above it)',
           'over the crumbling boards without stopping', 'hop to the planks, low under the thought',
           'off the end of the pier']
r.notes = ['Fall in and the ladders take you back up to the deck.']
r.step((4, 19), (10, 17))
r.step((14, 17), (23, 17), dash=('r',))
r.step((23, 17), (31, 17), hurry=True)
r.step((31, 17), (35, 17), ('walk',))
r.step((35, 17), {'portal': 'Act3_Level_3'}, ('walk',), steer=41)

r = room('Act3_Level_3', 'The Shelf', 1, (960, 0), [
    LID,
    'x......................................#',
    'x......................................#',
    'x......................................#',
    'x......................................#',
    'x......................................#',
    'x......................................#',
    'x......................................#',
    'x......................................#',
    'x......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    'g......................................#',
    'gg.....................................#',
    'gggg..................................##',
    'ggggg.................................##',
    'gggggg................................##',
    'gggggg.........G......................##',
    'ggggggg..............................###',
    'gggggggg.............................###',
    'ggggggggg...........................####',
    'gggggggggg..........................####',
    'ggggggggggg........................#####',
    'gggggggggggg.......................#####',
    'ggggggggggggg......................#####',
    'gggggggggggggg....................######',
    'ggggggggggggggg..........G........######',
    'ggggggggggggggg...................######',
    'gggggggggggggggg..................######',
    'gggggggggggggggg.o...............#######',
    'ggggggggggggggggg................#######',
    'gggggggggggggggggg..............########',
    'gggggggggggggggggg..............########',
    'ggggggggggggggggggg.............########',
    'gggggggggggggggggggg............########',
    'ggggggggggggggggggggg..........#########',
    'gggggggggggggggggggggg........##########',
], water=19, horizon=76)
r.set('G', {'motion': 'Horizontal', 'amp': 32.0, 'speed': 0.2},
      {'motion': 'Horizontal', 'amp': 24.0, 'speed': 0.2, 'phase': 0.5})
r.mark('Colour', 20, 30)
r.chain = ['off the pier into the sea', 'down past the drifting thoughts — the first colour',
           'through the floor']
r.step(('w', 4, 21), {'portal': 'Act3_Level_4'}, ('swim',),
       path=[(14, 24), (24, 33), (24, 41), (25, 46)], wait=300)


# ======================================================= II · THE SHALLOWS ===
# Under the surface now. Indigo. The Dive.

r = room('Act3_Level_4', 'The Gift', 2, (960, 384), [
    '######################........##########',
    '####################............########',
    '##################................######',
    '################....................####',
    '##############........................##',
    '#############..........................#',
    '############......................o.....',
    '###########.............................',
    '##########..............b.R.............',
    '##########..............................',
    '##########..............................',
    '##########..............................',
    '##########.................#############',
    '##########.................#############',
    '###########................#############',
    '############...............#############',
    '#############..............#############',
    '##############.............#############',
    '###############............#############',
    'gggggggggggggggggggggggggggg############',
    '#' * 40, '#' * 40, '#' * 40, '#' * 40,
], water=0)
r.set('R', {'text': '', 'w': 96})
r.current(32, 6, 35, 11, -125, 0)  # 4 cells: one Dive crosses <= 5 (55px incl. his width)
r.mark('Rumi', 27, 8)
r.chain = ['drift down to Rumi', 'the gift: the Dive', 'Dive through the current to the right']
r.step(('w', 25, 2), ('w', 26, 9, 16), ('swim',))
r.step(('w', 26, 9), {'portal': 'Act3_Level_5'}, ('swim',), dive=('r',), path=[(30, 9), (40, 9)])

r = room('Act3_Level_5', 'Kelp', 2, (1280, 384), [
    '#' * 40,
    '#' * 40,
    '###################.....################',
    '###################..o..################',
    '###################.....################',
    '####################...#################',
    '.......vvvvvvvvvvvvv...vvvvvvvvvv.......',
    '.' * 40,
    '...b.........b.....b.....b.....b........',
    '.' * 40,
    '.' * 40,
    '...........^^^^^^.........^^^^^^........',
    'g' * 40,
    '#' * 40, '#' * 40, '#' * 40, '#' * 40, '#' * 40, '#' * 40, '#' * 40,
    '#' * 40, '#' * 40, '#' * 40, '#' * 40,
], water=0)
r.current(8, 6, 35, 11, -130, 0)
r.chain = ['the current runs against you', 'Dive, touch a bubble, Dive again — four bubbles',
           'out the far side']
r.notes = ['The calm pocket in the ceiling holds the lemon, and a rest.']
r.step(('w', 4, 9), {'portal': 'Act3_Level_6'}, ('divechain',), path=[(40, 9)])

r = room('Act3_Level_6', 'Currents', 2, (1600, 384), [
    '#' * 40,
    '#########....###########################',
    '#########....###########################',
    '#########....###########################',
    '#########..o.###########################',
    '#########....###########################',
    '...................###......###........#',
    '...................###......###........#',
    '.....b.............###......###........#',
    '...................###...b..###........#',
    '...................###......###........#',
    '...................###......###........#',
    '#########..............................#',
    '#########..............................#',
    '#########..............................#',
    '#########...........G........G..........',
    '#########...............................',
    '#########...............................',
    '#########...............................',
    '#########...............................',
    '#########^^^^......^^^......^^^.........',
    'g' * 40,
    '#' * 40, '#' * 40,
], water=0)
r.set('G', {'motion': 'Vertical', 'amp': 14.0, 'speed': 0.35},
      {'motion': 'Vertical', 'amp': 14.0, 'speed': 0.35, 'phase': 0.5})
r.current(9, 1, 12, 19, 0, 150)
r.current(13, 15, 38, 20, 120, 0)
r.chain = ['Dive across the falling water', 'down into the river under the first overhang',
           'up into the calm between them; wait for the thought', 'ride the river out']
r.step(('w', 3, 8), ('w', 16, 9, 16), ('swim',), dive=('r',))
r.step(('w', 16, 9), ('w', 25, 9, 16), ('swim',), path=[(17, 12.5), (24, 12.5), (25, 10)], wait=171)
r.step(('w', 25, 9), {'portal': 'Act3_Level_7'}, ('swim',), path=[(26, 12.5), (34, 12.5), (35, 17), (38, 17)], wait=171)

r = room('Act3_Level_7', 'Air Pockets', 2, (1920, 384), [
    '#' * 40,
    '#.................####.................#',
    '#.................####.................#',
    '#.................####..................',
    '#.................####..................',
    '#.................####..................',
    '#.................####..................',
    '#.................####..................',
    '#.........#####...####...........#######',
    '#.................####...###.....#######',
    '#.................####...........#######',
    '#.................####...........#######',
    '#.................####.................#',
    '#.................####.................#',
    '#.................####....#######......#',
    '..................####....#,,,,,#......#',
    '..........................#,,,,,#......#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '#......................................#',
    'g' * 40,
    '#' * 40,
], water=12)
# The cup sits two rows under the surface, not one: he floats 7px down, and with
# a single row of water over its top his feet caught the corner and the slower
# stroke (SeaWorld.apply_sea_movement) could not carry him across.
r.extra.append(('Lemon', (29 * 8 + 4, 15 * 8 + 4), (16, 16), {}))
r.chain = ['under the wall', 'surface on the far side', 'Dive up out of the water, dash up onto the high ledge']
r.notes = ['An upturned cup of rock holds air, and a lemon: swim under its rim and up.']
r.step(('w', 2, 17), ('w', 29, 12, 14), ('swim',), path=[(15, 17), (24, 17), (29, 12)])
r.step(('w', 29, 12), (35, 8, 12), ('float',), dive=('u', 'ur'), dash=('ur', 'u', 'r'))
r.step((35, 8), {'portal': 'Act3_Level_8'}, ('walk',), steer=41)

r = room('Act3_Level_8', 'The Drop-off', 2, (2240, 384), [
    '#' * 40,
    '#......................................#',
    '#......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    '######.................................#',
    '######.................................#',
] + ['#' + '.' * 38 + '#'] * 12 + [
    '#..................^^^^^^..............#',
    '#########################..............#',
    '#########################..............#',
    '#########################..............#',
    '#..............................G.......#',
    '#......................................#',
    '#....................................o.#',
    '#......................................#',
    '#..............^^^^^^..................#',
    '#..............#########################',
    '#..............#########################',
    '#..............#########################',
    '#......G...............................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#..................^^^^^^..............#',
    '#########################..............#',
    '#########################..............#',
    '#########################..............#',
    '#..............................G.......#',
    '#......................................#',
    '#......................................#',
    '##########....................##########',
    '##############............##############',
    '################........################',
], water=18)
r.set('G', {'motion': 'Horizontal', 'amp': 24.0, 'speed': 0.3},
      {'motion': 'Horizontal', 'amp': 24.0, 'speed': 0.3, 'phase': 0.5},
      {'motion': 'Horizontal', 'amp': 24.0, 'speed': 0.3, 'phase': 0.25})
# 29, not 45: currents he steers across are kept under his 40 px/s stroke.
r.current(1, 18, 38, 46, 0, 29)
r.chain = ['walk off the ledge into the deep', 'down the zigzag past three thoughts', 'into the wreck']
r.step((3, 8), ('w', 9, 19, 40), ('walk',), steer=12)
r.step(('w', 9, 19), {'portal': 'Act3_Level_9'}, ('swim',),
       path=[(30, 20), (37, 22), (37, 28), (13, 28), (13, 36), (37, 36), (37, 44), (20, 46)])


# ================================================= III · THE DROWNED OFFICE ===
# His office, lying on the sea floor. Teal, and the amber of old tubes.

r = room('Act3_Level_9', 'The Lobby', 3, (2240, 768), [
    '################........################',
    '################........################',
    'ssssssssssssssss........ssssssssssssssss',
    's....................................o.s',
    's......................................s',
    's......................................s',
    's......................................s',
    's...................R..................s',
    's......................................s',
    's......................................s',
    's......................................s',
    's......................................s',
    's......................................s',
    's......................................s',
    's......................................s',
    's.......................................',
    's.......................................',
    's.......m...............................',
    's.......................................',
    's.......................................',
    's.......................................',
    's' * 40,
    '#' * 40, '#' * 40,
], water=0)
r.set('R', {'text': '', 'w': 96})
r.set('m', {'kind': 'nameplate', 'lines': '(flat) Fifteen years at the same desk.\n'
            'They spelled my name wrong on this for six of them. I never said anything.'})
for x in (6, 16, 26):
    r.decor('tube', x, 4)
r.decor('desk', 8, 21)
r.decor('chair', 12, 21)
r.decor('cabinet', 32, 21)
r.decor('partition', 24, 21)
r.mark('Rumi', 20, 7)
r.chain = ['down through the roof', 'Rumi: "You brought it with you."', 'the name plate', 'on through the lobby']
r.step(('w', 20, 2), ('w', 9, 17, 14), ('swim',))
r.step(('w', 9, 17), {'portal': 'Act3_Level_10'}, ('swim',), path=[(30, 17), (40, 17)])

r = room('Act3_Level_10', 'Cubicles', 3, (2560, 768), [
    '#' * 40,
    's' * 40,
    's......................................s',
    's......................................s',
    's......................................s',
    's......................................s',
    's.....s.....s.....s.....s.....s........s',
    's.....s.....s..o..s.....s.....s........s',
    's.....s.....s.....s.....s.....s........s',
    's.....s.....s.....s.....s.....s........s',
    's.....s.....s.....s.....s.....s........s',
    's......................................s',
    's...ssssssssssssssssssssssssssssssss...s',
    's........T................T............s',
    's......................................s',
    '......s.....s.....s.....s.....s.........',
    '......s.....s.....s.....s.....s.........',
    '......s.....s.....s.....s.....s.........',
    '......s.....s..m..s.....s.....s.........',
    '......s.....s.....s.....s.....s.........',
    '......s.....s.....s.....s.....s.........',
    's' * 40,
    '#' * 40, '#' * 40,
], water=0)
# 26, not 32: at 32 the second thought's 12px kill box reached 2.5px into the
# column-21 turn, a "safe" cubicle mouth that killed a player who took it. At 26
# the safe turns (15, 21) clear by 3.5px and the timed ones (9, 27) still sit
# inside a sweep.
r.set('T', {'motion': 'Horizontal', 'amp': 26.0, 'speed': 0.16},
      {'motion': 'Horizontal', 'amp': 26.0, 'speed': 0.16, 'phase': 0.5})
r.set('m', {'kind': 'photo', 'lines': '(vulnerable) Two boys by a pond.\n'
            '(happy) We had the same haircut. His mother cut both. Badly.'})
for x in (9, 21, 33):
    r.decor('tube', x, 3)
r.decor('desk', 3, 21)
r.decor('chair', 21, 21)
r.decor('desk', 27, 21)
r.chain = ['the cubicles', 'the aisle above them, where the thoughts do their rounds',
           'duck into a cubicle as one passes', 'the photograph', 'out the far side']
# Cubicle to cubicle: up into the aisle, over one partition, down again —
# each hop timed against the thought on its rounds.
for a, b in ((3, 9), (9, 15), (15, 21), (21, 27), (27, 34)):
    r.step(('w', a, 18), ('w', b, 18, 10), ('swim',), path=[(a, 14), (b, 14), (b, 18)], wait=375)
r.step(('w', 34, 18), {'portal': 'Act3_Level_11'}, ('swim',), path=[(38, 18)])

r = room('Act3_Level_11', 'The Flooded Stair', 3, (2880, 768), [
    '#' * 40,
    's' * 40,
    's......................................s',
    's......................................s',
    's.............ccc..ccc..ccc............s',
    's..........m...........................s',
    's.........sss..........................s',
    's......................................s',
    's.....sss.........sss..............o...s',
    's.................sss..................s',
    's.................sss..................s',
    's.................sss..................s',
    's.................sss..................s',
    's.................sss..................s',
    's.................sss..................s',
    '..................sss...................',
    '..................sss...................',
    '..................sss...................',
    '..................sss...................',
    '..................sss...................',
    '..................sss...................',
    's' * 40,
    '#' * 40, '#' * 40,
], water=12)
r.set('m', {'kind': 'ticket', 'lines': '(hesitant) Tehran. I had the ticket. I packed.\n'
            '(vulnerable) I sat by the door with my coat on, all night.\n'
            '(flat) In the morning I took my coat off.'})
for x in (5, 30):
    r.decor('tube', x, 3)
r.decor('cabinet', 29, 21)
r.chain = ['surface under the stair', 'Dive up out of the water onto the first landing',
           'up the stair (the ticket)', 'across the loose ceiling panels', 'down into the water beyond the wall']
r.step(('w', 2, 16), ('w', 4, 12, 16), ('swim',))
r.step(('w', 4, 12), (7, 8, 10), ('float',), dive=('u', 'ur'), dash=('ur', 'u'))
r.step((7, 8), (11, 6))
r.step((11, 6), (15, 4))
r.step((15, 4), (20, 4), hurry=True)
r.step((20, 4), (25, 4), hurry=True)
r.step((25, 4), ('w', 28, 13, 24), ('walk',), steer=28)
r.step(('w', 28, 13), {'portal': 'Act3_Level_12'}, ('swim',), path=[(38, 17), (40, 17)])

r = room('Act3_Level_12', 'The Dark Floor', 3, (3200, 768), [
    '#' * 40,
    's' * 40,
    's......................................s',
    's.......................................',
    's...........T...........................',
    's.......................................',
    's.......................................',
    's.......................................',
    's.......................................',
    's........sssssssssssssssssssssssssssssss',
    's......................................s',
    's.o....................................s',
    's...................T..................s',
    's......................................s',
    'sssssssssssssssssssssssssssssss........s',
    '.......................................s',
    '.......................................s',
    '..............m..........T.............s',
    '.......................................s',
    '.......................................s',
    '.......................................s',
    's' * 40,
    '#' * 40, '#' * 40,
], water=0)
r.set('T', {'motion': 'Horizontal', 'amp': 28.0, 'speed': 0.2},
      {'motion': 'Horizontal', 'amp': 44.0, 'speed': 0.2},
      {'motion': 'Vertical', 'amp': 14.0, 'speed': 0.2})
r.set('m', {'kind': 'letter', 'lines': '(hesitant) "Dear Khaleh. I don\'t know how to begin this."\n'
            '(flat) I began it nine times.'})
r.decor('desk', 6, 21)
r.decor('desk', 30, 21)
r.decor('cabinet', 20, 21)
r.decor('desk', 14, 14)
r.decor('cabinet', 33, 9)
r.mark('Shadow', 30, 11)
r.chain = ['the lights are out', 'along the bottom floor (the letter)', 'up at the end',
           'back along the middle floor, the shadow watching', 'up and out at the top']
# Past the letter, then UNDER the thought: it sweeps the middle of this 6-row
# lane, so the straight line through it only got by on drift. A player drops
# into the 24px of clear water below it.
r.step(('w', 2, 17), ('w', 34, 17, 16), ('swim',), path=[(14, 17), (17, 19), (33, 19), (34, 17)], wait=300)
r.step(('w', 34, 17), ('w', 4, 10, 16), ('swim',), path=[(35, 10), (4, 10)], wait=300)
r.step(('w', 4, 10), {'portal': 'Act3_Level_13'}, ('swim',), path=[(4, 7), (38, 7)], wait=300)

r = room('Act3_Level_13', 'The Lift Shaft', 3, (3520, 768), [
    '#' * 40,
    '########ssssssssssssssssssssssss########',
    '########s......................s########',
    '..............................os########',
    '...............................s########',
    '...............................s########',
    '...............................s########',
    '...............................s########',
    '...............................s########',
    'sssssssss......................s########',
    '########s......................s########',
    '########s......................s########',
    '########s......................s########',
    '########s.....................<s########',
    '########ssssssssssss..........<s########',
    '########s.....................<s########',
    '########s.....................<s########',
    '########s...........b.........<s########',
    '########s................G....<s########',
    '########s.....................<s########',
    '########s>.....................s########',
    '########s>.....................s########',
    '########s>.........sssssssssssss########',
    '########s>.....................s########',
    '########s>.....................s########',
    '########s>.....G...............s########',
    '########s>.........b...........s########',
    '########s......................s########',
    '########s.....................<s########',
    '########s.....................<s########',
    '########ssssssssssss..........<s########',
    '########s.....................<s########',
    '########s.....................<s########',
    '########s................G....<s########',
    '########s.....................<s########',
    '########s>.....................s########',
    '########s>.....................s########',
    '########s>.........sssssssssssss########',
    '########s>.....................s########',
    '########s>.....................s########',
    '########s>.....G...............s########',
    '########s......................s########',
    '########s......................s########',
    '########s.....R................s########',
    '########s......................s########',
    '########s...........m..........s########',
    '########s......................s########',
    '########ssssss............ssssss########',
], water=0)
r.set('G', {'motion': 'Horizontal', 'amp': 20.0, 'speed': 0.3},
      {'motion': 'Horizontal', 'amp': 20.0, 'speed': 0.3, 'phase': 0.5},
      {'motion': 'Horizontal', 'amp': 20.0, 'speed': 0.3},
      {'motion': 'Horizontal', 'amp': 20.0, 'speed': 0.3, 'phase': 0.5})
r.set('R', {'text': ''})
r.set('m', {'kind': 'can', 'lines': ''})
r.current(9, 10, 30, 41, 0, 40)
r.mark('Rumi', 14, 43)
r.chain = ['into the lift shaft', 'down past the broken cars and the spiked walls', 'the spray can, at the bottom',
           'Rumi: "Everything except the years."', 'down and out of the building']
# Down the shaft from pocket to pocket — above car A, then the dead water
# beside each car — each leg timed past the one thought it crosses.
r.step(('w', 3, 5), ('w', 14, 12, 12), ('swim',), path=[(14, 8), (14, 12)])
r.step(('w', 14, 12), ('w', 14, 20, 12), ('swim',), path=[(23, 12), (23, 20), (14, 20)], wait=200)
r.step(('w', 14, 20), ('w', 24, 28, 12), ('swim',), path=[(13, 21), (13, 28), (24, 28)], wait=200)
r.step(('w', 24, 28), ('w', 14, 36, 12), ('swim',), path=[(24, 36), (14, 36)], wait=200)
r.step(('w', 14, 36), ('w', 20, 45, 16), ('swim',), path=[(13, 37), (13, 44), (20, 45)], wait=200)
r.step(('w', 20, 45), {'portal': 'Act3_Level_14'}, ('swim',), path=[(20, 48)])


# ================================================ IV · THE REEF OF LANTERNS ===
# Below the wreck the sea begins to glow. Jellyfish.

r = room('Act3_Level_14', 'First Light', 4, (3520, 1152), [
    '##############............##############',
    '############................############',
    '##########....................##########',
    '########........................########',
    '#######..o.....................#########',
    '#######........................#########',
    '#######........................#########',
    '#######.........R..............#########',
    '#######........................#########',
    '#######........................#########',
    '#######.................................',
    '#######.................................',
    '#######.....................b...........',
    '#######.................................',
    '#######...........................j..j..',
    '#######.................................',
    '#######........................#########',
    '#######........................#########',
    '#######........................#########',
    '#######........................#########',
    '#######gggggggggggggggggggggggg#########',
    '#' * 40, '#' * 40, '#' * 40,
], water=0)
r.set('R', {'text': '', 'w': 112})
r.set('j', {'motion': 'Vertical', 'amp': 3.0, 'speed': 0.3},
      {'motion': 'Vertical', 'amp': 3.0, 'speed': 0.3, 'phase': 0.5})
r.current(31, 10, 39, 15, -130, 0)
r.mark('Rumi', 16, 7)
r.chain = ['down into the glow', 'Rumi: "These, jaan, you may also land on."',
           'Dive into the current, a bell, Dive again']
r.step(('w', 20, 2), ('w', 26, 12.6, 16), ('swim',))
r.step(('w', 26, 12.6), {'portal': 'Act3_Level_15'}, ('divechain',), path=[(30, 12.6), (39, 12.6)], wait=200)

r = room('Act3_Level_15', 'Lantern Coral', 4, (3840, 1152), [
    '#' * 40,
    '#......................................#',
    '#......................................#',
    '#...................o..................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '.' * 40,
    '.' * 40,
    '....b...........j.........j.............',
    '.' * 40,
    '.....................j.........j........',
    '.' * 40,
    '########........................########',
    '########........................########',
    '########........................########',
    '########........................########',
    '########^^^^^^^^^^^^^^^^^^^^^^^^########',
    '#' * 40, '#' * 40, '#' * 40,
], water=0)
r.set('j', {'motion': 'Vertical', 'amp': 6.0, 'speed': 0.3},
      {'motion': 'Vertical', 'amp': 6.0, 'speed': 0.3, 'phase': 0.25},
      {'motion': 'Vertical', 'amp': 6.0, 'speed': 0.3, 'phase': 0.5},
      {'motion': 'Vertical', 'amp': 6.0, 'speed': 0.3, 'phase': 0.75})
r.current(8, 1, 31, 19, 0, 95)
r.chain = ['the water here sinks toward the coral spikes', 'Dive to a bell, bounce, Dive to the next — four of them',
           'land on the far shelf']
r.step(('w', 5, 13), {'portal': 'Act3_Level_16'}, ('divechain',),
       path=[(16, 9.5), (21, 11.5), (26, 9.5), (31, 11.5), (36, 11), (39, 12)], wait=200)

r = room('Act3_Level_16', 'Bubble Garden', 4, (4160, 1152), [
    '#' * 40,
    '#..........b.........b.................#',
    '#...............o......................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#..........................j...........#',
    '#......................................#',
    '#...............j......................#',
    '#......................................#',
    '.' * 40,
    '.' * 40,
    '...b....................................',
    '.' * 40,
    '.' * 40,
    '.' * 40,
    '######..........................########',
    '######..........................########',
    '######..........................########',
    '######^^^^^^^^^^^^^^^^^^^^^^^^^^########',
    '#' * 40, '#' * 40, '#' * 40, '#' * 40,
], water=0)
r.set('j', {'motion': 'Horizontal', 'amp': 10.0, 'speed': 0.25},
      {'motion': 'Horizontal', 'amp': 12.0, 'speed': 0.25})
r.current(6, 1, 31, 18, 0, 80)
r.current(10, 1, 12, 18, 0, -200)
r.current(20, 1, 22, 18, 0, -200)
r.chain = ['sinking water over coral spikes', 'ride the first bubble column up', 'Dive across to the second',
           'ride it up, then down onto the far shelf']
r.step(('w', 3, 13), ('w', 11, 4, 24), ('swim',), dive=('r',), path=[(11, 12), (11, 4)])
r.step(('w', 11, 4), ('w', 21, 4, 24), ('swim',), dive=('r',), path=[(21, 4)])
r.step(('w', 21, 4), {'portal': 'Act3_Level_17'}, ('swim',), dive=('dr', 'r'), path=[(34, 14), (40, 13)])

r = room('Act3_Level_17', 'Whale Fall', 4, (4480, 1152), [
    '#' * 40,
    '####................................####',
    '##...................o................##',
    '##....................................##',
    '##................####................##',
    '##................####..=======.......##',
    '##......=======...####................##',
    '##................####................##',
    '#.................####.................#',
    '#.................####.................#',
    '..................####..................',
    '..................####..................',
    '..................####..................',
    '........j.........####..........j.......',
    '..................####..................',
    '..................####..................',
    '#.................####.................#',
    '#.................####.................#',
    '#.................####.................#',
    '#.................####.................#',
    '#gggggggggggggggggggggggggggggggggggggg#',
    '#' * 40, '#' * 40, '#' * 40,
], water=8)
r.set('j', {'motion': 'Vertical', 'amp': 10.0, 'speed': 0.25},
      {'motion': 'Vertical', 'amp': 10.0, 'speed': 0.25, 'phase': 0.5})
r.decor('skull', 6, 20)
for x in (10, 14, 26, 30, 34):
    r.decor('rib', x, 20)
r.chain = ['the whale\'s ribs hold a dome of air', 'surface, Dive up onto a rib', 'jump the reef wall to the far rib',
           'down into the water, on']
r.step(('w', 2, 13), ('w', 11, 8, 16), ('swim',))
r.step(('w', 11, 8), (11, 6, 12), ('float',), dive=('u', 'ur', 'ul'))
r.step((13, 6), (26, 5, 16), dash=('r', 'ur'))
r.step((29, 5), ('w', 34, 9, 32), ('walk',), steer=34)
r.step(('w', 34, 9), {'portal': 'Act3_Level_18'}, ('swim',), path=[(38, 12), (40, 12)])

r = room('Act3_Level_18', 'The Edge', 4, (4800, 1152), [
    '#' * 40,
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#...................R..................#',
    '#......................................#',
    '.......................................#',
    '.......................................#',
    '.....................................o.#',
    '.......................................#',
    '.......................................#',
    '.......................................#',
    'ggggggggg......................ggggggggg',
    '#########......................#########',
    '#########......................#########',
    '#########......................#########',
    '############................############',
    '############................############',
    '############................############',
    '############................############',
], water=0)
r.set('R', {'text': '', 'w': 80})
r.mark('Rumi', 20, 8)
r.chain = ['the reef ends', 'Rumi: "From here, you go alone."', 'down into the trench']
r.step(('w', 2, 13), ('w', 19, 11, 16), ('swim',))
r.step(('w', 19, 11), {'portal': 'Act3_Level_19'}, ('swim',), path=[(20, 18), (20, 24)])


# =================================================== V · THE FLOOR OF LIGHT ===
# The trench. The ink. The floor, gold and white.

def trench(name, title, pos, top, bottom, shelves, ink, bubbles=(), jellies=()):
    """A chase room: a 20-cell trench (cols 10-29) with shelves leaving short
    zigzags, so the dive reads as DOWN with a step aside at each shelf — the
    ink is above and a long crossing is how it catches you."""
    rows = []
    for y in range(48):
        if y == 0:
            rows.append(''.join('.' if top[0] <= x <= top[1] else '#' for x in range(40)))
        elif y == 47:
            rows.append(''.join('.' if bottom[0] <= x <= bottom[1] else '#' for x in range(40)))
        else:
            rows.append('#' * 10 + '.' * 20 + '#' * 10)
    grid = [list(r) for r in rows]
    for y0, x0, x1, spike_from, spike_to in shelves:
        for y in range(y0, y0 + 3):
            for x in range(x0, x1 + 1):
                grid[y][x] = '#'
        for x in range(spike_from, spike_to + 1):
            grid[y0 - 1][x] = '^'
    for x, y in bubbles:
        grid[y][x] = 'b'
    for x, y, _ in jellies:
        grid[y][x] = 'j'
    r = room(name, title, 5, pos, [''.join(row) for row in grid], water=0)
    if jellies:
        r.set('j', *[p for _, _, p in jellies])
    r.ink(*ink)
    r.decor_density = 0.5
    return r


r = trench('Act3_Level_19', 'The Trench', (4800, 1344), (12, 27), (10, 16),
           [(8, 10, 22, 18, 22), (18, 17, 29, 17, 21), (28, 10, 22, 18, 22), (38, 17, 29, 17, 21)],
           (20.0, 0.4), bubbles=[(26, 13), (13, 23), (26, 33), (13, 43)])
# The current and the ink were paced for a 62 px/s stroke; both are scaled by
# the same 40/62 as the stroke, so the chase keeps its shape.
r.current(10, 1, 29, 46, 0, 36)
r.chain = ['the ink pours in above', 'down the zigzag, never stopping', 'through the floor']
r.step(('w', 20, 2), {'portal': 'Act3_Level_20'}, ('swim', 'divechain'),
       path=[(26, 4), (26, 13), (13, 14), (13, 23), (26, 24), (26, 33), (13, 34), (13, 46)])

r = trench('Act3_Level_20', 'The Deep Trench', (4800, 1728), (10, 16), (10, 29),
           # Spikes on the far end of each shelf — the end you pass over high —
           # never under the drop you come down, where the current carries you on.
           [(7, 17, 29, 25, 29), (15, 10, 22, 18, 22), (23, 17, 29, 17, 21), (31, 10, 22, 18, 22),
            (39, 17, 29, 17, 21)],
           # The bells hang at the shelf lips: in a chase DOWN a bounce throws
           # you back up toward the ink, so these are for cutting corners into.
           (20.0, 0.4), bubbles=[(20, 11), (19, 19), (20, 27), (19, 35)],
           jellies=[(16, 8, {'motion': 'Vertical', 'amp': 3.0, 'speed': 0.3}),
                                 (23, 16, {'motion': 'Vertical', 'amp': 3.0, 'speed': 0.3, 'phase': 0.5}),
                                 (16, 24, {'motion': 'Vertical', 'amp': 3.0, 'speed': 0.3}),
                                 (23, 32, {'motion': 'Vertical', 'amp': 3.0, 'speed': 0.3, 'phase': 0.5})])
r.current(10, 1, 29, 46, 0, 29)
r.chain = ['faster now, and brighter', 'Dive bubble to bubble across each lane to stay ahead of the ink',
           'round the bells at the shelf lips', 'to the floor']
r.step(('w', 13, 2), {'portal': 'Act3_Level_21'}, ('swim', 'divechain'),
       path=[(12, 11.5), (27, 11.5), (27, 19.5), (12, 19.5), (12, 27.5), (27, 27.5), (27, 35.5), (12, 35.5), (12, 44), (20, 46)])

r = room('Act3_Level_21', 'The Floor of the Sea', 5, (4800, 2112), [
    '##########....................##########',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#.......................................',
    '#.......................................',
    '#.......................................',
    '#.......................................',
    '#.......................................',
    '#.......................................',
    '#.......................................',
    '#.....P.................................',
    'g' * 40,
    '#' * 40, '#' * 40, '#' * 40,
], water=0)
r.mark('Stand', 14, 19)
r.mark('Shadow', 30, 9)
for x, kind, h in ((4, 'lantern', 1), (9, 'seagrass', 1), (19, 'lantern', 1), (23, 'seagrass', 1),
                   (27, 'coral', 1), (33, 'lantern', 1), (36, 'seagrass', 1)):
    r.decor(kind, x, 20, h)
r.decor_density = 0.6
r.chain = ['the bottom', 'the shadow comes; the thoughts fill the water', 'be still', 'let it go']
r.step((6, 20), {'portal': 'Act3_Level_22'}, ('swim', 'walk'), path=[(30, 18), (40, 16)])

r = room('Act3_Level_22', 'The Pond at the Bottom of the Sea', 5, (5120, 2112), [
    '#' * 40,
    '#' * 40,
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#......................................#',
    '#...............,,,,,,,,...............#',
    '#.............,,,,,,,,,,,,.............#',
    '#............,,,,,,,,,,,,,,............#',
    '#...........,,,,,,,,,,,,,,,,...........#',
    '#...........,,,,,,,,,,,,,,,,...........#',
    '#...........,,,,,,,,,,,,,,,,...........#',
    '............,,,,,,,,,,,,,,,,............',
    '............,,,,,,,,,,,,,,,,............',
    '............,,,,,,,,,,,,,,,,............',
    '............ggggg......ggggg............',
    '............ggggg......ggggg............',
    '............ggggg......ggggg............',
    '............gggggggggggggggg............',
    '.' * 40,
    'g' * 40,
    '#' * 40, '#' * 40, '#' * 40,
], water=0)
for x in (12, 13, 26, 27):
    r.decor('reed', x, 15, 2)
r.mark('Jamshid', 14, 14)
r.mark('Hooshang', 16, 14)
r.mark('Line', 19, 15)
r.decor_density = 0.5
r.chain = ['a pond in the floor of the sea, with air above it', 'Jamshid, fishing', 'the pearl', 'go home']
r.step(('w', 3, 16), (14, 15, 12), ('swim',), path=[(10, 12), (14, 12)])
r.step((16, 15), {'portal': 'Act3_Level_23'}, ('walk', 'swim'), path=[(28, 13), (34, 16), (40, 16)])

r = room('Act3_Level_23', 'The Ascent', 5, (5440, 1920), [
    '#' * 40,
] + ['#' + '.' * 38 + '#'] * 35 + [
    '.' * 39 + '#',
] * 4 + ['...P' + '.' * 35 + '#'] + ['.' * 39 + '#'] * 3 + [
    '#' + '.' * 38 + '#',
    '#' + '.' * 38 + '#',
    'g' * 40,
    '#' * 40,
], water=0)
for x, y in ((20, 40), (23, 34), (18, 28), (22, 22), (17, 16), (20, 10)):
    r.extra.append(('Lemon', (x * 8 + 4, y * 8 + 4), (16, 16), {}))
r.current(1, 1, 38, 45, 0, -55)
r.mark('Top', 20, 3)
r.decor_density = 0.3
r.chain = ['up', 'up through the white']

r = room('Act3_Level_24', 'The Office at Dawn', 6, (6400, 0), [
    's' * 40,
] + ['s' + '.' * 38 + 's'] * 17 + ['s...P' + '.' * 34 + 's'] + [
    's' * 40,
] * 5, fixed_depth=0.0)
r.decor('desk', 6, 19)
r.decor('chair', 10, 19)
r.decor('partition', 14, 19)
r.decor('desk', 18, 19)
r.decor('partition', 22, 19)
r.decor('desk', 26, 19)
r.decor('cabinet', 31, 19)
for x in (6, 16, 26):
    r.decor('tube', x, 2)
r.mode = 'dawn'
r.mark('Wake', 5, 18)
r.mark('Box', 8, 18)
r.mark('Door', 36, 18)
r.decor_density = 0.0

r = room('Act3_Level_25', 'The Real Sea', 6, (7100, 0), [
    LID,
] + [SKY] * 12 + ['x' + '.' * 39] * 2 + ['x..P' + '.' * 36] + [
    # Open on the right since the way home: after the wave he walks on along
    # the shore (THE WAY HOME, SCRIPT.md).
    'gggggggggggggggg........................',
    'gggggggggggggggggggggg..................',
    'gggggggggggggggggggggggggggg............',
    'gggggggggggggggggggggggggggggggggg......',
    'g' * 40, 'g' * 40, 'g' * 40, 'g' * 40,
], horizon=96, fixed_depth=0.0)
r.mode = 'sunrise'
r.mark('Shoes', 12, 15)
r.mark('Water', 25, 16)
r.decor_density = 0.0
r.chain = ['down the sand to the water', 'the wave', 'on along the shore']
r.step((3, 16), {'portal': 'Act3_Level_26'}, ('walk',), steer=41)


# ======================================================== VI · THE WAY HOME ===
# He thinks he made it out. The land after the sea, in natural colour: two rooms
# of nothing but morning, then the tiger, the chase, and the vine (SCRIPT.md
# ELEVEN to THIRTEEN). Drawn from ground-height profiles: every column is open
# above its height and earth below it.

EARTH = (0.36, 0.25, 0.17)
GRASS = (0.56, 0.74, 0.30)


def land(profile, open_left, open_right, h=24, rock_from=None, walls=True):
    """Rows from a per-column ground height. `open_left`/`open_right` are the
    (first, last) rows left open in the side walls for the portals; the rest of
    each side is an invisible wall up to the ground. Below `rock_from` (a row)
    the ground is rock rather than earth."""
    assert len(profile) == 40, len(profile)
    rows = ['x' * 40]
    for y in range(1, h):
        row = []
        for c in range(40):
            if y >= profile[c]:
                row.append('#' if rock_from is not None and y >= rock_from else 'g')
            elif walls and c == 0 and not open_left[0] <= y <= open_left[1]:
                row.append('x')
            elif walls and c == 39 and not open_right[0] <= y <= open_right[1]:
                row.append('x')
            else:
                row.append('.')
        rows.append(''.join(row))
    return rows


def land_room(name, title, x, rows, backdrop, h=24):
    r = room(name, title, 7, (x, 0), rows, horizon=-1, fixed_depth=0.0)
    r.mode = 'land'
    r.terrain_fill, r.terrain_line = EARTH, GRASS
    r.backdrop = 'res://assets/act3/land/%s.png' % backdrop
    r.decor_density = 0.0
    return r


# Over the dunes: sand gives way to grass, the sea behind him.
r = land_room('Act3_Level_26', 'The Shore Road', 7420, land(
    [20] * 10 + [19] * 6 + [18] * 6 + [19] * 3 + [17] * 6 + [16] * 4 + [14] * 5,
    (13, 19), (8, 13)), 'shore_road')
r.terrain_fill, r.terrain_line = (0.62, 0.48, 0.30), GRASS
r.chain = ['up off the beach', 'over the dunes', 'onto the coast path']
r.step((2, 20), (8, 20), ('walk',))
r.step((8, 20), (11, 19))
r.step((11, 19), (14, 19), ('walk',))
r.step((14, 19), (17, 18))
r.step((17, 18), (20, 18), ('walk',))
r.step((20, 18), (23, 19), ('walk',))
r.step((23, 19), (26, 17))
r.step((26, 17), (30, 17), ('walk',))
r.step((30, 17), (32, 16))
r.step((32, 16), (34, 16), ('walk',))
r.step((34, 16), (36, 14))
r.step((36, 14), {'portal': 'Act3_Level_27'}, ('walk',), steer=41)

# The high meadow: long grass, poppies, one lemon tree on the brow of the hill.
r = land_room('Act3_Level_27', 'The High Meadow', 7740, land(
    [14] * 8 + [13] * 6 + [12] * 8 + [13] * 6 + [14] * 6 + [15] * 6,
    (8, 13), (9, 14)), 'high_meadow')
r.chain = ['up the meadow', 'past the lemon tree', 'down toward the tall grass']
r.step((2, 14), (6, 14), ('walk',))
r.step((6, 14), (9, 13))
r.step((9, 13), (12, 13), ('walk',))
r.step((12, 13), (15, 12))
r.step((15, 12), {'portal': 'Act3_Level_28'}, ('walk',), steer=41)

# The tall grass. The tiger steps out behind him (Act3Beats, scene "tiger").
r = land_room('Act3_Level_28', 'The Tall Grass', 8060, land(
    [15] * 14 + [16] * 8 + [15] * 6 + [16] * 12,
    (9, 14), (10, 15)), 'tall_grass')
r.mark('Tiger', 4, 14)
r.chain = ['into the tall grass', 'the tiger', 'run']
r.step((2, 15), (17, 16), ('walk',))
r.step((17, 16), (20, 16), ('walk',))
r.step((20, 16), (23, 15))
r.step((23, 15), {'portal': 'Act3_Level_29'}, ('walk',), steer=41)

# The wood: a fallen log to hop, a ditch, roots. Never stop.
r = land_room('Act3_Level_29', 'The Wood', 8380, land(
    [16] * 10 + [15] * 2 + [16] * 8 + [17] * 3 + [16] * 5 + [15] * 6 + [16] * 6,
    (10, 15), (10, 15)), 'wood')
r.terrain_fill = (0.27, 0.19, 0.14)
r.chain = ['over the log', 'over the ditch', 'up the roots', 'on']
r.step((2, 16), (8, 16), ('walk',))
r.step((8, 16), (13, 16))
r.step((13, 16), (19, 16), ('walk',))
r.step((19, 16), (24, 16))
r.step((24, 16), (27, 16), ('walk',))
r.step((27, 16), (30, 15))
r.step((30, 15), {'portal': 'Act3_Level_30'}, ('walk',), steer=41)

# The rocks: boulders on the headland, a crevice, the sea far below.
r = land_room('Act3_Level_30', 'The Rocks', 8700, land(
    [16] * 6 + [14] * 4 + [16] * 4 + [13] * 3 + [16] * 5 + [17] * 3 + [16] * 4 + [15] * 4 + [14] * 7,
    (10, 15), (8, 13)), 'rocks')
r.terrain_fill, r.terrain_line = (0.42, 0.40, 0.38), (0.62, 0.70, 0.40)
r.chain = ['up the first boulder', 'over the tall one', 'over the crevice', 'up to the edge of the land']
r.step((2, 16), (4, 16), ('walk',))
r.step((4, 16), (7, 14))
r.step((7, 14), (12, 16), ('walk',))
r.step((12, 16), (15, 13))
r.step((15, 13), (21, 16), ('walk',))
r.step((21, 16), (26, 16))
r.step((26, 16), (28, 16), ('walk',))
r.step((28, 16), (30, 15))
r.step((30, 15), (32, 15), ('walk',))
r.step((32, 15), (34, 14))
r.step((34, 14), {'portal': 'Act3_Level_31'}, ('walk',), steer=41)

# The edge. Two screens tall: the cliff top he runs along, the face he hangs
# from, the valley floor where the second tiger waits. The fall and the vine are
# staged (Act3Beats, scene "vine"); the markers place them.
edge = land([14] * 8 + [13] * 3 + [14] * 14 + [44] * 12 + [10] * 3, (8, 13), (0, 0), h=48, rock_from=18)
# Below its grassy top the cliff is PAINTED (tools/gen_act3_land_backdrops.py,
# edge()): strata, cracks, moss, the crack the mice live in. So the body is
# invisible solid here, collision unchanged, and so is the ravine's far wall.
for y in range(16, 48):
    row = list(edge[y])
    for x in range(40):
        if row[x] in 'g#' and not (y in (44, 45) and 25 <= x <= 36):
            row[x] = 'x'
    edge[y] = ''.join(row)
edge[44] = edge[44][:25] + 'g' * 12 + edge[44][37:]   # the valley floor is grass
edge[45] = edge[45][:25] + 'g' * 12 + edge[45][37:]
r = land_room('Act3_Level_31', 'The Edge', 9020, edge, 'edge', h=48)
r.terrain_fill, r.terrain_line = (0.45, 0.40, 0.36), (0.60, 0.72, 0.36)   # a rock face, grass on top
r.mark('Edge', 21, 13)
r.mark('VineRoot', 25, 16)
r.mark('Hang', 25, 27)
r.mark('Lemon', 23, 27)
r.mark('TigerAbove', 22, 13)
r.mark('TigerBelow', 31, 43)
r.chain = ['along the cliff top', 'the land runs out']
r.step((2, 14), (6, 14), ('walk',))
r.step((6, 14), (9, 13))
r.step((9, 13), (19, 14), ('walk',))
