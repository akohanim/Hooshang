# Castle-prison challenge pass

Implementation and verification complete for user playtest, 2026-10-09. Started 2026-10-08. The previous Act2 build is the baseline, not
completion evidence for this harder revision. User steering: analyze Celeste's
local binary/supporting data; do not physically play it on this computer.

- [x] Locate installed Resort binary; regenerate 65-room inventory.
- [x] Read current prison import/state/geometry and identify underdeveloped rooms.
- [x] Save current source baseline (8,636 files), pre-existing diff and Act2 LDtk.
- [x] Inspect seven binary-derived schematics; record gate/node/path data and
  eight hypothetical clutter states with explicit inference limits.
- [x] Write pre-build room graph, purposes, challenge sequences and reset rules.
- [x] Implement and validate complete representative Green wing.
- [x] Implement and validate connected Red and Blue key loops, including reverse traversal.
- [x] Implement and validate complete Gold key loop, including reverse traversal.
- [x] End-to-end mechanics/state/retry/return/render verification.
- [x] Export updated playable build and milestone captures.

Current evidence: `output/prison_challenge/reference/`. Research:
`celeste_ch3_challenge_analysis.md`; design: `prison_challenge_design.md`.

## Library introduction — 2026-10-09

- [x] Add act-local touch-circuit prefab, ledger, import handling and save state.
- [x] Author two nodes and a sealed upper exit in G01 through the LDtk script.
- [x] Validate LDtk 1.5.3 schema, unique IDs, same-room gate references and 2–4-node requirements.
- [x] Component checks: unique touches, interrupted attempts, physical blocking, permanent opening, old/unknown save data.
- [x] Imported-world save checks: death/room entry clear partials; completion and keys survive disk resume and another death.
- [x] Input-driven G01 spawn → both nodes → G02, zero deaths, no climb or mantle.
- [x] Inspect native arrival/completion renders; extend the initially cropped gate so it reads within the camera.
- [x] G02 development and G03 capstone; complete Green key loop and return.

Verification: `output/prison_challenge/library_intro/route.json` records the
actual child-physics input route. It begins at G01's authored spawn, not the
Act opening. `tests/library_intro_route_test.gd` supplies inputs, never writes
positions or progress. Native captures: `01_arrival.png`, `02_first_node.png`,
`03_circuit_open.png`, `04_exit_reached.png` in the same output directory.
This is an introductory-room checkpoint, **not the complete wing milestone**.

Automated fixtures (separate from route evidence): `prison_circuit_test`,
`prison_circuit_save_test`, existing `prison_save_test`, `smoke_test`, and
`world_bounds_test` passed. Logs are in `output/prison_challenge/circuit_components/`
and `output/prison_challenge/circuit_save/`. The save fixture activates ledger
nodes directly to isolate persistence behavior; it is not a playthrough.

The source-baseline comparison lists only the two historical doc pointers,
Act2 LDtk, the prison world/import hook and validator as changed existing files.
New circuit code/tests/tooling are additional files. Act1 and player source are
unchanged. The previous exported build has not been refreshed for this revision.

## Representative Green wing milestone — 2026-10-09

- [x] G02 three-node high route and recessed return detour.
- [x] G03 four-node capstone, patrol crossing, directional reversal and gated key alcove.
- [x] Preserve G04 and external room apertures; add permanent key-approach footing.
- [x] Complete input-driven hub → G01 → G02 → G03 → key → G04 → hub.
- [x] In the same run, traverse hub → G04 → G03 → G02 → G01 → hub.
- [x] Nine simulated deaths cover partial stages and completed-room retries; all checkpoints remain safe.
- [x] Closed-gate physics probes identify the actual gate collider in each required passage.
- [x] Disk save/load restores all three completed circuits alongside existing key progress.
- [x] Missed-jump pocket recovery uses actual wall-jump inputs, no mantle or death.
- [x] Inspect native closed/open archive captures and move headings clear of the upper nodes.

**Input-driven result:** zero deaths, no CLIMB or LEDGE_MANTLE state, Green key
owned, all three library circuits completed, final room Prison_Hub after both
loops. Evidence: `output/prison_challenge/library_wing/route.json` and `route.log`.
The graphical Godot run used `--fixed-fps 60`; movement came from input actions
and ordinary physics, not position/progress injection. This is an automated
rendered gameplay run, not a human playtest of feel.

**Fixtures:** `library_retry`, `library_pit_recovery`, `prison_circuit`,
`prison_circuit_save`, `prison_save`, `smoke`, and `world_bounds` passed. Retry
and save fixtures deliberately activate ledger nodes or position the actor to
isolate failure states; they are not full-route evidence. The separate pocket
fixture establishes one initial missed-jump position, then uses only inputs to
return to the left stairs. Logs: `library_wing/regressions/`, `recovery/`, `save/`.

**Captures:** `01_stacks_arrival.png`, `02_stacks_high_route.png`,
`03_archive_arrival.png`, `04_archive_upper.png`, `05_archive_open.png`,
`06_green_key.png`, `07_hub_return.png`, `08_backtrack_return.png` in
`output/prison_challenge/library_wing/`. Source hashes are in
`verified_sources.json`; the official schema/reference validation and targeted
Act2 import passed. Source comparison continues to show Act1, player physics,
character artwork and authored dialogue unchanged.

Iteration findings: the floor-pocket node originally lay on an incidental
approach; it now requires a detour. The central step was too narrow for reliable
braking; it is now 24px wide, with wall-jump recovery if missed. A permanent
scaffold and clear descent lane replace reliance on the shortcut shutter as
footing. The navigation test now checks the full body; its return route also
uses explicit stair landings so arrival tolerance cannot start the next jump
beside a spike. These are recorded in the design's authored-wing notes.

The final native hub capture also shows the pre-existing LIBRARY and CAFETERIA
labels crossing scaffold art. Relocate those labels during the hub presentation
pass; this is an outstanding readability issue, not a new puzzle blocker.

Next: implement Red's timed lever/relay rooms, then Blue's swimming mechanisms
and Gold's pressure-plate sequences. The complete castle mission, all key orders,
full-act consistency pass and updated export remain unfinished. Existing broad
mission drivers still need adaptation to the new puzzles; do not treat the old
build's full-act pass as evidence for this revision. No external blocker.

## Timed controls and cafeteria introduction — 2026-10-09

- [x] Timed lever, shutter and completion seal prefabs with editable LDtk fields.
- [x] Return-only lever reopens passage without granting puzzle completion.
- [x] Defer closing an open shutter while the player's full body occupies it.
- [x] R01 lever → patrol/recess crossing → timed gate → seal → R02, input-driven.
- [x] Deliberate expiry and held-Up check before the successful attempt.
- [x] Imported-room death/exit resets, physical return, closure safety and disk resume.
- [x] R02 multi-shutter encounter (see development milestone below).
- [x] R03 two separately banked phrases and connected forward Red loop.
- [x] Complete Red reverse traversal; additional capstone phase check recorded below.

R01's timer is 9 seconds. The initial 8-second trial completed in 6.58 seconds;
9-second trials completed in 5.08 seconds with a different patrol phase. Every
successful recorded trial had zero deaths and no climb/mantle state. This is
an automated rendered route from R01's authored spawn, not a complete Red loop.
Evidence and five native captures: `output/prison_challenge/cafeteria_intro/`.
Both closed and banked renders were inspected; the heading was moved clear of
the new wall and lever art now draws behind the player.

`prison_timed`, `prison_timed_save`, `prison_circuit_save`, `smoke`, and
`world_bounds` passed. The timed save/recovery fixture deliberately establishes
failure positions and ledger states; it separately proves that the real player
is not displaced by gate expiry, can retreat through the return lever, cannot
bank from that lever, and retains banked completion and keys after disk resume
and death. These fixtures are not earned-route evidence.

Official schema/reference validation passed, including same-room timed controls,
unique puzzle identities, main/return lever requirements and one completion seal
per gate. All non-R01 level data matches the pre-introduction snapshot exactly.
Act1, player physics, supplied dialogue and character artwork remain unchanged.
Only field documentation changed after the final graphical import; runtime
geometry and field values match the played version. No updated build exported yet.

Next implementation: linked shutter instances for R02's shared timer, then its
serving-counter sequence and R03's two-phase relay route. Blue, Gold, hub label
cleanup, complete mission verification and final export remain pending.

## Serving-counter development — 2026-10-09

- [x] R02 shared 12-second timer opens two shutters; a third seals the exit until completion.
- [x] Main lever → first shutter → scaffold → counter → dash through raised shutter → seal → R03.
- [x] Three rendered input runs at different patrol phases: 6.85, 5.83 and 8.00 seconds; zero deaths and no climb/mantle.
- [x] Far-side and middle return levers permit input-driven retreat after expiry without banking success.
- [x] Physics probes prove all three closed barriers block their passages.
- [x] Local occupied-shutter grace does not extend other shutters or the relay deadline.
- [x] Disk resume restores linked shutters from their controller's banked state.

Evidence: `output/prison_challenge/cafeteria_development/`, including route JSONs,
native captures, recovery and regression logs. The counter capture was inspected
at native resolution. The 12-second timer leaves four seconds over the slowest
measured attempt; the player can observe patrols from safe ground before launch.
Recovery uses one fixture placement on the failed-attempt far side, then actual
inputs through both return controls. It is not an earned forward route.

Official schema validation passed. Only R02 room data differs from its immediate
pre-build snapshot. The baseline check matched 3,506 protected character,
dialogue and Act1 source files. This is still not a complete Red wing: R03's
capstone and the connected Red key/return loop remain pending.

Compatibility finding: old checkpoints beyond newly introduced barriers require
migration. Add revisioned completion inference only for legacy saves, from a
matching saved checkpoint beyond the puzzle or the already-earned wing key.
Fresh runs and current-revision interrupted attempts must receive no completion.
Extend that migration as later wing mechanisms are introduced.

## Legacy-checkpoint compatibility — 2026-10-09

- [x] Add a prison-only versioned migration for the five authored puzzle controllers.
- [x] Earlier rooms reopen for a matching legacy checkpoint; an earned key preserves the whole wing's access.
- [x] Current room stays unsolved without its key; fresh/debug runs gain no puzzle completion.
- [x] Current-revision interrupted attempts remain unsolved, even when a fixture places them beyond a gate.
- [x] Test disk resume, actual imported gate collision state, death and a second save/resume.

`prison_migration`, `prison_circuit_save`, `prison_timed_save`, and `prison_save`
passed in `output/prison_challenge/save_migration/final/`. These are explicit
state/persistence fixtures, not earned-route playthroughs. The first run caught
a GDScript type-inference error in the new migration helper; it was fixed before
the final four-test run. Original failed logs remain in the parent directory.

The full goal remains active. Next: author R03's two banked timing phrases and
verify the complete Red key loop; then Blue, Gold, hub readability, whole-act
consistency and updated export. No external blocker.

After the migration change, the graphical R02 input route was rerun at the
120-frame patrol offset: 8.00 seconds to bank, zero deaths, no climb/mantle,
and successful transition to R03. Updated `phase120.log`, `route_delay120.json`
and native `delay120_*.png` captures are in `cafeteria_development/`; the final
banked capture was inspected. Source hashes were refreshed after that run.

## Red wing capstone and connected route — 2026-10-09

- [x] R03 crumbling service shelf, permanent midpoint, upper patrol crossing and two-seal key alcove.
- [x] Separate 6-second and 4.5-second timers, with return controls and persistent phrase completion.
- [x] Shelf resets on lever use (including completed levers), death and room re-entry.
- [x] Complete input-driven hub → R01 → R02 → R03 → Red key → R04 → hub.
- [x] Continue in the same run hub → R04 → R03 → R02 → R01 → hub.
- [x] Retry fixtures: missed shelf landing, actual input recovery from its pit, first seal retained across death, second attempt reset, and key blocked until both seals.
- [x] Legacy-save revision2 covers the new pantry barriers; older current-room challenges remain unsolved without their key.

The full rendered run completed both loops with zero deaths and no climb/mantle,
banked all four Red controllers, and ended in Prison_Hub. Measured phrase times:
R01 5.82s, R02 5.80s, pantry shelf 2.92s, pantry upper 2.97s. Evidence:
`output/prison_challenge/cafeteria_capstone/full_route.json` and `full_route.log`.
This is input-driven automated gameplay, not a human judgment of difficulty.

`pantry_retry`, `prison_timed`, `prison_migration`, `prison_timed_save`, `smoke`
and `world_bounds` passed in `cafeteria_capstone/final_checks/`. The retry fixture
stages failure positions and banked state explicitly. Its low-patrol check disables
only the fixture's respawn grace, then confirms an actual hazard death; it does
not change gameplay physics. The pit recovery itself uses ordinary jump inputs.

Native closed, midpoint, upper-seal and key captures were inspected. Early
iterations had an overhead patrol that did not intersect the route, then a seal
landing inside its sweep. The final patrol crosses the dash lane and the seal
landing sits beyond it. A permanent right step supports key-alcove return travel.
The upper-seal capture shows the final arrangement. Older standalone trial
captures/results are under `prototype/` and are not final-layout evidence.

Official schema validation and targeted Act2 import passed. Only R03 room data
changed against its pre-capstone snapshot; 3,506 protected Act1, character and
dialogue source files match the goal baseline. `verified_sources.json` records
current authored/runtime/test hashes. Local Godot still reports a new-script
UID cache warning and falls back to its correct path; verify a clean import in
the final export workspace. The user-owned editor was not stopped.

Remaining: Blue swim mechanisms, Gold plate sequences, hub label cleanup,
complete mission/key-order/save/rescue/collectible checks, whole-act consistency
and a fresh playable export. The active goal is not complete.

Additional rendered capstone run with a 90-frame initial patrol offset also
passed with zero deaths and no climb/mantle. Phrase times: cafeteria_pantry_shelf 2.85s, cafeteria_pantry_upper 2.35s.
Evidence: `cafeteria_capstone/route_delay90.json`, `phase90.log` and
`delay90_*.png`; these use the final geometry and timers.

## Basement swimming introduction — 2026-10-09

- [x] Persistent FloodGate/FloodValve entities, same-room references and typed activation fields.
- [x] B01 submerged contact seal, diving baffle and sealed exit neck.
- [x] Input-driven B01 → seal → underwater passage → B02 → B01 → entrance bank.
- [x] Zero deaths, actual SWIM, no climb/mantle; native seal capture inspected.
- [x] Fresh-Up, held-Up rejection, dry-only interaction and death persistence fixtures.
- [x] Extend existing circuit disk-save coverage to sluices and lit valve state.
- [ ] B02 dry-pocket control and B03 combined wet/dry key route.

Evidence: `output/prison_challenge/basement_intro/route.json`, `route.log` and
five native captures. This is an automated rendered input route from B01's
room checkpoint, not a full Blue key loop or human playtest. Geometry and player
state were not injected during the route. A separate closed-gate physics probe
confirms the sluice seals the exit before the control is touched.

Component/save tests deliberately stage control states and positions, separately
from route evidence. The valve fixture also tests dry-only refusal underwater
and successful interaction from real dry footing. Official schema/reference
validation and targeted import passed. Only B01 room data changed against its
pre-build snapshot; 3,506 protected source files match the baseline. Current
source hashes are recorded in `verified_sources.json`.

Next: B02's dry pocket reached through a submerged route, then B03's combined
wet/dry capstone and full Blue loop. Gold, hub cleanup, whole-act verification
and the updated export remain pending. The goal remains active.

Final checks: `flood_valve`, `prison_circuit`, `prison_circuit_save`,
`prison_migration`, `pond`, `smoke` and `world_bounds` passed in
`basement_intro/checks/`; the valve fixture was rerun after adding explicit
scene cleanup, with its final log in `basement_intro/valve_final/`. The existing
local UID-cache warning remains recorded for the clean export-import pass.
The valve fixture still emits an exit-time ObjectDB/resource cleanup diagnostic
after all assertions pass, despite freeing its loaded scene. Treat that as an
unresolved test-cleanup diagnostic; this run is not evidence of warning-free
engine shutdown. No script errors or gameplay assertion failures occurred.

## Flooded stores development — 2026-10-09

- [x] B02 submerged approach, dry valve pocket, visible deep-water hazard and permanent exit sluice.
- [x] Earn valve by actual swimming, dry footing and an Up press; exit into B03 and return through B02.
- [x] Zero deaths and no climb/mantle on the rendered route; no unintended key pickup.
- [x] Controlled hazard deaths before/after activation return to a dry entrance and preserve only earned completion.
- [x] Save/migration checks cover the second sluice; only B02 room data changed.
- [x] B03 wet/dry capstone and full Blue key loop (see milestone below).

Evidence: `output/prison_challenge/basement_stores/route.json`, `route.log` and
five native captures. The dry-pocket and activated-valve renders were inspected;
the lever now sits behind the child and its instruction is clear of scenery.
The route uses real input/physics. The retry fixture separately stages hazard
positions and disables its respawn grace to test actual hazard deaths, then
uses Up from the authored dry pocket. It is not an earned-route playthrough.

`basement_stores_retry`, `prison_circuit_save`, `prison_migration`, `smoke` and
`world_bounds` passed. Logs are under `basement_stores/retry/` and `checks/`.
The subsequent changes were the sign position and lever draw order; the rendered
route was repeated for those final visuals. Schema/reference validation and
targeted import passed. Source hashes and the 3,506-file protected baseline
comparison are recorded in `verified_sources.json`.

B03's next design must respect its actual right-hand entrance from B02: preview
the key from that arrival, gate it against an immediate pickup, then require a
dry control, a submerged seal and a higher dry seal before returning to the key.
Gold, hub readability, complete mission/order/rescue verification and the updated
playable export remain pending. The goal remains active.

## Complete Blue wing milestone — 2026-10-09

- [x] B03 dry valve, sealed underwater chamber, high-platform seal and enclosed key alcove.
- [x] Preserve right-hand entrance water passage beneath the valve bank.
- [x] Earn both seals and Blue, then use B04's original shortcut.
- [x] Complete hub → B01 → B02 → B03 → key → B04 → hub.
- [x] Continue hub → B04 → B03 → B02 → B01 → hub in the same run.
- [x] Retry fixtures cover either seal first, interrupted attempts, real hazard death, dry respawn and completed-route persistence.
- [x] Save/migration coverage includes both new barriers under revision5.

Final rendered result: all four Blue controller IDs completed, Blue collected,
actual swimming, zero deaths, no climb/mantle, final room Prison_Hub after both
loops. Evidence: `output/prison_challenge/basement_capstone/full_route.json` and
`full_route.log`. Captures `full_01_closed.png` through `full_07_backtrack_hub.png`
include the bank, underwater seal, launch, opened key alcove and both hub returns.
Native launch and key captures were inspected. The heading was changed to
“BOTH SEALS OPEN KEY” after its plus sign rendered poorly; the full route was
rerun after that text-only correction.

`pump_retry`, `prison_circuit_save`, `prison_migration`, `smoke` and `world_bounds`
passed in `basement_capstone/retry/` and `checks/`. The retry test deliberately
positions the actor at individual seals/hazards. It proves reset and persistence
behavior but is not an earned playthrough. The input-only complete wing route
is separate. No player controller or shared movement parameters changed.

Official LDtk schema/reference validation and targeted import passed. Only B03
room data differs from its pre-capstone snapshot; 3,506 protected Act1, character
and dialogue source files match the baseline. Final source hashes are in
`verified_sources.json`. The existing local UID-cache warning and fixture
exit-time resource diagnostic remain for the clean-import/export pass.

Next: Gold's pressure-plate introduction, balcony development and two-phrase
capstone. Then hub readability and full-act/order/save/rescue/collectible checks,
followed by the playable export. During the broader verification pass, strengthen
`prison_portals_test`: it currently iterates whatever portals exist but prints a
hard-coded crossing count; it must assert the expected room pairs explicitly so
a missing connection cannot silently reduce test coverage. The goal remains active.


## Gold introduction verified

- [x] Y01 pressure plate holds its shutter open while occupied; departure starts an eight-second grace period.
- [x] Actual child inputs complete the wall-jump/scaffold sequence, bank the seal, enter Y02, return through Y01 and reach the hub.
- [x] Rendered route: zero deaths, wall jump observed, no climb or land mantle. Plate held for nine seconds, deliberately expired, then rearmed before the successful crossing (6.13 seconds).
- [x] Return descent missed an intended upper landing; the actor landed safely on the lower floor and recovered by walking beneath the left obstacle. No teleport or mechanism-state injection in this route.
- [x] Staged retry checks: side/airborne contact rejected, real landing activates, continuous occupation emits one attempt event, release expires, rearming works, death restores safe entrance, return lever cannot bank success, completed shutter survives death.
- [x] Disk save fixture includes the new shutter; revision6 migration preserves old Gold-key saves without auto-completing modern attempts.
- [x] Native captures inspected. Moved instruction below the backboard to remove overlap, then reran traversal.

Evidence: `output/prison_challenge/gym_intro/route.json`, `route.log`,
`01_held_plate.png` through `05_return.png`; `checks/`, `retry/`, and `migration/`
contain passing regression logs. `pressure_plate_test` uses staged positions to
isolate contacts and failures; it is not an earned traversal. The separate
`gym_intro_route_test` drives inputs throughout. Required smoke/world-bounds,
timed persistence, migration and plate checks passed. Targeted import and
official LDtk schema validation passed. Only Y01 changed against its authoring
snapshot, and 3,506 protected Act1/character/dialogue files match baseline.
Import still reports the known stale crumble-script UID fallback and exit-time
resource diagnostics; clean import/export verification remains outstanding.

Next: Y02 balcony development and Y03 two-phrase Gold capstone, then the full
Gold key loop and reverse route. Whole-act verification and updated playable
export remain outstanding; this is not completion of the overall goal.


## Gold balcony development verified

- [x] Y02 preserves the 64px balcony and adds a second 40px crossing under one 8.5-second plate-release timer. Landing on the middle bank restores dash before the second jump/dash.
- [x] Both passage shutters share the timer; the downward exit stays physically blocked until the far relay banks completion. Middle/far return levers open retreat attempts without granting completion.
- [x] Rendered input route crosses both gaps, banks success, enters Y03, returns to Y02 and dashes back over the first pit: zero deaths, no climb/mantle.
- [x] Deliberately expires on the middle bank, drops onto the closed exit shutter, jumps back to the bank, uses the return lever and returns to the start. Then completes a fresh attempt and both room transitions. No position or mechanism-state injection in this route.
- [x] Separate fixture walks off the launch bank into the actual spikes, verifies one death and safe room-entry respawn, probes the closed exit collider, and checks the far return lever cannot bank success.
- [x] Revision7 migration and disk-save checks include the balcony. Smoke and world-bounds checks passed.
- [x] Native captures inspected; moved the instruction into the left observation area so the new wall cannot obscure it.

Evidence: `output/prison_challenge/gym_balcony/retry_route.json` and
`retry_route.log`; captures include `retry_00_expired_middle.png`,
`retry_00_recovery_floor.png`, `retry_02_middle_bank.png`,
`retry_03_banked.png` and `retry_05_return.png`. The initial complete attempt
measured 5.83 seconds including setup on the plate, within the 8.5-second grace.
The final retry run also passes after adding the lower recovery-floor check.
The navigator could not plan the dynamic shutter-to-bank jump from its static
IntGrid graph; a direct movement-input jump verified that recovery instead.
This changes only the test recipe, not player physics or puzzle state.

Official schema/reference validation and targeted import passed. Only Y02 room
data changed from its snapshot; 3,506 protected Act1/character/dialogue files
still match baseline. Checks are in `checks/` and `recovery/`; source hashes in
`verified_sources.json`. The known local UID fallback and import-exit resource
diagnostics remain for clean export verification.

Next: Y03 two-phrase Gold capstone, full Gold key loop/backtracking, hub
readability, then whole-act/order/save/rescue/collectible verification and the
updated playable export. The overall goal remains active.


## Gold complete wing milestone

- [x] Y03 combines a timed wall-jump ascent and an upper reverse-direction jump/dash past a moving hazard. Each seal banks independently; both are required for Gold.
- [x] Complete earned loop: Hub → Y01 → Y02 → Y03 → Gold → Y04 → Hub, then reverse the full loop. Zero deaths, real wall jump, no climb or mantle, all four Gold controller IDs completed.
- [x] Real balcony entrance reaches the upper sequence first; standalone room route reaches the ascent first. Both orders succeed. The final design reflects that actual entry geometry rather than requiring an artificial setup detour.
- [x] Staged retry fixtures verify actual seal contact, the second physical roof blocking the key after one seal, actual patrol death, safe respawn, interrupted timer reset and completed-seal persistence.
- [x] Save/migration coverage includes both new controllers under revision8. Smoke/world-bounds and timed-save checks pass.
- [x] Native launch and key captures inspected. Corrected an obstructing upper partition and widened the key-pocket exit for the full body before the successful full-loop run.

Evidence: `output/prison_challenge/gym_capstone/full_route.json` and
`full_route.log`; seven `full_*.png` captures cover the closed key, seals, launch,
Gold pickup and hub returns. The route drives actual child inputs without
position/key/mechanism injection. The retry fixture deliberately stages contact
and failure positions and is not counted as an earned playthrough. Standalone
and full-route timer readings are recorded in their logs. The full loop completed
all four Gold controllers and finished in Prison_Hub after reverse traversal.

Schema validation and targeted import passed. Only Y03 changed from its authoring
snapshot; 3,506 protected Act1/character/dialogue files remain unchanged. Source
hashes are in `verified_sources.json`; passing checks are in `checks/`. The
known import UID fallback and exit resource diagnostics remain unresolved for
the clean export pass.

All four individual key loops now have rendered input-route evidence. This does
not yet prove the full act: hub readability, expected portal-pair assertions,
exploration orders, combined key/state behavior, whole-act collectibles/dialogue/
rescue traversal, and a clean updated playable export remain outstanding.


## Connected mission and visual readability pass

- [x] Two rendered input-driven prison missions completed: Green/Red/Blue/Gold and Gold/Blue/Red/Green, each earning all keys and rescuing Jamshid with zero deaths or climb/mantle states. Evidence: `integration/mission/` and `integration/mission_reverse/`.
- [x] All 40 expected directed prison portal connections checked, including safe entry, death and respawn. Separate state fixtures cover all 24 key permutations; these are not 24 playthroughs.
- [x] Broad 25-test regression batch passed (`integration/regressions/`).
- [x] Removed permanent circuit wires, oversized gate badges and full-height status bars. Controls now use smaller brass symbols; active countdowns stay beside their gate.
- [x] Shortened and repositioned headings and hub labels to clear platforms and HUD.
- [x] One-way platforms now use a thin warm wooden lip with transparent space underneath. Solid crumbling shelves retain their steel scaffold silhouette on a separate atlas tile. All 752 one-way IntGrid cells map to the new tile; no solid IntGrid cell uses it.
- [x] Inspected fresh native room captures with the new platform silhouettes (`visual_cleanup/`). Physics and authored room geometry remain unchanged. The 3,506 protected Act1, character and dialogue files still match the challenge baseline.

The connected full-act run and final exported build remain outstanding. The
visual preview deliberately stages completed mechanisms; those screenshots are
presentation evidence, not earned gameplay. A fresh input-driven library loop
and complete reverse return passed with the updated platform artwork: zero
deaths, Green key earned, all three circuits completed, no climb/mantle states
(`visual_cleanup/library_route/route.json`). Movement smoke and world-bounds
regressions also passed. Earlier complete
wing and mission runs remain valid mechanics evidence, but predate this artwork.


## Final end-to-end and delivery milestone

- [x] Latest-art full-act input run: all 39 rooms, zero deaths/failures, four keys and locks, rescue/chase/ending, nine story flags and 16 lemons. `integration/full_act_final/result.json`.
- [x] Revalidated all 35 collectible IDs against earlier successful optional-route coverage; all 22 non-prison rooms and non-prison runtime code remain unchanged. This is reuse of inspected evidence, not a claim of replaying every detour.
- [x] LDtk1.5.3 GUI open/save succeeded; only number formatting and one tileset cache changed. No authored geometry or mechanic changed on round-trip.
- [x] Clean import, export, archive CRC, signature verification, packaged native boot, title/picker/prison launch and keyboard pause passed.
- [x] Final package runtime/source comparison: 3,882 files match; protected Act1/character/dialogue baseline: 3,506 unchanged files.
- [x] Playtest build, instructions, checksum, research, final design, capture index and verification limitations delivered.

Current authoritative report: `prison_challenge_verification.md`. Earlier entries
are iteration history and their outstanding-work notes are superseded by this
section. The earlier full-act capture wait was terminated after diagnosis; the
replacement run with explicit draw capture completed successfully. User playtest
remains the final judgment of difficulty, readability and enjoyment.
