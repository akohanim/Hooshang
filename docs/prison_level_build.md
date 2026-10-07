# Act 2 school-prison build

Implemented in `ldtk/hooshang_act2.ldtk`: the 17 rooms and 20 reciprocal graph
edges from the approved design, on the existing 8px tile grid. The prior 14 Act 2
rooms retain their geometry. One existing numeric UID collision (Act_2_Level_1
and CeilingPanel both used 121) was repaired by assigning the level a fresh UID
and updating its layer levelId references; its persistent IID is unchanged. Act_2_Level_13 now leads to Prison_Hub instead of
showing the former garden finale.

## Playing and editing

Run `tests/prison_preview.tscn` for a direct playable start in the hub, or reach
it through Act 2. Use the existing run/jump/wall-jump/dash/swim controls. Contact
the cage to insert collected keys. Jump skips the final walkout after the last
lock opens. The four key labels and lock counter are on the separate UI surface.

Open `ldtk/hooshang_act2.ldtk` in LDtk 1.5.3 and select `Prison_Hub` or a
`Prison_R/G/B/Y01..04` level. Paint `Collision`: 1 solid, 2 one-way, 3 hazard,
4 water. `Tiles` auto-tiles that grid; `Decor` is collision-free, including
nested tile layers created by the importer. Edit keys, checkpoints, cage slots
and shortcut EntityRefs directly in `Entities`. The script is not needed for
future hand edits. Shared boundary apertures determine prison connections.
Close LDtk before running any source-writing script, and close/reopen the Godot
editor when importing changed LDtk content, as required by the project workflow.

The bootstrap is `python3 tools/build_prison_ldtk.py`; it refuses a second run
unless `--rebuild` is supplied, and makes a timestamped backup under
`output/prison_build/backups/`. Rebuilding replaces the prison rooms, so use LDtk
for ordinary layout revisions. `python3 tools/validate_prison_ldtk.py` validates
the official LDtk 1.5.3 JSON schema, unique definition/level UIDs, typed editor
values, tile metadata and key references. Python requires Pillow and jsonschema,
both already available on this machine.

Original sprite/tile masters are in `art/source/prison/`. Their README describes
how to replace artwork without changing the atlas coordinates or layouts. The
runtime atlas and cage/door states are in `ldtk/art/prison/`. No Celeste room
geometry or sprite assets were copied.

## Runtime behavior

`ldtk/Act2World.tscn` uses `scripts/prison/prison_world.gd`, a scoped extension
of the existing world manager. Legacy rooms retain their existing transitions.
Prison rooms use paired boundary apertures and geometric rearming, so entering,
idling at an entrance and respawning cannot automatically bounce back. The
player controller and Act 2 movement parameters were not changed.

Four freely accessible wings contain one key each. A pickup persists through
death, banks a safe checkpoint, and opens both shutters in that wing's return
corridor. All shutters reference the actual Key entity. The cage reads its four
authored KeyId slots; contact removes owned locks in sequence. The fourth lock
opens the cage, Jamshid walks onto the adjacent floor, and `prison_completed`
fires once with `Game.completed` set. Both collected and inserted key state,
the checkpoint and rescue completion are included in the world save payload.

The reusable prefabs are `PrisonRoom.tscn`, `PrisonProp.tscn` and
`PrisonHUD.tscn` under `scenes/props/prison/`. Collision meshes are derived from
the imported semantic IntGrid; no parallel runtime map JSON is maintained.

## Verification and evidence

Acceptance logs are under `output/prison_build/final_acceptance/`,
`output/prison_build/final_routes/` and the final state/traversal recheck in
`output/prison_build/verified/`:

- `prison_test`: real contact pickups, persistence after death, cage contact,
  lock removal, Jamshid's walkout and control restoration; imported room count,
  reference resolution, full-body arrival containment and HUD surface/scale.
- `prison_graph_test`: all 16 key subsets, all 24 pickup orders, duplicate
  pickup idempotence, and physical shutter collision matching the held keys.
- `prison_portals_test`: all 40 directed crossings through the actual world
  callback, followed by idle and death/respawn checks. Teleports set up boundary
  crossings; this test is not a traversal proof of entire rooms.
- `prison_routes_test`: actual input-driven traversals of all 12 outbound
  challenge rooms, using the real child movement profile with ledge mantle and
  bank mantle overridden off in a test-only subclass. A bounded search varies
  jump timing; only a complete death-free trial ending on the far landing is accepted. The
  key-room trials must collect their actual key by contact. Successful sampled
  positions/states are saved in `output/prison_build/routes.json`. Setup
  teleports occur between trials, never to advance a successful route. This is
  not a recorded continuous hub-to-four-keys speedrun or a substitute for a
  human difficulty/readability pass.
- `prison_save_test`: actual disk save/resume in a disposable save directory;
  separate collected/inserted state, shutter restoration, a dry post-key spawn,
  and another death after resuming. It never writes the player's save directory.
- `act2_progression_test`: the old Act 2 route reaches the prison through its
  real exit; the prior room-to-room return chain remains usable.

Rendered room previews are in `output/prison_build/previews/` (capture all with
`tests/prison_preview.tscn -- --capture-all`). The source was also opened and
saved through LDtk itself during authoring; editor checks exposed and corrected
a Float/Boolean mismatch and the internal coordinate/rule metadata used when
LDtk saves tile layers. The final round-trip comparison preserves every prison
IntGrid, AutoLayer tile, Decor tile, entity transform and field value; its saved
copy also passes schema/UID/reference validation. See
`output/prison_build/editor_roundtrip.log`. The schema alone does not detect all
of these editor-only mistakes.

The broad repository sweep is **not fully green**: its initial 145-scene report
contains 96 passes, 23 failures, 12 timeouts and 14 rendering-only checks skipped
by the headless runner. The Act 2 progression failure in that sweep was fixed
and passes the final acceptance run. Required movement/world/swim checks were
also rerun without fast mode; see `output/prison_build/required_recheck/`.
Chimney, intro and lemon failures reproduce in a comparison copy with the
prison ordering addition removed (`output/prison_build/baseline_comparison/`).
Other broad-suite failures have not all been isolated. Do not interpret the
prison acceptance results as a clean bill of health for every existing system.

## Scaffold and access revision — 2026-10-06

The first build's room-local checks did not establish that the complete hub,
entry, challenge, key and return paths worked. This revision replaces the
masonry terrain presentation with the existing connected scaffold art and
rebuilds the circulation described in the design document's revision section.
The original 14 non-prison Act 2 room records are unchanged by this pass.
No player physics or movement parameters were edited.

New verification distinguishes three scopes:

- `prison_navigation_test.tscn`: a continuous input-driven run from the hub,
  through all four wings and their keys, back to the cage and the rescue event.
  No repositioning after initial setup. `-- --reverse` walks the reverse loops
  with keys seeded to unlock the return doors, exercising all 40 directed
  connections across the two runs. The driver can wait for patrols and recover
  from missed landings; it never writes player velocity or position in a route.
- `prison_recovery_test.tscn`: independent starting setups for eight floor pits,
  three gym alcoves, and four closed-door pockets, followed by input-only escape
  to a standing floor. Key state is cleared between these independent setups.
- `prison_source_sync_test.tscn`: every imported prison Collision cell must match
  the editable LDtk file, and the imported atlas pixels must match its PNG.
  This catches a stale import that would otherwise invalidate movement checks.

All movement tests use the existing no-assist fixture, which disables land and
water mantles. The broad mission and retreat tests complement the smaller
room-local challenge, portal-state, key-state and save/load regressions. Evidence
for this revision is under `output/prison_build/scaffold_revision/`.

Final revision results: **18 targeted checks passed** (17 test scenes plus the
reverse-navigation mode). The continuous four-key rescue and both traversal
orders completed with zero deaths and no forbidden climb/mantle state. All
15 recovery setups escaped successfully. These are bounded automated movement
checks, not a claim that every possible input sequence has been exhaustively
playtested. The existing broad-suite limitations above remain separate.

The final map also passed an actual LDtk 1.5.3 save round trip: all 17 room
geometries, tile placements, entity transforms and typed fields survived. A
fresh process against the main workspace confirmed that all imported prison
collision cells and visible scaffold-atlas pixels match the source. Final
rendered room previews are in `output/prison_build/previews/`.
