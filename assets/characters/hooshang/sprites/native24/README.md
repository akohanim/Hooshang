# Hooshang native 24px animation pack

Approved design: short charcoal hair, gray temple, a black mustache with no
other facial features, brown jacket, exposed bright blue shirt, longer torso
and shorter burgundy legs. The standing silhouette is 16×22 on a transparent
24×24 canvas. Moving hands/legs can extend beyond that standing width.

`idle.png` (5 frames), `run.png` (8), `dash.png` (4) and `jump.png` (4) are the
requested horizontal sprite sheets. Each cell is exactly 24×24. Dash and jump
are one-shots; run and idle loop. The manifest records every clip's speed.

Additional generated wall-slide, climb, swim and exit-water sheets keep the
adult identity consistent in existing states. Fall holds the last jump poses;
wall-jump reuses the jump sequence; wall-land holds the first braced pose;
swim-idle plays a slower stroke. These are intentional shared poses, not
separate generated actions.

The large approved image came from built-in ImageGen. PixelLab `animate_image`
generated motion directly from `base.png` at 24×24. `source/jobs.json` preserves
the prompts, job IDs and counts; frame 0 in each source folder is the input.
The packer excludes that stationary input from action loops, normalizes the
palette and opaque alpha, restores the approved head at integer offsets, and
enforces a one-pixel black outside contour. It never rescales individual poses.

Rebuild offline with `python3 tools/build_hooshang_native24.py`. This writes
the atlases, `manifest.json`, the runtime `hooshang_frames.tres`, and preview
PNGs/GIFs in `output/hooshang_native24/`.

Godot: nearest filtering, scale 1, offset `(0,-5)`, frame center `(12,12)`.
The standing bottom edge at y=23 therefore meets the collision bottom y=6.
Physics remains 9×12; the visual extends above and beside that collision body.
Lighting, dash tint, swimming rotation and existing squash/stretch still act
on the sprite. Act 2's child library retains its original presentation.

Verification:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/hooshang_native24_test.tscn
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/hooshang_native24_review.tscn
```
