# Act 2 — the sky gardens

Eleven rooms, `Act_2_Level_3` through `Act_2_Level_13`, follow the meadow,
pond story and carpet lesson. The garden finale leads into the castle approach;
it does not complete the act. Current LDtk geometry is authoritative.

- **Saffron Steps:** ascending jump/dash transfers, with broad first landings.
- **The Spring Courtyard:** spring steering and increasingly raised catches.
- **Orchard of Choices:** a low crumbling route or an upper spring/reward route,
  converging at a supported checkpoint terrace.
- **Silk in the Wind:** two steered carpet passages separated by a rest island.
- **The Sky Garden:** spring, crumble and carpet challenges with a checkpoint
  between movement phrases.
- **Garden of Kings:** quiet recovery floor, wider landings and a short flight.
- **Apex Relay:** spring-to-dash transfers with widened catch surfaces.
- **Needlewind Passage:** leave a carpet, cross an island, then recatch it.
- **The Turning Stair:** changes of direction and alternating ascent/descent.
- **Under the Thorns:** short controlled hops under readable low ceilings.
- **Crown of the Wind:** combines familiar flight and transfer ideas, then
  releases the player into the calmer castle approach.

All rugs travel right at 32 px/s after boarding. Up/down arrows, W/S,
controller D-pad or left stick steer vertically at 36 px/s. Neutral input holds
height. Hazards are LightThought entities; solid garden architecture creates
route choices and headroom puzzles. After dismounting, a rug keeps flying for
five seconds, then returns to its original parked position. Reboarding before
the deadline cancels that return.

Checkpoint behavior remains on resting islands; flags and decorative checkpoint
pennants are hidden. Small transfer ledges stay clear of botanical props, while
broad resting islands retain accents. Room titles sit below the first elevated
platforms with a dark one-pixel shadow. The final garden has no completion banner.

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

Edit the current LDtk project for continued level authoring. The original
`tools/build_act2_expansion.py` generates the earlier baseline; rerunning it
wholesale can overwrite later room and accessibility polish. The focused
`revise_act2_garden_landings.py` documents the subsequent landing corrections.
Keep LDtk closed during scripted changes and reload afterward.

For a targeted import of the current Act 2 source:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --script res://tools/import_act2_expansion.gd
```

An already-open editor may retain old import hooks. Do not terminate the user's
editor process; distinguish targeted-import results from its cached view.

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
