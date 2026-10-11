# Act 2 verification status

> The later castle-prison challenge revision is documented in
> [prison_challenge_verification.md](prison_challenge_verification.md).
> Results below describe the earlier Act2 polish baseline unless noted.


## Current result

Ready for the user’s end-to-end playtest. The three implementation milestones
are complete, with no known progression blockers or major presentation defects
in the inspected routes. Remaining verification limits are explicit below.

The current level layouts have a continuous scripted solution through all 39
rooms, from the meadow to the completed poem. The run used real input actions
and scene skips in one world instance: 0 deaths, 4 collected keys, 4 opened
locks, 16 banked lemons, and all 9 story flags. It did not teleport between
rooms or grant keys/story progress. It is not a human difficulty or feel test.

Current evidence: `output/act2_polish/milestone3/route.log` and
`milestone3/route/result.json`. The run includes the latest furnishing, garden
presentation, farewell gesture and morning-light changes. The opening uses the existing ledge assist; the gardens, prison
and chase are checked without climb or land-mantle assistance. Full cinematic playback has separate checks; this route uses normal scene skips.

The focused final batch has 29 passing checks after three fixture corrections,
plus a passing two-project import-isolation check. The original failed logs are
preserved; `final_regressions/resolved_results.json` points to the successful
replacement runs. This is not a claim that every legacy test in the repository
passes. The older Act1 intro transcript and full death-sweep limitations remain
listed below.

Collectible coverage: all 35 authored lemons have verified pickup, banking and
retention across actual room transitions. The required run collects 16; separate
entrance-to-exit detours cover the others. `milestone3/collectible_coverage.json`
maps each fruit to its evidence. The final garden, meadow, castle and chase
reward runs use real inputs with zero deaths and no climb or land mantle.
No geometry or runtime movement changed during this final detour audit.

## Verified separately

- Act 1 benchmark: observed tutorial, music puzzle, optional reward and late
  chase rooms. Standard: `act2_quality_checklist.md`.
- Castle approach/entrance milestone: actual connected forward/return routes,
  retries, optional gatehouse lemon, complete wall/palace dialogue and skip/save
  endpoints. Captures: `milestone1/` and `threshold_readability/` under the
  output directory. This milestone is ready for review.
- Garden connections: forward doorways, entry retries, castle arrival and all
  ten return doorways pass the focused progression fixture. The fixture places
  the player near each doorway; continuous movement is covered separately.
  `garden_audit/progression_final/`.
- Prison: four visible keys, persistent collection/insertion, room checkpoints,
  all 40 directed portal/retry checks. Revised library and gym loops pass
  forward and backward without climb/mantle. Reverse fixtures grant keys only
  to exercise unlocked connections; forward loops earn them.
- Gym observed play: a failed return dash, safe respawn, successful run-up
  return and actual equipment-room exit. One death in that observed session;
  separate continuous gym loop checks have zero deaths.
- Orchard branches: separate continuous input runs from room 5 entrance
  through its actual exit bank the upper and lower rewards respectively,
  with zero deaths and no climb/land mantle. Observed misses additionally
  verify safe retries and banked-fruit persistence. See `garden_audit/`.
- Carpet lesson optional rewards: debug entrance, real carpet steering and
  return jump to the upper shelf, underwater reward, swim-out and actual
  garden exit. Both lemons retained, zero deaths, no climb/land mantle.
  Captures and commands: `carpet_lesson/optional_observed/`.
- Alley/pond observed play: debug alley entrance to the painted-wall room,
  zero deaths, no climb/mantle. Underwater lemon collected and banked, retained
  across the real exit. `alley_review/observed/` contains native/UI captures.
- Dialogue: Desktop author script is the source. Act Two scene text matches
  after Markdown formatting normalization. Complete finale preview shows
  108 pages, including the morning light and Jamshid half-salute; normal,
  gesture-skip and save checks pass in `jamshid_salute/morning_regressions/`.
- Build: refreshed after the farewell presentation change; macOS debug candidate
  exports, unpacks and completes native headless startup with exit 0. Native package menu was
  rendered. Earlier CUA input attempts returned `noWindowsAvailable`; the latest retry
  reports a locked Mac before launching the app. Native menu navigation remains
  unverified. This is distinct from in-engine input-driven gameplay tests.
- Preservation: 359 Act1-named baseline files and the shared player controller
  match the initial hashes. Act2-only sibling art preserves the original
  character sheets. Shared conditional menu/import changes have focused tests.

## Remaining verification limits

- Native app export, unpacking, title-screen rendering and headless startup
  pass. Native packaged menu input is **not verified**: prior clicks returned
  `noWindowsAvailable`, and the final CUA attempt reports a locked Mac. The
  continuous 39-room run is source-engine gameplay, not a packaged UI run.
- Audio cues dispatch, stop on skip and record without clipping. These checks
  do not establish a perceptual listening/mix review; that remains for playtest.
- The whole legacy repository suite is not claimed green. The unchanged Act1
  intro differs from its old expected transcript; an earlier broad death sweep
  timed out at 240 seconds and includes an outdated importer fixture. The
  focused final report covers 29 checks plus import isolation. Finished Act1
  was not rewritten to satisfy those expectations.
- This is an ad-hoc-signed macOS debug playtest build, not a notarized release.
  Human difficulty, feel and enjoyment remain the user's final judgment.

## Handoff artifacts

- Build: `builds/act2_playtest/Hooshang-Act2-Playtest.zip`; startup instructions
  in `act2_playtest.md`. Its SHA-256 matches `builds/act2_playtest/SHA256.txt`;
  no changed runtime source file is newer than the build.
- Room-by-room purpose and acceptance evidence: `act2_room_review.md`.
- Capture index: `output/act2_polish/milestones.md`; milestone 3 includes the
  complete route, final reward detours, farewell and final poem.
- Dialogue: the Act2 archive matches the supplied Desktop script after
  Markdown whitespace/escape normalization, checked again at handoff.
- Preservation: the final hash check covers all 359 Act1-named baseline files
  and the shared player controller; zero changed. `milestone3/preservation.json`.

Detailed historical evidence remains in `act2_polish_progress.md`.
