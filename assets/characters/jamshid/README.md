# Jamshid

Hooshang's best friend and cousin, based on the two supplied character references.
Generated with the built-in image generation tool; prompts are in `prompts.json`.
Original references and selected generated PNG sheets are preserved in `source/`.

## Delivered artwork

- Five dialogue emotions: friendly, joyful, worried, sad, determined.
- Each emotion has four poses: silent (0), small speaking mouth (1), wider
  speaking mouth (2), blink with closed mouth (3). Twenty portrait frames total.
- Idle: four frames, 5 fps, looping.
- Walk: eight frames, 10 fps, looping.
- Sit: four seated breathing/blinking frames, 4 fps, looping.
- Jump: eight frames, 10 fps, once; the actor returns to idle afterward.

All body sheets have actual RGBA transparency. The actor's material thresholds
faint alpha edges for a clean silhouette. Source artwork is kept at generated
resolution; individual frames are native Godot AtlasTexture `.tres` resources,
not separate resized PNG files. `tools/pack_jamshid.py` rebuilds those resources
without modifying any bitmap. Head anchors and floor baselines are normalized
per frame, and each animation has its own source-to-world scale.

## Use in Godot

Instance `res://scenes/characters/jamshid/Jamshid.tscn`. Its origin is at his feet.
Default standing height is 16 world pixels, matching the game's small actor scale.
Call `play_pose("walk")`, `play_pose("sit")`, `play_pose("jump")`, or
`play_pose("idle")`; call `face_left(true)` to mirror around his origin.
Movement and collision are intentionally owned by the cutscene or gameplay code
directing him. This is a reusable visual actor, not a new playable controller.

To put him IN a room with something to say, instance
`res://scenes/characters/jamshid/JamshidNpc.tscn` instead — it wraps this actor,
stands him on the floor below where he was placed, and plays a written script
once the player comes within its `trigger_radius`. That is what the LDtk
`Jamshid` entity builds (`tools/ldtk_add_jamshid.py`); his first placement is
Act_2_Level_0, on the bank at the right-hand side of the water.

Pass `Jamshid.portrait("worried")` as the portrait texture to `Dialogue.say`.
The shared dialogue manifest recognizes each emotion automatically and drives
speech and blinking from the existing typewriter system. The portrait resources
keep their own `jamshid_<emotion>` paths so speaker and emotion lookup works.

Run `res://scenes/characters/jamshid/JamshidPreview.tscn` for an animated audition
of all nine sets. This preview shows enlarged art; it does not enter a saved run.
`preview.png` is a real Godot render of that scene.

Validation: `jamshid_test`, `jamshid_npc_test`, `portrait_anim_test`,
`smoke_test`, and `world_bounds_test`, plus a main-menu boot and a windowed
preview render.
