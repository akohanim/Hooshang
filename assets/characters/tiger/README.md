# Act III finale tiger

The approved pixel-art ImageGen concept is preserved in
`source/approved_finale/concept.png` (full prompts in
`assets/act3/source/finale_cast_v2_pixel/README.md`). Its native silhouettes,
stripe clusters and colour ramps form the new gameplay artwork.

`tiger.aseprite` is the editable source, 44×22 pixels, feet anchored at (22,21):

- walk: 12 frames, 73ms; planted paws sweep back, then recover in lifted arcs.
- run: 12 frames, 43ms; staggered fore/hind contacts, flexing knees and a softer
  body rise/fall replace the previous eight abrupt gallop poses.
- idle: 4 frames, 240ms; tail movement while waiting at the threshold.
- roar: 6 frames, 130ms; jaw opens and closes with the forepaws planted.
- look_down / look_up: 4 frames each, 300ms; tail and blink acting at the cliff.
- crouch: 4 frames, 180ms; an additional authored low pose.

Both story tigers use these clips through `ChaseTiger.sprite_frames()`.
The chase retains its existing speed, trail, collision and respawn behaviour.
Playback follows actual travel speed, so catch-up steps accelerate with the cat.
Walk/run changes retain stride phase and use a speed deadband to prevent flicker.
Vertical following is capped at 140px/s so route lips do not pop the whole sprite.
Story-tween walking also follows travel speed and pauses at pacing turns;
stationary acting clips restore their full rate before roaring or looking up.

After hand editing the saved source, run `python3 tools/export_finale_cast.py`.
It exports `tiger.png` and `tiger.json` without resampling or changing timing.
The PNGs under `frames/` document the original authoring pass; the saved source
and its exported atlas are authoritative for later edits.

`tools/build_finale_cast.lua` is the one-time source-conversion and animation
recipe. Do not run it, or the legacy `tools/gen_tiger.py`, over later hand edits.

Previews: `artifacts/act3_finale/tiger_run_refined.gif` and
`tiger_walk_refined.gif`. Tests: `act3_finale_animation_test`,
`act3_chase_pit_test`, `act3_tiger_test`, `act3_story_test`.
