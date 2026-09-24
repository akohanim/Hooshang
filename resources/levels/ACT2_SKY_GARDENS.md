# Act 2 — the sky gardens

Six additional rooms, `Act_2_Level_3` through `Act_2_Level_8`, follow the
existing three-room Act 2 project. All terrain remains on its 8px grass grid.
Each expansion room has a distinct watercolor Persian landmark painting,
blended at its borders; earlier rooms retain the original panorama.
Native garden ornaments use a new PixelLab swatch for their color ramps;
short original synthesized sounds mark spring releases and carpet boarding.

- **Saffron Steps:** a safe spring lesson and short steering flight, followed
  by two ascending spring transfers. Broad landings teach air control; the
  high lemons invite more precise arcs.
- **The Flying Courtyard:** duck beneath a hanging garden, climb to a rest
  island, then spring onto a second parked rug. A light-thought opening guards
  the final ride. The island banks a checkpoint, with no visible flag.
- **Orchard of Detours:** spring up to a launch terrace and choose above or
  below the central island. Both paths reach the exit. The high path offers a
  lemon balcony: jump off, collect, then catch the same moving rug again.
- **Silk in the Wind:** climb two spring steps, walk past a side spring and
  turn back into its face to launch onto a lower rug. A slowly moving thought
  gate leads into a tighter static opening; a low exit gives room to dismount.
- **The Sky Garden:** a longer, 768px finale. Spring directly onto a rug,
  thread a precise opening, rest at a checkpoint, bounce to an upper terrace,
  side-launch onto a second rug, and make the final climb through light thoughts.

- **Garden of Kings:** a calm coda beneath the Tomb of Cyrus. A spring climb,
  short carpet flight, and final spring lead to the completion terrace.

All rugs travel right at 32 px/s after boarding. Up/down arrows, W/S,
controller D-pad or left stick steer vertically at 36 px/s. Neutral input holds
height. Flight limits stay above the recovery floor. Hazards are LightThought
entities; solid garden architecture creates route choices and headroom puzzles.
After dismounting, a rug keeps flying for five seconds, then returns to its
original parked position. Landing on the floor does not shorten that delay.
Reboarding before the deadline cancels it, preserving the optional balcony loop.
Tutorial signs and checkpoint flags stay removed. Only the first three existing
Act 2 rooms are outside the builder's authored expansion and remain unchanged.

## Mechanical contracts

`SpringPlatform` retains its upward bounce by default. Rotate it +90 degrees
for right or -90 for left in Godot, or set its `Facing` field in LDtk. Side
launches use 240 px/s horizontal momentum; gravity resumes immediately and
normal steering/dash remain available. They trigger from the exposed face,
not the back or while already moving away.

Every `MagicCarpet` begins parked at its authored position. A real player
landing on top starts its configured pattern, which continues after jumping off.
A room entry or death/reset returns it to the parked state and clears its timer. Simply brushing
its side does not start it. The Jamshid film uses its own tweened sprite and
is unaffected.

The old second room needed an exit, and the tall third room needed a spawn
and an exit landing. The builder adds those missing connections without
erasing existing terrain. New rooms place their return doors at their spawn
edge even when the preceding room's exit is an interior portal.

## Build and play

Keep **the Act 2 project** closed in LDtk before running:

```
python3 tools/build_act2_expansion.py
python3 tools/gen_sky_garden_decor.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

The builder is deterministic and preserves unrelated JSON formatting/content.
If Godot's editor holds a stale importer, close it normally and reimport.
`tools/import_act2_expansion.gd` is also a targeted import diagnostic; it
imports only Act 2 through the existing importer and configured hooks.

Save-free playable entry:

```
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/act2_expansion_preview.tscn
```

Pass `-- --capture` to write actual rendered 320x180 views, enlarged with
nearest-neighbour sampling, under `output/act2_expansion/`.

## Checks

- `side_spring_carpet_test`: both side-launch directions through physics,
  carried momentum, parked/boarded/reset behavior for all four carpet patterns.
- `act2_routes_test`: real input-driven spring transfer, boarding jump, complete steered
  flight and destination landing in each imported room, followed by continuous
  entrance-to-exit runs. Both Orchard solutions and the optional balcony return
  are traversed. Also verifies constant
  forward speed and the delayed return. This is automated traversal coverage,
  not a claim of human fun testing.
- `act2_expansion_test`: real imports, entrances, checkpoints, spring headroom,
  carpet carrying and forward destinations.
- `act2_progression_test`: actual forward and return triggers through the five
  rooms, clear return landings and entrance retries.
- Existing spring, carpet, panorama, Act 2 quest and encounter tests also run.

The varied-layout revision passes all targeted suites; results and logs
are in `output/act2_expansion/variety/`. Earlier broad-suite findings
remain recorded separately in `output/act2_expansion/verification.md`.
