# Rumi gameplay sprites

Prepared from the approved generated sheets with `tools/prepare_rumi_sprites.py`.
The source images remain in `source/`; `.gdignore` keeps these large references
out of Godot imports. Re-running the script reproduces the PNG atlases, shared
SpriteFrames resource, fallback portrait and animation preview.

- `idle.png`: four frames, 4 fps, loops.
- `walk.png`: eight frames, 8 fps, loops.
- `give_glow.png`: six frames, 6 fps, plays once.

Each atlas is one horizontal row of 96×96 frames. The rig retains its existing
0.5 scale. Art is prepared at the actual game resolution, then doubled with
nearest filtering: the occupied body is 18 world pixels tall, every visible
pixel is a solid 2×2 source block, and the foot baseline is row 80 in every
frame. All clips share a 24-colour palette and binary alpha. Frames are aligned
by the turban rather than by the width of an extended arm or walking stride.

The generated yellow particles are excluded from the character atlas. The live
gift mote supplies the moving light and launches on `give_glow` frame 3 from
the extended palm. `LdtkRumiTrigger` plays walk during `step_to`, returns to idle
on arrival, and returns to idle when `give_glow` finishes. Existing fades still
handle appearing and vanishing. Legacy run/jump/fall/dash/wall_slide resource
names map to the new artwork for compatibility.

`rumi_material.tres` keeps his body self-lit in the approved colours: the old
samurai self-light clipped the turban to yellow and the coat to neon green.
His aura and travelling gift retain their scene lighting. Normal dialogue
continues using the expressive face portraits; `portrait.png` replaces only
DialogueBox's old samurai fallback.

Validation:

```
Godot --headless --path . res://tests/rumi_animation_test.tscn
Godot --path . res://tests/rumi_shot.tscn
```

The animation test checks actual staging transitions, release timing, both
facing directions, both runtime factories, foot alignment, alpha, and pixel
sampling after Godot import. The capture harness renders each pose through
the game's real 320×180 viewport, saving under `output/imagegen/rumi-animations`.
