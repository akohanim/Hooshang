# Prison precision revision progress

- [x] Read the new attached goal and current project/movement instructions.
- [x] Snapshot the existing build's source and audit all 17 prison rooms.
- [x] Identify safe-rest abundance and independent short actions in existing routes.
- [x] Write the higher commitment standard and wing-by-wing design direction.
- [x] Rebuild and measure the representative cafeteria wing (connected earned forward/reverse passes; broader final acceptance remains).
- [ ] Bring library, basement and gym to that standard.
- [ ] Validate failure/retry/backtracking/save/key/rescue and full-act consistency.
- [ ] Export the new playable build, captures and verification report.

Baseline: `output/prison_precision/baseline/`. Design: `prison_precision_design.md`.
The previous challenge build remains a baseline; its passing routes do not prove
the new requested difficulty. R01–R03 have the main precision rebuild. G03/Y03 now have musical-gate prototypes; nine dry vertical connections also have partial entrance ledges. Other wing challenge rebuilds remain pending.

First implementation support: added three damage stages to the prison's solid
crumbling shelf. The existing warning previously reused its intact atlas region
for every frame. Act1 and the shared crumble physics remain unchanged. Rendered
contact/countdown/reset verification passed in `warnings/`: all three damage
stages appeared before collision dropped, and lever activation restored intact
art and collision. The fixture stages its initial landing; it is not a route.


## R01 collapsing-shelf lesson

- [x] Authored directly in LDtk through `tools/build_precision_cafeteria_intro.py`: 104px gap, 24px temporary landing, clear observation banks, existing lever/relay and external apertures retained. Removed the patrol so the lesson isolates collapse timing.
- [x] Official schema/reference validation and targeted Act2 import passed.
- [x] Rendered input-driven spawn → lever → shelf → relaunch/dash → seal → actual R02 exit: zero deaths, no climb/mantle. Relaunch started at0.133s of the0.6s collapse window; no collapse-edge/coyote reliance.
- [x] Inspected the native room render; signs and controls remain sparse, solid shelf visibly distinct from wooden one-way ledges.
- [x] Movement smoke and world-bounds checks passed. Existing pantry retry fixture initially selected the newly added R01 shelf while testing R03; scope corrected to the current room. Its rerun is recorded separately rather than hiding the initial failure.
- [ ] Deliberate late launch, missed landing, bypass and reverse-route tests for R01.
- [ ] R02 development chain and R03 capstone rebuild; the representative wing milestone is not yet complete.

Evidence: `output/prison_precision/cafeteria_intro/route.json`, `route.log`,
`01_observe.png` through `04_exit.png`. The first attempted recipe left at the
collapse boundary and was rejected as sufficient timing evidence; it is retained
as `route_boundary_attempt.json`. The successful recipe uses active air braking
and early floor-contact detection without changing player physics.


## R02 five-action commitment chain

- [x] Replaced permanent central rests with four24px solid collapsing shelves in a rising zigzag. Existing controller/exit persistence remains; removed two patrols and the middle lever to keep the challenge visually sparse.
- [x] Earned route contacts all four shelves centrally, then dashes left through the high shutter, banks the seal and uses the actual R03 exit. Zero deaths or climb/mantle,0.1s contact-to-relaunch on each0.6s shelf.
- [x] Deliberate late departure from shelf2 causes one real death; respawn is safe, all shelves reset, and the unfinished timer clears. No position or state injection in either route.
- [x] A two-shelf bypass probe reaches shelf2 but fails at the attempted direct upper landing. This is one tested shortcut, not an exhaustive proof against every alternate route.
- [x] Rendered native composition inspected. Initial edge-only first contact was rejected; the revised driver clears the entrance ceiling and requires full-body central landings.
- [x] Schema, targeted import, movement smoke and world-bounds pass.3,506 protected files still match the new revision baseline.
- [ ] Reverse traversal, timer expiry variants, additional bypass/landing-margin probes and complete wing integration.

Measured seal route6.65s; global timer reduced from12s to8.5s based on that
measurement, then rerun against the final timer. Evidence:
`output/prison_precision/cafeteria_development/route.json`, `late_retry.json`,
`bypass_probe.json`, corresponding logs and `route_*.png`. Rejected edge-contact
evidence remains in `edge_landing_attempt.json`. The prior wing/full-act drivers
need adaptation to the new room geometry before they can serve as acceptance
evidence. The representative wing milestone is still incomplete.


## Existing crumble-art correction and return verification

User correction: scaffolding is solid and must never communicate collapse.
Removed the prison scaffold skin and its generated damage variants. All prison
CrumblingShelf entities now inherit the existing three-frame beveled crumble
stones, including their original jitter, falling pieces and reset animation.
Their LDtk definition and instance previews use the existing crumble icon.
No shared artwork or movement physics was changed.

Rendered warning fixture passes all three stages, actual collision loss and
lever reset (`existing_crumble_art/warning.log`, refreshed `warnings/*.png`).
R02's actual earned outbound route and R03 → R02 → R01 → hub retreat pass with
zero deaths and no climb/mantle using the corrected artwork (`backtrack.json`).
The upper shutter now has eight pixels more headroom, y40–112. The return flat
dash launches near the jump apex; the earlier short launch is retained as a
failed attempt. A successful recipe does not yet establish timing tolerance.
R03 capstone and other-wing rebuilds remain unfinished.


## R03 seven-stone capstone

- [x] Authored through `tools/build_precision_cafeteria_capstone.py` in LDtk:
  four-stone rising zigzag to a permanent bank, then a three-stone rising
  reversal to the high second seal, followed by a drop/dash to the key alcove.
  Uses the existing crumble artwork; no extra switch density.
- [x] Actual input route earns both seals and Red, then takes R04 to the hub:
  zero deaths and no climb/mantle. First phrase5.58s against9s.
- [x] Late departure in the second phrase causes exactly one death; entrance
  respawn, all stones restored, unfinished timer cleared, first seal retained.
- [x] Direct midpoint-to-high-seal jump/dash probe fails. This is one tested
  bypass, not an exhaustive route proof.
- [x] Rendered native room and key approach inspected. Schema/import pass.
- [ ] Slower-departure margin result, hazard phase variations, retreat and
  full connected cafeteria loop still need completion/assessment.

Evidence: `output/prison_precision/cafeteria_precision_capstone/`. Failed
clearance/drop attempts remain alongside the final layout. All3,539 files in
this pass's protected subset (characters/portraits, player scripts, Act1 LDtk
and selected story scripts) match the revision baseline. The representative
wing milestone is still incomplete until connected and reverse runs pass.

Slower-departure probe now passes: waiting18 frames on every stone (0.30–0.317s
of the0.6s deadline) still completes both seals, Red and the hub return with
zero deaths. First phrase6.40s; second seal2.88s, versus5.58s/2.30s on the
quicker recipe. This demonstrates a sampled departure margin, not arbitrary
landing tolerance or human-tested feel. Final geometry smoke/world-bounds
checks pass (`final_geometry_checks/results.json`).


## Connected cafeteria milestone

- [x] A single imported world, actual hub entry and earned room transitions:
  hub → R01 → R02 → R03 → Red → R04 → hub. No progress grants or teleports.
- [x] The same earned run continues hub → R04 → R03 → R02 → R01 → hub with
  zero deaths and no climb/mantle. The connected trace includes all room drivers.
- [x] R03's upper seal now opens a lower return grate atx268,y64–112. This
  removes the return ascent through the patrol while retaining the outbound
  upper route. Authored in LDtk; it shares the existing second-seal controller.
- [x] Current geometry smoke, world bounds and staged pantry retry pass.
- [x] Current linked-shutter save/restore and refreshed warning render pass. State fixtures are staged, not earned route playtests.

Evidence: `cafeteria_connected/backtrack.json` (all four stage reports clean),
`cafeteria_connected/route.json`, and current capstone `backtrack_*.png`.
Standalone R03 reverse probes are retained as diagnosis, not passing evidence:
starting directly in R03 does not earn R02's exit seal, so that fixture cannot
cross its locked target-room shutter. The connected run earns it normally.
The successful R03 reverse recipe waits below the patrol, climbs to the far
ledge, walks through the earned lower grate, jumps to the midpoint, restores
stones and retraces three landings before jumping through the upper portal.

The retry fixture now stages its landing relative to the current stone instead
of the removed old platform's coordinates. It verifies a real pit death and
safe reset; the prior recoverable-bottom-floor assertion no longer describes
this room. The warning fixture also stages relative to the actual stone.


## User addition: exactly two musical key puzzles

The user requested two puzzles requiring ordered musical-tile hits to open
key gates. Added prototype authored sequences in G03 (Green) and Y03 (Gold),
reusing existing NoteTile art, pitch sounds and contact behavior. Library's
four unordered nodes are replaced by five numbered musical tiles; gym's first
key-alcove roof is now musical while its existing timed traversal remains.
No Act1 music behavior or shared note artwork was changed.

- [x] Prison-local ordered circuit handling; wrong/repeated note resets only
  that unfinished melody. Completed melodies use the existing persistent
  circuit save ledger. Separate library and gym progress.
- [x] LDtk definitions for MusicalGate and five numbered PrisonNote entities,
  typed local references, exactly two gates and five notes per gate validated.
- [x] Order/reset/persistence state checks and original music/circuit tests pass.
- [x] Imported gravity-contact checks now pass both five-note gates after moving gym note2 to an exposed landing. These are staged contacts, not earned routes.
- [x] Disk save/resume restores both ordered gates physically open. Revision9 preserves the new gym gate for older saves with Gold or a later wing checkpoint.
- [ ] Actual ordered movement routes, failure/retry and integration with the deeper wing challenges.
- [ ] Integrate both melodies into the deeper library/gym geometry passes.

Evidence: `output/prison_precision/music_foundation/`. The contact fixture
stages a gravity landing over each pad and does not demonstrate a playable
route between pads. Initial library contacts passed; initial gym note2 was
covered by a ledge and moved to(240,80). Numbered sounds and success/wrong cues
remain small and local; there are no connection wires in the game.


## Partial one-way entrance ledges

User instruction: vertical entrances need partial jump-through catch ledges,
with an open side for ordinary downward retreat. Authored nine16px wooden
ledges above dry vertical seams, leaving24px clear beside each40px opening.
Boundary aperture cells stay open, so room adjacency is unchanged. The tenth,
submerged B01/B02 seam remains continuous water for swimming.

- [x] Official schema and all local references validated.
- [x] Rendered portal fixture passes nine upward entries landing on their
  partial ledges and nine downward side-gap returns, zero deaths.
- [x] Repeated portal fixture passes all nine in both directions, zero deaths.
- [x] Connected earned cafeteria forward/key/shortcut/reverse loop passes with the partial entrance ledges, zero deaths and no climb/mantle. Return driver now releases input immediately when its upward jump changes rooms.
- [x] Final smoke/world-bounds checks after this change pass.

The portal fixture stages unlocked puzzle state and each lower launch position;
then jump/walk inputs perform actual transitions. It is separate from earned
whole-wing playtests. An initial run reported a hub/B04 descent miss; a fresh
run passed all nine. The repeat result must be assessed, not discarded.
Evidence: `output/prison_precision/entrance_ledges/placements.json`, `routes.json`,
`routes.log`, and native room captures. `tools/add_prison_entrance_ledges.py` is
one-time authoring; future edits stay in LDtk.

Music regression note: an external/current Jamshid texture reference initially
had no usable imported resource. Reimported the existing native18/movement.png
cache without editing character artwork; save and migration reruns pass in
`music_foundation/state_rerun/`. The earlier failing log is retained.

## Library G03 ceiling melody pass

Replaced the criss-cross music prototype after an earned input route hit note4
on its approach to note2. G03 now has five ceiling notes in a readable left to
right phrase, three existing 24px crumble stones, and a permanent final wooden
lip. The solved melody opens the horizontal Green-key roof. Original key,
shortcut, and partial lower entrance ledge remain. No new switches or wires.

- [x] Script-authored LDtk layout, official schema validated; other rooms preserved.
- [x] Earned five-note/key/G04 route, no deaths or climb/mantle.
- [x] Same route with 18 extra physics frames (0.3s) on each temporary landing.
- [x] Late first-stone departure causes one real pit death, restores stones and
  safe checkpoint, then the retry earns the key and reaches G04.
- [x] Connected Hub→G01→G02→G03→G04→Hub earns all three library circuits and
  Green with zero deaths. G01/G02 still use their previous geometry.
- [x] Both music puzzles pass staged contact checks; library uses head strikes.
- [x] Eight checks pass: smoke, world_bounds, platform, music, music_exit,
  prison_music_order, prison_circuit_save, prison_migration.
- [ ] Deeper G01/G02 progression, reverse G03 traversal, alternate/bypass probes,
  missed-note recovery and final native-resolution presentation pass.

Evidence: `output/prison_precision/library_music/`, including `connected/route.json`,
`late_retry.json`, `hold_18.json`, native captures, and `checks/results.json`.
These are scripted gameplay and staged tests, not a human difficulty assessment.
The existing stone's 0.6s timer is unchanged. Normal landings begin their jump
at about0.183s of stone age; the delayed run begins at0.383–0.433s. The later
lateral dash can happen after the stone falls because the player is airborne.
Ordinary crumble imports are now supported inside prison rooms, with local
room-entry resets; shared crumble/player behavior and Act1 remain unchanged.

## Library G01 lesson and reverse-route pass

Authored G01's two-stone ascent in LDtk. Two24px crumble stones connect the
first contact-seal bank to an upper permanent seal bank. Existing two-node gate,
room-entry checkpoint, lower partial catch ledge and side gap are preserved.
A jump/upward-dash exits through the upper aperture; diagonal steering is not
required there. No new mechanism entities beyond the two existing crumble props.

- [x] Standalone forward route reaches G02 without death/climb/mantle.
- [x] 0.3s dwell on each0.6s stone still reaches G02; normal contact ages0.1s.
- [x] Earned G01→G02→G01→Hub reverse route retraces both stones without death.
- [x] Reverse inspection widened the upper permanent bank from56 to80px,
  keeping its challenge-facing edge fixed. This catches sideways momentum
  after stepping beside the upper lip.
- [x] Official schema/local references pass. Smoke, world_bounds, platform,
  prison_music_order checks passed after the initial ascent edit.
- [x] Final connected library forward/key/shortcut/full reverse loop after bank widening: all three circuits, Green, Hub finish, zero deaths and no climb/mantle.
- [ ] G02 deeper sequence, G01 failure/bypass probes, remaining wings and final
  whole-act acceptance still outstanding.

Evidence: `output/prison_precision/library_intro/` (route, hold_18, backtrack,
checks and native captures). Authoring scripts are one-time recipes:
`tools/build_precision_library_intro.py` then `tools/widen_library_return_bank.py`.
Do not rerun them over later LDtk edits or restore their full-project snapshots.

G03 reverse evidence before the bank fix: all three melody stones and the
G03→G02 transition pass with earned Green state; re-entry restores the stones.
The approach uses the key-alcove floor, its return step, then the final note
bank. The left exit uses an upward dash from directly beneath its narrow lip.
Earlier diagonal recipes missed ledges but landed safely; those test failures
were not evidence of an unreachable route.

Final connected evidence: `output/prison_precision/library_music/reverse/route.json` and `reverse.log`. These inputs earn G01/G02/G03 before returning through G04 and retracing G03/G02/G01. No puzzle-state or position grants. G02 still has its previous geometry.

## G02 four-stone reversal: standalone validation

- [x] Script-authored original geometry and official schema validation.
- [x] Four temporary landings with a low crossing, rightward rise and leftward
  reversal; two endpoint seals replace the previous three-node errand.
- [x] Existing0.6s crumble artwork/behavior; no scaffolding repurposed.
- [x] Forward route earns both seals and exits to G03, no death/climb/mantle.
- [x] Slower route with0.3s dwell on each stone passes.
- [x] Real collapse death resets all stones; same run retries and reaches G03.
- [x] Smoke, world_bounds, platform, prison_music_order, prison_circuit_save pass.
- [x] Full connected forward/key/shortcut/reverse library loop passes: all three circuits, Green, Hub finish, zero deaths and no climb/mantle.
- [ ] Wider landing/timing probes, alternative-route audit, wrong-note recovery,
  remaining wings, final build and whole-act verification.

Evidence: `output/prison_precision/library_stacks/`. The bottom-row passage
under the new beam is omitted by the generic navigation graph; connected
fixtures use actual walking/jumping inputs there instead of planner waypoints.
The older `library_wing_route_test` now delegates to the current connected
fixture, so it no longer tests discarded pre-music geometry.

G02 final probes: normal0.1s and delayed0.3s contact dwells pass; aimed landing
offsets of−3px and+3px also pass with zero deaths. An upward jump/dash beneath
the beam does not reach a crumble stone or open the gate. This is one specific
bypass probe, not exhaustive alternate-route proof. The connected reverse
fixture walks the bottom passage and makes a short hop toward the partial
catch ledge; if that hop already transitions to G01 it does not trigger the
same doorway again. Final results in `library_stacks/connected/route.json`.

## B01 alternating swim passage

One-time authoring: `tools/build_precision_basement_intro.py`. Existing roofed
pool has three alternating baffles, the end seal moved to(248,160), and original
sluice/room apertures preserved. The32px upper and40px lower gaps are a safe
introduction to the next rooms' swim demands; no timer or hazards were added.
The24px entry mouth permits a surface kick and ordinary jump onto the roof,
without bank mantle. Shader/art/player movement remain unchanged.

Evidence in `output/prison_precision/basement_intro/`:
- `route.json`: all six swimming targets, B02 entry, full reverse swim and
  jump out, Hub return; zero deaths/climb/mantle.
- `retry.json`: actual respawn input after earning submerged seal, one death,
  dry safe checkpoint and persistent physically open sluice, then repeated
  whole route and Hub return. This uses no position/progress grants.
- `connected/full_route.json`: full earned Hub→B01→B02→B03→B04→Hub and reverse
  loop, zero deaths/climb/mantle. B02/B03 retain earlier challenge geometry.
- Six checks: pond, water_tile, smoke, world_bounds, prison_circuit_save pass
  in `checks/`; flood_valve rerun passes in `flood_rerun/`. Original failure
  retained: fixture teleported to the old seal coordinate; it now stages at
  the actual imported valve. This fixture is distinct from input-driven routes.

The older B01 route now delegates to the new driver. The existing B03 full-loop
fixture composes that driver for the outbound and return B01 legs, so later
basement work can test the complete earned route without stale waypoints.

## B02 swim window and air-pocket landings

Authored through `build_precision_basement_stores.py` and
`add_basement_stores_patrol.py`; later edits remain in LDtk. The original dry
valve/sluice persist. Two24px stones at(120,140)/(88,116) replace fixed footing,
with a safe submerged recovery beneath. One vertical patrol at(144,112),
amplitude8/speed0.3, provides a visible swim-entry window. Its earlier low sweep
was rejected after an earned route died while rising into the pocket.

`SwimCrumblingPlatform` reuses existing crumble art/physics, restores only when
the player is swimming and its solid box is clear, and pauses the countdown
while an EXIT_WATER rider's uninterruptible animation owns controls. The shared
player and crumble scripts remain unchanged. Actual gameplay exposed this
animation consuming most of the0.6s warning; the local fix gives control back
before timing the relaunch. A fresh editor filesystem scan registered the new
script UID after the first targeted import left an invalid-UID warning.

Rendered evidence: `output/prison_precision/basement_stores/`. Wet retry observes
collapse, verifies safe collision restoration, lands again and operates the
valve, exits and returns without death. It also checks the stones do not reset
between dry landings. The delayed run launches0.5s later and holds both stones
for0.3s (actual timer ages0.317/0.300); it passes without death. Full-loop
integration and final patrol draw-order capture are tracked separately.

Seven checks pass in `final_checks/`: pond, water_tile, smoke, world_bounds,
platform, basement_stores_retry, prison_circuit_save. The old stores retry
fixture now stages on the imported valve's actual dry landing instead of a
removed coordinate. The old stores route delegates to the new driver, and the
full-basement driver composes it in both directions.

B02 final integration: `basement_stores/connected/full_route.json` earns all
four basement circuits and Blue, uses the shortcut and retraces B03/B02/B01 to
Hub with zero deaths/climb/mantle. Native `02_dry_pocket.png` confirms the
patrol outline now draws above water; fresh runtime has no invalid-UID warning.
An initial composed return rejected the already-earned Blue key because its
standalone fixture expected an empty inventory. It now compares against the
inventory at return entry, preserving the same no-unintended-pickup invariant
for both standalone and connected use. The corrected full loop passes.

B02 post-animation timing and safe-water retry are verified; B03 and the gym
still require deeper rebuilds. Final all-wing difficulty/presentation/rescue
acceptance and the new playable export remain unfinished.


## B03 submerged capstone revision

`tools/build_precision_basement_capstone_swim.py` preserves all other rooms,
entrance ledges, circuit IDs, key and return path. Deep seal104160→72128;
hanging baffle12896→136144 and floor baffle88144→96184; one patrol112128,
amplitude12, speed0.35. Official LDtk1.5.3 schema passes. The upper seal remains
a short dry recovery after the developed swim phrase, instead of another
crumble ladder. B02 already supplies the water-to-crumble commitment.

`basement_capstone_route_test` uses actual child inputs, a held-depth observation
point and anticipatory swim braking. Default and+30-frame departure pass.
+90-frame probe dies on the left turn, as intended for the failure check. Manual
respawn at the deep seal preserves the valve, clears partial seals, restores dry
footing and then earns Blue/shortcut with exactly one death. Full new basement
forward and reverse run passes with zero deaths and no climb/mantle. Six
headless regressions pass. Native captures and JSONs:
`output/prison_precision/basement_capstone/`.

The staged pump fixture now finds its deep node by imported position; its floor
hazard probe moves from92174 (now inside a new baffle) to100174. It still tests
real contacts, actual hazard death and physical gate collision. No production
movement or art changes in this revision.


Late-departure recovery subsequently passes with exactly one actual patrol death,
dry respawn, retained valve and earned Blue/shortcut. The collision occurs during
the left turn after the rise; the test's failure handler covers that complete
turn. The direct-descent driver briefly lacked its geometry cache initialization;
that test-only setup error was fixed before the final clean run. The production
geometry did not change during these driver corrections.


## Y02 precision balcony

`build_precision_gym_balcony.py`: replaces permanent middle bank with two24px
CrumblingShelf entities (existing stone artwork), centres184156 and232132,
linked to existinggym_balcony. Hazard bed112–232 at176. Preserve both vertical
shutters and banked exit, far lever, seal, partial entrance ledge and aperture.
Remove obsolete208152middlelever. Grace tuned8.5→6.5 after measured routes.
`refine_gym_launch_bank.py` makes64–112,160–184 solid masonry: the old one-way
strip only8px above solid flooring gave a confusing lower landing.

`precision_gym_balcony_test` forward3.23s /3.82s from launch to confirmed seal,
with0.1s /0.3s stone dwells. Slower route last sampled remaining time2.63s.
Reverse catch244170→far bank296154→232122(up-diagonal)→184146(low hop/flat)→
104154(up-diagonal). Direct catch-to-overhanging-stone hit its underside; flat
last return landed beneath the obsolete one-way strip. Tested reverse is clear.

A real first-stone collapse kills, restores stones and plate checkpoint, then
completes forward and reverse: exactly one expected death. A single jump/dash
skipping the first stone fails before a completed retry. Final-bank slow/late
routes pass, no climb/mantle. Seven initial regressions pass; final-bank smoke
and world_bounds pass. `gym_balcony_retry` initially gave an ambiguous collider
atx252 where partial ledge and shutter meet; moving the probe into the side gap
atx260 fixes the fixture and passes. Original failed result retained beside the
specific rerun. Evidence in `output/prison_precision/gym_balcony/`.

Old `gym_balcony_route_test.gd` delegates to current driver. Full gym capstone
approach/return now compose that driver; the whole-gym run is still pending Y03
ordered-music redesign. Act1, shared physics, art and dialogue untouched.


## Y03 ordered musical reversal

Authored by `build_precision_gym_music.py` with surgical follow-ups
`refine_gym_music_return_banks.py`, `refine_gym_music_note2.py`,
`refine_gym_music_seal_bank.py` and `refine_gym_music_shaft.py`. Final geometry,
measured route, failed experiments and recovery evidence are recorded in the
Y03 implemented section of `prison_precision_design.md`. Do not replay these
one-time recipes over later hand edits. All changes are in the LDtk source;
shared player, note, crumble physics and Act1 art/geometry remain unchanged.

The former full-width shaft ledge was a real entrance obstruction beneath the
upper gate column, discovered only in the connected run. Removing it both fixes
retreat and develops the wall-jump lesson into a sustained ascent. Existing
room-entry checkpoint behavior stays intact. Final full-gym test includes a
late miss, real retry, Gold and every reverse connection. The old capstone scene
now delegates to `precision_gym_music_test.gd`; no obsolete route implementation
remains behind that scene name.
