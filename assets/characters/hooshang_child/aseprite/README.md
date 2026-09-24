# Young Hooshang movement

`young_hooshang_movement.aseprite` is the editable source of truth. Its 88×88
frames preserve the child's existing 0.39 gameplay scale and (0, -7) offset.
Edit pixels, frame durations and animation tags in Aseprite, then run:

```sh
python3 tools/build_child_hooshang_frames.py
```

The wrapper invokes Aseprite Lua for every image export and writes only Godot
resource text itself. It exports tagged frames into `act2/packed`, preserves
Aseprite frame durations, and writes `act2_frames.tres`. `ASEPRITE` can override
the executable path. Old `repack_child_hooshang.py` and
`build_child_swim_jump_overrides.py` predate this source and must not be used to
regenerate the active library.

- Jump and wall-jump are upright, non-looping rising poses with a raised fist
  and bent leading knee. Falling is a separate upright balancing pose.
- Run has eight alternating contact/down/passing/up poses and counter-swinging
  arms. The same head and jacket silhouette prevent generated-frame warping.
- Wall-slide keeps the head and contacting hands steady.
- Swim is authored head-up: the player's direction-aware rotation points its
  local up axis along travel. Swim idle is an upright, quieter float. Exit-water
  retains its authored horizontal-to-standing sequence with zero child rotation.
- Airborne poses keep the character anchored; the controller supplies travel.

Every cel also has an opaque pure-black outline on its own bottom layer,
`Black outline - 1px`. The contour is exactly ONE Aseprite/source pixel wide;
do not thicken it to compensate for the 0.39 gameplay scale. The latest
correction changed only this layer. Every colored-body pixel, pose, position,
scale, foot offset and collision stayed unchanged.
Run now compresses/rises over the stride, wall-jump has distinct push/tuck/rise
poses, and both swimming arms alternate without crossing the face.

Each source frame has two pure-white ankle pixels on `Socks - 1px marks`, one
for each leg. Edit those pixels in Aseprite; the exporter reads the layer itself
and refreshes `sock_pixels.json` and the SpriteFrames metadata, including the
reversed portion of ping-pong clips. The flattened Aseprite artwork is unchanged.

At runtime, `SockPixels.tscn` draws these marks as exactly one pixel each on the
game viewport. A single source texel would vanish when reduced to .39 scale or
stretched during a jump. The marks follow the current frame, mirror, rotation,
camera and squash transform, while their drawn size remains one game pixel.
The body PNG export omits the socks layer to avoid drawing the marks twice.
The body, black outline, proportions, scale and collision are unchanged.

Run `Godot --path . res://tests/sock_visibility_test.tscn` windowed: it checks
every animation in 376 actual render cases, including idle, jumps, fractional
positions, left facing, landing squash, and rotated swimming. It asserts both
visibility at the ankles and exactly one white pixel per distinct mark.

`tools/review_child_outline.lua` audits every source cel for a complete,
exactly-one-pixel ring (including diagonal neighbors) in Aseprite. The Godot
child animation test checks the contour on every exported runtime frame.
`tools/set_child_outline_1px.lua` refreshes the outline from the current body
layer without moving, scaling, or redrawing it.
The one-time `polish_child_movement.lua` recipe reads the saved pre-outline
snapshot; do not run it over later manual artwork. Use the normal export above.

Review artifacts are in `output/child_animation_fix/`: pass contact sheets,
nearest-sampled gameplay size sheet, and Aseprite-exported animation GIFs.
