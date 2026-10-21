# Act III — THE SEA

_Creative direction and design bible for World 3. The rooms themselves are DRAWN
in `tools/build_act3_world.py`; `docs/act3/act3_rooms.md` is generated from that
same data. The play text is `SCRIPT.md`'s ACT THREE section._

## The one idea

**Going down is going toward the light.**

Act I was the mind (thoughts are weather; stop watering the dark seed). Act II was
memory (Jamshid's hand; let go). Both ended with Hooshang lighter than he began.
What is left is the thing Act II's last scene could not answer — Jamshid asks
_"Is that why you came back?"_ after Hooshang says _"I wasted it. All that time."_
Act III is the answer: the sea underneath the office and the pond, where every
thing he ever kept has sunk, and underneath all of it, light.

Rumi promised it in Act I's first conversation: _"The office that swallowed your
years. Your childhood. And beneath them, the places and things you have never let
go of."_ Act III is the "beneath them".

The ocean brightens with depth — the reverse of a real sea — because that is what
the whole game has been saying: the way out is in.

## Look: from line to light

Two directions were on file and they are both kept, as the two ends of the act:

- **September's art direction** for Act III: monochrome psychedelia — white line on
  black, optical patterns, red-rimmed thoughts (`assets/act3/README.md`).
- **The design doc / CLAUDE.md**: a luminous ocean that brightens with depth.

So the act **opens in pure black and white** — a shore drawn in single white lines,
the existing Act 3 terrain exactly as approved — and **colour floods in as he
descends**, until the sea floor is gold and white. One palette, keyed to WORLD
DEPTH (absolute y), drives the backdrop, the terrain's two tones, the water and the
props, so the change is continuous across every room seam and during every slide.

| depth band | chapter | fill (terrain black) | line (terrain white) | mood |
|---|---|---|---|---|
| surface | I · The Ink Shore | black | white | silent, stark, wind |
| shallow | II · The Shallows | deep indigo | pale cyan | the first colour, a held breath |
| wreck | III · The Drowned Office | teal-green | sodium amber | his old office, under water |
| reef | IV · The Reef of Lanterns | violet-teal | coral / rose | bioluminescent, saturated |
| floor | V · The Floor of Light | pale gold | white | radiant, warm, still |

The **terrain atlas is unchanged** (`assets/act3/terrain.png`, brick / Grass /
Scaffolding brushes). A palette-map shader (`assets/shaders/act3_depth_tint.gdshader`)
recolours its black and white per pixel from the depth ramp. Read as: brick = rock,
Grass = seabed with sea-grass fringe, Scaffolding = pier / wreck / office frame.

The two epilogue rooms leave the ramp: the office at dawn (line art warming into
colour) and the real sea at sunrise — the only room in the game drawn in plain
natural colour.

## Hooshang

Old again, in his cardigan — the adult rig (`hooshang_frames.tres`), which already
has `swim`, `swim_idle` and `exit_water`. Act II made him a boy; Act III gives him
back his age, and lets the sea not care about it.

## Verbs

Everything from Acts I–II stays (run, jump, dash, wall-jump, swim, bank mantle).
Act III adds the sea's own:

| verb | what | where taught |
|---|---|---|
| **Sea swimming** | An old man's stroke, a little slower than the pond (`SeaWorld.apply_sea_movement`): 40 px/s, drawn side-on like the child's (`tools/build_adult_swim.lua`). Water **refills the air dash** (Celeste's rule; the prison already does it). | Ch I |
| **The Dive** | Rumi's Act III gift: **dash underwater**. A burst in any of 8 directions, one per breath, refilled by surfacing, landing or an air bubble. Dashing up through the surface breaches him high into the air — with his air dash ready. | Ch II, room 4 |
| **Currents** | Rivers in the sea (`Current`). Carry him while swimming; the Dive is how you cross one. Bubble columns are upward currents. | Ch II |
| **Air bubbles** | `AirBubble` — touch to refill the Dive and the dash; pops and comes back. The sea's refill crystal. | Ch II |
| **Jellyfish** | `Jellyfish` — drifting thought-hazards on DarkThought's paths. The **bell bounces** you and refills everything; the **tentacles kill**. Rumi: _"These, jaan, you may also land on."_ | Ch IV |
| **Memories** | `Memory` — the things he kept, floating in the wreck. Touch one and Hooshang remembers. No reward but the line. | Ch III |
| **The ink** | `InkFlood` — Darkshang pouring down the trench after him; a descending wall that only starts once he commits. | Ch V |
| **Stillness** | The finale. Thoughts fill the water; moving makes them sting, standing still lets them pass through and go out. | Ch V, room 21 |

Rules kept from the prison/Act II water: no oxygen meter, no drowning, hazards
read in the water exactly as in the air.

## Chapters and rooms

26 rooms, `Act3_Level_0`..`Act3_Level_25` (identifiers are play order). Rooms are
joined by EDGE APERTURES — an opening in one room's wall that meets an opening in
its neighbour's becomes a two-way portal (the prison's system, rebuilt for the sea
in `scripts/act3/sea_world.gd`). That is what lets the act go DOWN: most chapters
end by dropping through the floor into the room below.

### I · THE INK SHORE (surface, monochrome)
0. **The Tide** — the alley wall's paint runs into a sea; he wakes old on a shore of
   white lines; Rumi at the water's edge.
1. **Tide Pools** — first swims, pools between rock stacks, grey thoughts.
2. **The Pier** — a broken scaffold pier: crumbling planks, the first dashes.
3. **The Shelf** — under the waterline for the first time; down through the floor.

### II · THE SHALLOWS (indigo)
4. **The Gift** — Rumi in the water; the Dive.
5. **Kelp** — Dive through gaps; air bubbles.
6. **Currents** — ride them, cross them.
7. **Air Pockets** — breach, air-dash, splash down, again.
8. **The Drop-off** — a tall fall through currents to the wreck.

### III · THE DROWNED OFFICE (teal-green, amber)
9. **The Lobby** — "You brought it with you." The name plate.
10. **Cubicles** — a maze of partitions under water. The photograph.
11. **The Flooded Stair** — half air, half water; falling ceiling panels. The ticket.
12. **The Dark Floor** — where the shadow drifts. The letter.
13. **The Lift Shaft** — down and out through the bottom of the building. The can.

### IV · THE REEF OF LANTERNS (saturated, glowing)
14. **First Light** — the reef; jellyfish bells.
15. **Lantern Coral** — bounce chains in a current.
16. **Bubble Garden** — columns, bubbles, precise Dives.
17. **Whale Fall** — a cathedral of bone and an air pocket.
18. **The Edge** — "From here, you go alone."

### V · THE FLOOR OF LIGHT (gold, white)
19. **The Trench** — the ink pours down after him.
20. **The Deep Trench** — faster; brighter.
21. **The Floor of the Sea** — stillness. The shadow becomes his shadow.
22. **The Pond at the Bottom of the Sea** — Jamshid, fishing. The pearl. The bell.
23. **The Ascent** — up through the white.
24. **The Office at Dawn** — he wakes on the carpet; the way to the car.
25. **The Real Sea** — sunrise, every colour; he walks into the water.

## Sound

`tools/gen_act3_sea_music.py` synthesises the score (stdlib only, deterministic,
the `gen_act2_garden_music.py` recipe): **Shore** (sparse santur over surf, D
minor/Shur), **Deep** (slow pads, a rising arpeggio), **Reef** (bright bells, the
melody whole), **Trench** (a low pulse that quickens), **Floor** (one held chord,
then the theme in major), **Dawn** (the full theme, warm). See
`assets/music/README.md`.

## Engineering map

| piece | where |
|---|---|
| world runtime (portals, water, palette, refills) | `scripts/act3/sea_world.gd`, `ldtk/Act3World.tscn` |
| per-room geometry/water/backdrop (built on import) | `scenes/props/sea/SeaRoom.tscn`, `scripts/act3/sea_import.gd` |
| story | `scripts/act3/act3_beats.gd` |
| new props | `scenes/props/sea/` (Current, AirBubble, Jellyfish, Memory, InkFlood, decor) |
| player additions | `player.gd` Swim group: `has_swim_dash`, `swim_dash_*`, `set_current()` |
| rooms + routes | `tools/build_act3_world.py` → `ldtk/hooshang_act3.ldtk`, `resources/levels/act3_routes.json` |
| route proof | `tests/act3_routes_test.tscn` (real input, every room) |
| art | `tools/gen_act3_sea_art.py`, shaders in `assets/shaders/act3_*` |

## Verification

- **Every room is proven with real input**: `tests/act3_routes_test.tscn`
  searches each step of each room's route and replays the whole room start to
  finish — 23 playable rooms, 0 failures, 0 fragile steps (the ascent and the two
  epilogue rooms are story-driven). Two design rules came out of it and are in
  `tools/act3_rooms.py`'s header: one Dive crosses at most 5 cells of current,
  and any room that needs the Dive offers a refill before it.
- **Every scene plays**: `tests/act3_story_test.tscn` reaches all fourteen scenes
  the way a player does, with the story on, through to the act's results.
- **Look**: `tests/act3_shot.tscn` photographs rooms; the depth palette was
  tuned from those captures (monochrome shore, indigo shallows, teal-and-amber
  wreck, violet reef, warm trench, gold floor, natural-colour sunrise).
