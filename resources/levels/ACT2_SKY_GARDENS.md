# Act 2 — the sky gardens

Eleven rooms, `Act_2_Level_3` through `Act_2_Level_13`, follow the meadow,
pond story and carpet lesson, and lead into the castle approach. They are
authored by `tools/redesign_act2_gardens.py` (explicit geometry, nothing random)
together with their real-input routes in `act2_expansion.json`.

## Design rules

Act 1 already taught jump, dash, wall-jump and the thought hazards, so the
gardens do not re-teach them on safe ground:

- **Every room is over a lethal rose-thorn pit, wall to wall.** Only the
  entrance pad is safe floor. (The previous pass left a thorn-free strip at the
  far end of each room, which was a soft-lock: the only way out was retry.)
- **One idea per room, in four beats** — introduce, develop, twist, conclude.
  The first instance of an element is the cheap one; the last is the test.
- **A sawtooth curve, not a ramp.** 3 warms up; 4–6 each add one Act 2
  mechanic; 7 is the first exam; 8 is a breather with a hard optional dare;
  9–12 escalate; 13 combines everything.
- **A checkpoint after every phrase** longer than ~10 seconds to replay.
- **Lemons are dares off the critical path**, visible from it. Every room has
  at least one the main line does not take.
- **Drifting thoughts are timed, never random.** Their periods are long enough
  to read on sight, and gates in one room are phase-shifted so they never move
  as one wall.

## The rooms

| Room | Title | Idea |
|---|---|---|
| 3 | Saffron Steps | Dash rhythm over the pit, then the first drifting thought bobbing through the gap you must dash: wait for it to sink. |
| 4 | The Spring Relay | Act 2 springs refill the dash: spring → dash → land on a floating spring → dash. Then a side spring whose flat throw slides under a thorn roof a jump clips. Dare: up-dash off the floating spring for the lemon and fall back onto it for your dash. |
| 5 | Orchard of Choices | A fork. Low road: three crumbling stones, no stopping. High road: a spring into the canopy past a circling thought. One lemon on each road. |
| 6 | Silk in the Wind | Carpets through *moving* thought gates: follow the gap. The second and third drift out of phase. |
| 7 | The Garden Threshold | First exam: up-dash start, crumbles, a floating-spring relay, a rug through a drifting gate. |
| 8 | Garden of Kings | Breather: broad landings, a lazy rug. Dare: a spring to a lemon alcove a slow circling thought keeps sweeping. |
| 9 | Apex Relay | Relays under a thorn roof that forbids the up-dash, a thought you time from the checkpoint, crumbles, then a side spring under a roof low enough that *any* jump dies. |
| 10 | Needlewind Passage | Leave a fast rug, cross an island, recatch it — three times. The middle island rides higher, so lane changes happen in short open stretches at speed. |
| 11 | The Turning Stair | Up a two-wall chimney by wall-jumps, out over the top, then a crumbling descent back down. Dare: the lemon above the chimney mouth costs a re-climb. |
| 12 | Under the Thorns | A thorn roof over crumbling stones (hop, don't jump), a spring through a one-gap roof — the needle's eye — then a ledge a thought keeps dropping onto like a piston. |
| 13 | Crown of the Wind | Finale: relay → rug weave → side spring under a thorn roof → crumbling stones, a checkpoint between phrases. |

## Child movement

The geometry is built against child Hooshang's measured reach — re-run
`tests/act2_feel_measure.tscn` before changing `Act2Beats._apply_child_movement`:
held jump 32px high; running jump 41px high / 70px long; jump + dash ~80–104px
long; jump + up-dash ~70px high; up spring 71px (+ up-dash ~108px). A side
spring's throw is **flat** — no lift at all unless he jumps during it — which
is what lets a thorn roof 12px over his head admit the throw and kill any jump.

## Mechanical contracts

`SpringPlatform` bounces up by default; `Facing` Right/Left turns it on its
side. A Right-facing side spring throws him right and is triggered by walking
LEFT into its face, not from its back. Act 2 springs refill the dash.

Every `MagicCarpet` begins parked. Landing on top starts it; it keeps flying for
five seconds after he leaves, then returns. A rug that meets a wall stops
against it; he simply jumps off.

Moving thought gates (`Room.gate(..., amp=...)`) move every cloud in the column
together, so the gap keeps its size; the clearance either side of rider + rug is
explicit (`clear`).

## Routes and checks

`act2_expansion.json` holds, per room, the geometry summary `SkyGarden` dresses
from (title, ledges, springs, carpets, exit) and three route lists, all replayed
with real inputs (no position or velocity writes):

- `routes` — the main line, entrance to exit.
- `optional_routes` — the Orchard's high road.
- `reward_routes` — the main line with every lemon dare taken.

Route steps: `jump`, `dash`, `spring`, `spring_dash`, `flight`, `weave`, `side`,
and `chain` — one airborne phrase across springs, side springs and wall-jumps,
with a dash per segment and an optional `wait` that holds the departure until a
named thought is in a phase window (the player watching the cloud).

- `act2_routes_test` — every main route; `-- --rewards` replays the reward
  routes and checks every room's fruit banked (except the Orchard, whose two
  lemons sit on its two exclusive roads).
- `orchard_optional_test` (and `-- --lower`) — each Orchard road, one lemon each.
- `garden_reward_detour_test -- N` — one room's reward route through its real exit.
- `act2_expansion_test`, `carpet_obstacles_test`, `act2_progression_test`,
  `garden_connected_test` — imports, spring headroom, checkpoints, no bypass of
  the weave's required dismount, both-way exits, one continuous run.

These are automated traversal proofs, not a claim of human fun-testing.

## Rebuilding

Close LDtk and the Godot editor, then:

```
python3 tools/redesign_act2_gardens.py
touch ldtk/hooshang_act2.ldtk
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

The script rewrites only `Act_2_Level_3`..`Act_2_Level_13` and asserts every
other room is byte-for-byte unchanged. Hand edits to those eleven rooms in LDtk
are overwritten by a rebuild — port them into the script. The older
`build_act2_expansion.py` and the garden half of `rework_act2_precision.py` are
superseded; do not rerun them.

Save-free playable entry:

```
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/act2_expansion_preview.tscn
```
