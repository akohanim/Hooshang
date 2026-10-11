# Prison precision revision — verification

Ready for the user's playtest. This revision deepens the four prison wings;
Act1 and the 22 non-prison Act2 room layouts remain unchanged from the precision
baseline. Celeste Chapter3 was studied through local map data, not played.

## Delivery

- Editable level source: `ldtk/hooshang_act2.ldtk` (17 prison rooms).
- Design, action sequences and measured timing: `prison_precision_design.md`.
- Build: `builds/act2_precision_playtest/Hooshang-Act2-Precision.zip`.
- Native gameplay captures: `output/prison_precision/milestones.md`.
- Progress checklist: `prison_precision_progress.md`.

Cafeteria develops timed crumble chains and reversals. Library develops temporary
landings, constrained crossings and the first ordered musical key gate. Basement
requires submerged turns, patrol observation, water-to-stone transfers and a
reversed swim route. Gym develops wall jumps, two temporary balcony landings,
then a collapse/drop/dash reversal within the second ordered musical key puzzle.
Y01 remains a shorter introduction. Hub and return rooms remain breathing space.

Solid scaffold art remains solid; collapsing surfaces use the existing stone
art. Thin wooden one-way ledges cover only part of each dry vertical entrance.
All nine leave a side gap for descent; the flooded seam remains swimmable.
Room entries are checkpoints, with no flags. Four keys, completed milestones,
shortcuts and the rescue structure remain intact.

## Earned, rendered input-driven routes

Evidence paths below are relative to `output/prison_precision/`.

- `full_act/result.json`: all39 authored rooms visited, four keys and locks,
  rescue, chase, ending, nine story flags and sixteen banked lemons; zero
  failures/deaths. This uses the real game with scripted movement inputs.
- `mission/result.json` and `mission_reverse/result.json`: Green/Red/Blue/Gold
  and Gold/Blue/Red/Green; each earns all keys, saves to an isolated test slot
  after two wings, resumes from disk, preserves completed mechanisms and keys,
  finishes the rescue/reunion with zero deaths and no forbidden movement state.
- Individual connected wing runs earn each key, use its shortcut and retrace
  the full wing. Their traces/captures are indexed in the design and progress
  documents. They exclude climb and land-mantle assistance; individual wing
  fixtures also exclude bank assist. The resumed mission actor uses ordinary
  water-exit behavior and suppresses land mantle through the existing cooldown.
- Sampled recovery runs cover collapse/death/restoration, safe water resets,
  timer expiry, a late basement patrol departure, missed gym beam transfers,
  and a wrong musical note followed by an earned solution. See per-wing evidence.
- Gym's slower upper phrase reaches note5 in6.13s and banks with1.875s left.
  Earlier and normal beam departures pass; the late sample misses the landing.
  Library stack landings pass with targets shifted3px in either direction.
  These are sampled tolerances, not exhaustive input intervals.
- `gym_music/skip_stone_probe.json`: a direct note3→4 jump/dash attempt misses,
  lands safely below, leaves the melody unsolved and grants no key. Other
  sampled bypass probes are recorded with the corresponding wing.

These are automated routes through actual physics and rendering, not human
playtests or proof of equivalent difficulty to Celeste. Production physics was
not adjusted to fit a route. The initial integration harness had a resumed-actor
assist issue; its failed evidence is retained, and corrected reruns pass.

## Staged fixtures and regressions

- `entrance_ledges/routes.json`: nine upward catch landings and nine downward
  returns, zero failures/deaths. Actors and unlocked progress are staged before
  jumping. Return input steps into the gap and releases to fall. Continuous
  rightward running overshoots two library openings; that failed probe remains
  in `continuous_right_overshoot.json` rather than being presented as a pass.
- `portals_and_orders_extended/`:40 directed portal crossing/idle/death checks,
  and all24 key-state permutations pass. These stage actors or state; they are
  not40 earned approaches or24 complete physical playthroughs. The original
 60-second runner limit timed out; both finish within the extended300-second
  limit (119s and139s).
- `regressions/results.json`:25 focused passes plus an outdated library fixture
  that timed out after a script error. G03 now has a musical gate, so the old
  circuit-only fixture wrongly indexed a missing circuit gate. The fixture now
  covers G01/G02; `library_retry_final/` verifies its pass. G03 and Y03's actual
  staged note contacts both pass in `library_retry_final/music_rendered.log`.
  Thus all26 targeted regression scenes pass after correction, with musical
  contact validation separately rendered.
- Coverage includes movement/world bounds, forward/return entries, persistent
  circuits/timers/keys, migration, saves, pressure plates, collectibles, retry
  behavior, reunion, ending, dialogue skipping and separate rendering surfaces.
  This does not claim every historical repository test was rerun or passes.

## Source and package verification

LDtk1.5.3 opened/saved the source with no error or warning dialog. The semantic
round trip had zero changes. Official1.5.3 schema and project-reference checks
pass, including unique IDs, typed fields, four keys and exactly two musical gates.

The build was imported and exported from a disposable clean project. Runtime,
art and LDtk source hashes match the working project (`export/package_source_equivalence.json`).
Export has no error/warning diagnostics; ZIP CRC and deep/strict code-signature
verification pass. Packaged headless startup passes. Native packaged title,
DEBUG PICKER, current Y02 geometry/art/HUD and keyboard pause were inspected.
The exhaustive gameplay routes ran in the project, not inside the exported app.

Clean import still emits the existing importer image-loading warnings and
resource/RID shutdown diagnostics. There were no script errors or stale-UID
warnings; this is not a claim of a warning-free engine import/shutdown.

Act1 LDtk, shared player physics and22 non-prison room dictionaries match the
precision baseline. Some current character assets differ from the earliest
snapshot; those existing changes were retained, not rolled back. All3533 files
in the protected character/dialogue/Act1 snapshot taken before this integration
pass remain unchanged (`integration/protected_final_check.json`).

## Playtest instructions and limits

Unzip and open Hooshang.app. Choose DEBUG PICKER → Act2 Room23 — Prison_Hub for
the prison, or Act2 Room1 — Act_2_Level_0 for the full act. Picker sessions do
not write saves; NEW GAME starts Act1. Use existing movement controls, Up for
levers and valves, contact for seals/keys/cage, and hold X to skip dialogue.
After reunion, return through the castle courtyard and use its exit to continue.

This is an ad-hoc-signed macOS debug build, not a notarized release. The title
retains its existing Act1 subtitle. No known progression blocker remains on the
verified routes. Blind puzzle comprehension, controller feel, perceived fairness,
sound balance and enjoyment still require the user's judgment. Optional fruit
routes were not all replayed in this revision; the full run banked16, and the
non-prison layouts are preserved. No claim is made that every possible bypass
or input sequence has been exhausted.
