# Act 2 advanced extension: levels 9–13

These five original levels assume jump/dash competence. They extend the existing
Act 2 sequence: level 8 leads to 9, and completion moves to level 13. Earlier room
geometry is preserved. No player physics, ability unlocks, or save format changed.
**No climbing, wall jumps, ladders, or automatic mantles are required.**

## Reference study

Read-only analysis of the installed Celeste Summit and Core A/B/C-side map
binaries informed the extension. In the installed `7X-Summit` map, the three
rooms progress from a tall 808×824 ascent, through a 760×248 transfer room, to
a 3608×200 sequence. The last room combines eight wall springs, nine falling
blocks, three clouds, and seven refills within a hazard-lined route. Core's
`9X-Core` contains a 5272×184 challenge with twenty falling blocks, thirteen
refills, thirteen mode toggles, and several other movement mechanisms.
These are map observations, not playthrough measurements; spawn records are not
being treated as checkpoint counts. This installation has no Farewell map.

The useful principle is commitment across successive transitions: arrive on a
temporary foothold already planning the next launch; change approach when the
same mechanic appears in a new spatial constraint; combine familiar systems in
the final sequence. Hooshang uses its own mechanics and art. Celeste's wall-spring
and refill chains are translated into spring/dash and grounded dash-reset
chains, rather than requiring climbing or adding Celeste-specific abilities.
The developer's [GDC talk description](https://www.gdcvault.com/play/1024307/Level-Design-Workshop-Designing-Celeste)
also provides context for arranging difficult stages into a larger progression.

## The five levels

- **9 — Apex Relay:** spring launch into an upward diagonal dash, directly onto
  a crumbling platform. Continue a timed chain before the resting island. The
  second half repeats the transfer with changed heights and landing distances.
- **10 — Needlewind Passage:** jump off one 24px-wide carpet onto three overhead
  islands and catch that same carpet after each island. The rug travels at 48px/s
  beneath the islands while the player crosses above. A checkpoint follows the
  entire flight, before the spring/dash finish.
- **11 — The Turning Stair:** reverse left in midair to gain height, then jump
  and dash right again; follow with a descending crumbling chain and a final
  spring/dash sequence. All landings must be reached above their top faces.
- **12 — Under the Thorns:** a low spiked ceiling constrains jump height over
  temporary platforms. Short-hop timing matters; a full-height bailout is unsafe.
  The second half opens into longer, exposed transfers.
- **13 — Crown of the Wind:** combine a spring/crumble chain, three mandatory departures
  and catches of a 56px/s carpet at alternating heights, and a final
  airborne-transfer sequence. Two main resting checkpoints
  separate these phases; completion is at the final portal.

Optional lemons mark riskier positions. Hazards are existing childhood-palette
props. Existing landmark paintings and native garden dressing are reused. There
is no new tutorial dialogue or new movement ability.

## Authoring and acceptance

Source: `tools/build_act2_expansion.py`. Rebuild with Act 2 closed in LDtk, then
run the targeted `tools/import_act2_expansion.gd` importer with `--headless --editor`.
Geometry and route recipes are generated together. Room IDs and positions are
stable between rebuilds. Do not edit generated scene files.

`act2_routes_test` drives real inputs continuously from each entrance to its exit
platform. Advanced runs disable automatic ledge assistance and fail if they use
climbing, mantling, wall jumping, or die. Solutions include spring-to-diagonal-dash
timing and a short-hop solution for the ceiling corridor. This verifies one
continuous solution; it does not measure human enjoyment or every possible route.

`act2_expansion_test` checks checkpoint activation and actual death recovery,
spring headroom, and initial carpet support. `act2_progression_test` traverses
forward through room 13 and back to room 3. Normal-speed validation is required
in addition to accelerated iteration. The preview accepts a room name, and
`-- --capture Act_2_Level_9` records rendered views of that room. Saves are disabled
in test/preview scenes.

Validated: all eleven expansion routes at normal game speed, all five advanced
rooms without climb/mantle/wall-jump use, new-room checkpoint death recovery,
forward/return progression and final completion, smoke, world bounds, backtrack
clearance, backtracking, and the return-strip respawn regression. Rendered views
of all five new rooms were inspected. Earlier room data was compared against a
pre-change snapshot: only room 8's onward exit changed, and exactly five rooms
were appended. Human playtesting remains the measure of difficulty and enjoyment.

## Carpet redesign: separate the player from the vehicle

The earlier courses let a rider solve everything with vertical steering. A closer
spatial inspection of Summit B-side movers exposed a more useful relationship:
`lvl_b-00` alternates 16px movers between x=24 and x=88 across successive heights,
with hazards on/near their placements. `lvl_f-02` places six swap blocks across a
616px-wide room amid 120 hazard entities; one block at (104,168) has hazards at
its placement and a destination node at (104,112). The design inference is to
constrain the player's position relative to a moving support, rather than merely
place free-standing hazard columns in its path. These observations do not claim
that Celeste has Hooshang's steerable-carpet mechanic.

The new split passages provide 16px of space ABOVE each island: enough for the
12px-tall player, but not the player plus an 8px-tall carpet. The island underside
is at the carpet's lane; the empty carpet travels 1px below it to clear the physics
sweep margin. Spikes 8px below the underside make riding under the island lethal.
The roof reaches the room's upper boundary, preventing flight over the whole
structure. Wide gaps between islands require catching the carpet again.

The player must leave the carpet, cross the island while the rug keeps moving,
then jump/drop onto that same rug. Waiting too long loses it. Level 13 changes
lane between passages and raises speed from 48 to 56px/s. No movement physics or
carpet reset behavior were changed. Decorations are excluded from these narrow
upper passages to keep the usable space readable.

Validation includes continuous real-input solutions with three same-instance
recatches per room, no reset of the carpet during flight, no death, and no climbing,
mantling, or wall jumps. Windowed, normal-speed runs capture the actual island
landings and recatches with `-- --capture-weave Act_2_Level_10 Act_2_Level_13`.
`carpet_obstacles_test` supplies negative controls: passive riding and continuously
held up/down each fail to clear the first split passage. These are sampled
strategies, not an exhaustive proof against every possible shortcut.
