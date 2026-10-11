# Jamshid

Hooshang's best friend and cousin, based on the two supplied character references.
The gameplay avatar matches **child Hooshang in Act 2**: the same 88×88
editable canvas, 63 source frames, 24 animation tags, durations, outlines,
body geometry and ankle marks. His green jacket, cream shirt, navy trousers
and warm dark hair distinguish him from Hooshang's brown/blue/plum outfit.
The five existing dialogue portraits and their speech/blink rigs are retained.

## Editable source and exports

- `aseprite/jamshid_child_movement.aseprite`: five editable layers, matching the
  child source: clothing/shoes, face/hair/hands, interior details, gameplay
  outline and sock marks. Edit this file in Aseprite.
- Run `python3 tools/import_jamshid_aseprite.py` after saving. Aseprite exports
  `sprites/child/movement.png`, `movement.json` and `socks.json`; the wrapper
  builds `jamshid_frames.tres`. No Python bitmap processing is involved.
- `tools/build_jamshid_aseprite.lua` is the initial derivation recipe, **not an
  exporter**: rerunning it replaces hand edits with a fresh child-source copy.
- All 24 child animation names are available, plus `walk` as a compatibility
  alias for `run`. Timing and looping match `hooshang_child/act2_frames.tres`.
  Non-looping poses hold their last frame, except the actor's existing `jump`
  behavior returns to idle after the jump finishes.
- Original generated body artwork remains in `source/`, `idle/`, `walk/`,
  `sit/` and `jump/` for reference. It is no longer the gameplay resource.

## Use in Godot

Instance `res://scenes/characters/jamshid/Jamshid.tscn`. Its origin is at his feet.
The default 15px standing silhouette uses the child's exact 0.375 source scale.
The centered visual has offset `(0,-3)` and position `(0,-6)`, translating
Hooshang's collider-centered anchor into Jamshid's floor-centered anchor.
Sock marks render as one viewport pixel using the shared `SockPixels` prefab.
Call `play_pose("walk")`, `play_pose("sit")`, `play_pose("jump")`, or any child
animation tag; call `face_left(true)` to mirror around his origin.
Movement and collision belong to the existing cutscene or gameplay director.

To put him IN a room with something to say, instance
`res://scenes/characters/jamshid/JamshidNpc.tscn` instead — it wraps this actor,
stands him on the floor below where he was placed, and plays a written script
once the player comes within its `trigger_radius`. That is what the LDtk
`Jamshid` entity builds (`tools/ldtk_add_jamshid.py`); his placement and encounter timing are owned by the Act 2 world and story director.

Pass `Jamshid.portrait("worried")` as the portrait texture to `Dialogue.say`.
The shared dialogue manifest recognizes each emotion automatically and drives
speech and blinking from the existing typewriter system. The portrait resources
keep their own `jamshid_<emotion>` paths so speaker and emotion lookup works.

Run `res://tests/jamshid_pair_preview.tscn` for all 24 animations beside child
Hooshang on the actual 320×180 game surface. Add `-- --capture` to save all
frame phases under `output/jamshid_pair/`. Hooshang is left, Jamshid right.
`output/jamshid_pair/pair.gif` is an enlarged source animation comparison.
The older `JamshidPreview.tscn` also auditions the retained dialogue portraits.

Validation: `jamshid_test` compares every clip, frame duration, loop, canvas and
sock coordinate against the child library, plus actor mirroring and portraits.
`jamshid_outline_render_test` must run graphically; it checks every exported
pose in both facings at gameplay scale for exposed colored contour edges.

Act 2 uses this actor for the pond, prison, school and chase appearances.
School scenes inherit the same 15px height. The finale's separate half-salute
uses `act2_ending/source/half_salute_child.aseprite`, derived from the approved
child avatar with an editable raised-arm layer. Export that source through
Aseprite to `act2_ending/half_salute_child.png` after hand edits; the initial
`tools/build_jamshid_child_salute.lua` recipe replaces those edits if rerun.
`act2_jamshid_art_test` traverses all imported placements and the finale,
checking the current art, scale and anchors. Run graphically with `-- --capture`
to render the finale salute on its actual carpet.
