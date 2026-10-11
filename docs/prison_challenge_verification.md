# Castle-prison challenge verification — 2026-10-09

The revised four-key castle-prison is ready for an end-to-end user playtest.
The user’s later instruction overrides the original goal’s Celeste-play clause:
Celeste was analyzed through its local binary, not physically played.

## Delivered design and build

- Research: `celeste_ch3_challenge_analysis.md`, with binary-derived graph,
  gates, inferred clutter states, dimensions and explicit inference limits.
- Final design: `prison_challenge_design.md`, with original geometry, room graph,
  roles, action sequences and reset rules. Final authored sections supersede
  early sketches; the final Gold/visual-language section is authoritative.
- Editable source: `ldtk/hooshang_act2.ldtk`, 17 prison rooms within the 39-room
  Act2. Four key loops, central cage, persistent keys and room checkpoints.
- Build: `builds/act2_challenge_playtest/Hooshang-Act2-Challenge.zip`.
- Captures: `output/prison_challenge/milestones.md`.

## Earned routes using actual player physics

These runs deliver input actions to the real game and inspect rendered output.
They do not inject positions, keys or puzzle completion during traversal. They
are automated gameplay, not a human evaluation of difficulty or enjoyment.

- Current full act: `integration/full_act_final/result.json` and `run.log`:
  all 39 rooms, zero failures/deaths, all four keys and locks, rescue, chase,
  nine story flags, ending completion and 16 banked lemons. This run includes
  the final small controls and distinct one-way platform art.
- Complete prison in two orders: `integration/mission/` (Green/Red/Blue/Gold)
  and `integration/mission_reverse/` (Gold/Blue/Red/Green). Zero deaths, rescue
  completed, no climb or land-mantle state. These predate the visual-only cleanup.
- Each wing earned its key and traversed the full reverse loop: `library_wing/`,
  `cafeteria_capstone/`, `basement_capstone/`, `gym_capstone/`, each zero deaths
  and no climb/mantle. Fresh library forward/reverse run after art changes:
  `visual_cleanup/library_route/route.json`, also zero deaths.
- Deliberate expiry/retry: `gym_intro/`, `gym_balcony/retry_route.json` verifies
  middle-bank expiry, recovery from the closed exit floor, retreat and reattempt.
  `recovery/` includes missed-landing pocket recovery by wall jumping.

The opening retains its existing movement assistance. The prison, garden and
chase route checks explicitly exclude climbing and land-mantle assistance.
Underwater movement uses the existing swim behavior, including bank exit.

## Automated fixtures, separate from traversal

- `integration/portals/`: all 40 exact directed prison connections, key gates,
  safe entries and death/respawn. These stage the actor near each portal.
- `integration/orders/`: all 24 key permutations preserve keys/locks through
  death and trigger rescue only after four locks. These directly exercise state;
  they are not 24 physical playthroughs.
- `integration/regressions/results.json`: 25 passing focused checks covering
  progression, dialogue skip, reunion, persistence, migrations, retries, return
  clearance, collectibles, rendering surfaces and movement/world bounds.
- Per-wing staged failures cover closed-gate collision, interrupted attempts,
  completed seals surviving death, safe respawn, shelf reset, nonbankable return
  levers and pressure-plate contact/departure behavior. Logs are indexed in
  `prison_challenge_progress.md`; these fixtures may position actors or state.
- After visual cleanup: circuit/timer save, plate, smoke and world-bounds checks
  passed again in `visual_cleanup/checks/`.

## Collectibles and preserved content

The current full-act inventory contains the same 35 lemon IDs as the earlier
verified optional-route coverage in `output/act2_polish/milestone3/collectible_coverage.json`.
All 22 non-prison room data dictionaries are unchanged from the challenge
baseline (`integration/nonprison_equivalence.json`). Existing non-prison runtime
scripts and player physics also match that baseline. Previous successful detour
results were inspected, and remain applicable; they were not all replayed in
this final turn. The new full-act run independently banks 16 of the 35.

All 3,506 baseline files under character art, character scenes, authored dialogue,
and Act1 LDtk match their saved hashes. No Act1 levels or player physics changed.

## Source, editor and package checks

Official LDtk1.5.3 schema/reference validation passes: unique IDs, typed fields,
four keys, valid local mechanism references and no climbing/checkpoint flags.
LDtk1.5.3 opened and saved the source with no error/warning dialog. Round-trip
comparison found only numeric formatting normalization and one tileset pixel
cache refresh; authored rooms and mechanics are unchanged. LDtk was closed
afterward. Evidence: `export/ldtk_gui_roundtrip_diff.json`.

A disposable clean checkout imported successfully, with backup directories
excluded from the importer. No script errors or stale-UID warnings remained.
Editor shutdown still reports existing resource/RID leak diagnostics; this is
not a claim of warning-free engine shutdown. Export itself completed without
errors or warnings. The final zip passes CRC validation and the extracted app
passes `codesign --verify --deep --strict`.

Packaged native startup, title display, mouse selection of DEBUG PICKER and
Prison_Hub, final platform artwork, cage/HUD display and keyboard pause were
observed through the native UI. Packaged headless boot also exits successfully.
The exhaustive route runs use the project runtime, not the packaged executable.
Package and source runtime/assets are hash-compared in `export/source_manifest.json`.

## Limits for the user’s playtest

No known progression blockers or major readability defects remain in the
verified routes. This is an ad-hoc-signed macOS debug build, not a notarized
release. Start Act2 through DEBUG PICKER; NEW GAME still starts Act1. The title
screen retains the existing Act1 subtitle. Controller feel, subjective challenge,
blind puzzle comprehension and the sound mix still need human judgment.

The Celeste comparison is structural and data-derived, not a claim that the
new level has empirically identical difficulty. Some older unrelated repository
tests have known limitations documented in `act2_verification.md`; the current
focused passing batch is explicitly enumerated instead of claiming every test
in the repository passes.
