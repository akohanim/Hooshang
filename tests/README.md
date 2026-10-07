# Regression checks

`python3 tools/run_tests.py` discovers `*test.tscn` scenes, runs them sequentially,
and records each exit status and log in `output/regressions/`. A timeout or
GDScript error is a failure. It does not silently treat skipped scenes as passes.

For a focused run: `python3 tools/run_tests.py smoke ladder_top dash_input save`.
Use `--timeout 120` for longer integration tests. `--fast` uses Godot's fixed-FPS
mode for an initial sweep; rerun failures in ordinary time before drawing
conclusions about input timing, animation, or asynchronous room transitions.

Tests that sample rendered pixels or await `RenderingServer.frame_post_draw`
need a windowed Godot run. The runner reports those as `requires_rendering`;
launch them individually without `--headless`. Preview/shot scenes are development
capture tools, not automatically discovered tests. The editor import-isolation
check is separate:

`Godot --headless --editor --path . --script res://tests/ldtk_import_isolation_test.gd`

Browser shell checks use Playwright:
`NODE_PATH=/path/to/node_modules node tests/web_fullscreen_test.cjs`.
They include explicit iPhone capability/standalone simulations; they do not
replace testing Safari and Home Screen launch on a physical iPhone.

Keep new test filenames descriptive and pair each scene with its own script.
Tests exercising saves/settings must use their own temporary storage location.

`dialogue_landing_test` enters speech during a real dash above a floor, checks
that the banner waits for collision-backed landing, and checks cancellation and
that the interrupted dash cannot resume. `dialogue_scene_controls_test` also
requires floor contact in the real conversation scenes. The authored dash
lesson explicitly opts into airborne staging; its existing tutorial behavior
is intentionally preserved.

`encounter_trapdoor_test` verifies that twenty seconds of pursuit never open
the hatch away from the exit, plus the real escape-exit overlap, 16px inset,
repeated requests and an airborne dash at the exit. The drop reaches Level 15's PlayerStart,
open and restore real floor cells, play the prone/get-up sequence, and return
control without adding a death. Run it windowed with `-- --capture` to save
native gameplay shots under `output/trapdoor/`.
It also checks that the one-way hatch cannot be reopened by a fresh Level 15
boot or old reciprocal route data; `chase_route_test` checks the same rule after
backtracking from Level 16.

`chase_checkpoint_test` completes the actual Rumi encounter dialogue, dies twice,
and checks the nearby checkpoint, completed dialogue, safe chase restart and
Level 15 retaining its own checkpoint after the drop.

`darkshang_blink_test` enters the actual Level 14 reveal dialogue and checks
visible idle eyes at encounter scale, closing/reopening during dialogue,
breathing alignment, and handing eye rendering back to the moving sprite.
Run windowed with `-- --capture` for `output/darkshang/encounter_eyes.png`.

`celeste_feel_test` exercises animation phases and stopped-surface launch grace
with real player input. `terrain_variation_test` checks stable visual choices,
collision preservation, resource isolation and packed-scene reload. Details and
tuning live in `docs/celeste-feel.md`.

`act2_routes_test` plays the World 2 rooms after Level 2 continuously using real
jump, dash, spring, and carpet inputs; it also traverses the Orchard's upper
branch. `act2_expansion_test` checks checkpoint activation/death recovery and prop
contacts. `act2_progression_test` checks forward and return transitions. Run
these with ordinary timing and `--timeout 240`. The save-free
`act2_expansion_preview.tscn` supports playable review and `-- --capture` screenshots.

Act 2's advanced rooms 9–13 are included in these tests. Their route solutions
explicitly disable automatic ledge assistance and reject climb, mantle, wall-jump,
or death events. Use a room identifier after `--` for a focused route/prop run.
The preview also accepts `-- --capture Act_2_Level_12` for a specific room.

`carpet_obstacles_test` verifies that passive riding and held up/down cannot bypass
Act 2's required carpet dismounts. The route test checks three real same-carpet
recatches per redesigned room and rejects a carpet reset during the sequence.
For actual playthrough screenshots, run the route scene windowed with
`-- --capture-weave Act_2_Level_10 Act_2_Level_13`.

`ink_thought_tiles_test` verifies the Act 2 paintable rose-thorn atlas, all 16 contours with four variants
and six frames, spike removal, full-body edge contact, and thought immunity.
Authoring: `docs/act2-ink-thought-hazards.md`.

`childhood_tempo_test` compares standing/running jump arcs and button-hold
variants against half-scale ROM measurements, checks gradual acceleration,
neutral air momentum, skidding, spring reach and idempotent profile application.
`world_movement_isolation_test` proves Worlds 1 and 3 retain their movement and
animation values before and after a World 2 visit. See
`docs/world2-movement-reference.md` for reference measurements and reproduction.

Act One dust: `act1_dust_test.tscn` checks source/import paint parity, absence of
spikes, fixed hazard cells during animation, and staggered blinking. Run
`thought_dust_preview.tscn` windowed to check real shader output and capture
24 native-resolution animation frames in `output/dust_preview/`.

`darkshang_contact_test.tscn` covers Level_14’s 40×64 torso catch region
(offset 28px upward), absorption during the visible reveal, complete dash
crossings between physics ticks, real player dash movement, diagonal misses,
teleport reset and restoration of the ordinary catch size in other rooms.
`window_placement_test.tscn` checks full-frame clearance and omission from
music rooms, including windows baked into wall art and world-level cubicles.

`encounter_trapdoor_test.tscn` also checks that the leaves fully open before
Hooshang holds his position for 0.6 seconds, cycles the upright arm poses,
and then drops under gravity. Run windowed with `-- --capture` to inspect
both flailing poses and the landing in `output/trapdoor/`.
