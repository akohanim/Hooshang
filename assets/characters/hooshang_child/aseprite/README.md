# Young Hooshang movement

`young_hooshang_movement.aseprite` is the editable source. The current design
follows the user's explicit Small Mario reference: the same compact facial/body
layout and pose geometry, with Hooshang's clothing/hair palette. It replaces the
previous eight-frame reinterpretation.

The 88×88 canvas uses 2×2 source clusters and renders at 0.375 scale, offset (0,-3).
The standing silhouette is 15 gameplay pixels tall to fit a 16px opening;
the exterior black contour is exactly one source pixel, without a stacked border. The collision body is unchanged.
Only World 2 uses this library.

Edit pixels, tags and timing in Aseprite, then run:

```sh
python3 tools/build_child_hooshang_frames.py
```

The source contains 63 frames and 24 tags. Walking alternates the reference's
two poses at 0.1 seconds each, with speed modulation in the existing controller.
Jump and fall use separate rising/descending silhouettes. Swimming follows the
reference's reach/pull/kick sequence (12/4/8 SNES ticks); resting float is separate. Hooshang-only dash,
wall-slide, mantle and sitting adapt the same geometry.

Five layers separate the one-pixel outline, interior black details, clothing/shoes,
face/hair/hands and socks. The full Small Mario-style nose is restored; moustache pixels are replaced with skin across poses.
The two white source marks on `Socks - 1px marks` remain runtime 1px socks under
rotation and squash. PNG exports omit this layer to avoid drawing it twice.

`tools/build_child_small_mario.lua` is a one-time authoring recipe, using captured
reference data in `output/child_small_mario/`. Do not run older restyle, outline,
repack or pose-generation scripts over manual edits. Use the normal export above.

Validation: `child_animation_test`, `sock_visibility_test` (windowed), and
`world_movement_isolation_test`. Review output: `output/child_small_mario/`.

The completed pack adds sprint, skid, takeoff, rise, apex, landing/recovery,
climb hold/descent and crouch. Idle includes a brief blink. Air and landing clips
hold their final pose; movement never waits for animation. The child-only visual
selector shows sprint above 90% run speed, braking while input opposes travel,
and crouch while standing with Down held. Physics and adult presentation are unchanged.

`tools/build_child_animation_pack.lua` is a one-time expansion from the approved
31-frame snapshot under `output/child_animation_pack/`; do not run it over later
manual edits. Use the normal exporter to preserve the saved 63-frame artwork.
`tools/preview_child_animation_pack.lua` renders the six-action GIF preview.

Swimming correction: SMW's side-view stroke stays upright (no 90-degree turn).
The clip begins with pose 24 for 4 ticks, then 26 for 8, then 22 for a 12-tick
glide. Neutral input holds the same pose 22; pose 28 is not the resting swim.
Horizontal intent mirrors the child; vertical swimming preserves his facing.
Adult swimming retains its existing rotation. Preview: `swim_corrected.gif`.
