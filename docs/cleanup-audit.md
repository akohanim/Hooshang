# Code and resource cleanup — 2026-09-28

This audit accompanied a conservative implementation cleanup. It did not change
movement tuning, level layouts, dialogue content or save-file schemas. Mobile
fullscreen/Home Screen changes already in the working tree were preserved.

## What was inspected

- Runtime scripts under `scenes/`, `scripts/`, and `systems/`, including call-site
  searches, signal names and public helpers.
- Godot's actual dependency lists for text and binary scenes/resources and LDtk
  worlds. The pre-cleanup graph contained 193 resources; 146 remain afterward.
- Character image hashes, portrait manifests, animation resources, authoring
  tools, import destinations and save compatibility fields.
- Web export structure, browser controls, regression entry points and source vs
  generated-file organization.

## Changes made

- Removed 96 obsolete `sprites/hooshang/` PNGs and their 96 import sidecars.
  Every PNG was byte-identical to a canonical image in
  `assets/characters/hooshang/emotion_matrix/`; no graph or source reference used
  the old directory. Different filenames were matched by SHA-256, not guessed.
- Removed 47 unused flat `ldtk/levels/*.scn` imports. The importer writes packed
  rooms into source-project subdirectories and the world dependency graph points
  there. One untracked generated scene was preserved in ignored
  `output/cleanup/legacy/` before removal; tracked files remain in Git history.
- Removed three helpers with no callers or serialized references:
  `SaveGame.world_of`, `HooshangDialogueAnimator.get_current_frame_texture` and
  `SpringPlatform.bounce_visual`. Their underlying used implementations remain.
- Removed an unconditional debug dump from the exit import hook.
- Moved the two retired office-level generators into `tools/archive/` and
  adjusted their repository-root calculation for the new location.
- Corrected obsolete flat-room cleanup instructions in 19 authoring tools.
- Removed the hardcoded developer-machine path from the active gym generator.
- Split the web shell into HTML, CSS and JavaScript. The build helper packages
  its sidecars explicitly; fullscreen/install regression tests cover the split.
- Added read-only resource auditing, a sequential regression runner, and guides
  for runtime scripts, tools and tests. Ignored local output/bytecode clutter
  without deleting existing captures or source art.

The removed resources account for **28,608,700 source bytes (27.3 MiB)**,
excluding import-sidecar text. The upload archive shrank from **140.5 MiB to
117.1 MiB**, with the latest mobile changes retained. There is still only one
upload ZIP: `builds/hooshang-web-upload.zip`.

The [removal manifest](cleanup-removals.json) records individual paths, hashes,
reasons and canonical replacements for duplicate art.

## Deliberately preserved

- `LevelBase` and `Game`: contrary to the old comment, TestLevel still references
  LevelBase. SaveGame also still persists Game's compatibility fields. Removing
  these just because the playable Acts use LdtkWorld would break the gym/schema.
- `HooshangDialogueAnimator`: DialogueBox instances this fallback, and its tests
  still exercise it. Its assets are not unused simply because portrait loops
  normally take precedence.
- Source artwork, `.aseprite` files, authoring tools, material labs, test/preview
  scenes and dynamically loaded audio/portrait assets. These are development
  inputs, not necessarily resources reachable from the main menu.
- The large Player, DialogueBox, LdtkWorld and Act beat scripts. Splitting their
  stateful logic should be a separate refactor with behavioral coverage, rather
  than a mass move mixed with resource deletion. Player alone is about 2,500
  lines; its state transitions, timers and physics ordering are tightly coupled.

## Verification

- Godot resource audit: **146 resources, zero missing declared dependencies**.
  This includes binary packed scenes; it is not a proof about all dynamic paths.
- All 13 ordinary-speed focused checks pass: dash input, portrait matrix,
  intro video, ladder top, menu navigation, mobile input, mobile UI, portrait
  animation, save round-trip, screen separation, movement smoke, spring platform
  and voice blips.
- Chromium and WebKit shell checks pass, including fullscreen entry/exit,
  denial/unsupported behavior, iframe fallback, resize, iPhone install guidance
  and simulated standalone launch. These are not physical iPhone checks.
- Actual exported game loads in Chromium and WebKit. ZIP integrity and shell
  sidecar inclusion were checked. The existing Level_25-without-Exit warning
  remains visible in browser logs.
- Broad-suite results and normal-speed follow-ups are recorded below. Failed
  checks were not deleted or weakened to make the cleanup appear green.

## Remaining maintenance work

The full suite is not a clean baseline. Some tests assert old room layouts,
lighting values, story beats and counts; others time out or fail behavior checks.
Reconcile those with the current authored game before doing larger controller
or world-lifecycle refactors. Fixed-FPS results are a triage sweep only: timing
failures require normal-speed reproduction. Rendering tests and the editor-only
import-isolation test require their own execution modes.

This pass verifies specific unused resources and call sites. It does not claim
that every remaining asset is needed, or that every gameplay defect is resolved.

## Broad sweep results

All 120 discovered scene entries were accounted for: **76 passed, 20 failed,
14 timed out and 10 required rendering**. This was the fast triage mode with a
25-second per-test limit, not an ordinary-speed clean-bill-of-health run.
The [test results](cleanup-test-results.json) name every scene and mode.

At ordinary speed, conveyor, crouch, Darkshang chase and chimney assertions also failed.
An isolated checkout of the last commit reproduced exactly the same assertion
counts (11, 1, 2 and 7 respectively), confirming those failures predate this
cleanup. The intro check also needs attention; its follow-up
results are recorded in the JSON. Intro also timed out on the previous commit
with a longer 60-second limit.

The separate editor-mode LDtk import-isolation check passed in both import
orders with zero failures. The active namespaced room scenes and the authored
LDtk world were not modified.
