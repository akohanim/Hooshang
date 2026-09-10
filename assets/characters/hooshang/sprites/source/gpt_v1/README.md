# Hooshang Act 1 animation source sheets

Eight generated sheets, eight poses each, arranged four columns by two rows: run, jump, fall, dash, climb, wall_jump, wall_land, wall_slide. Read frames left to right, then the second row.

Generated using built-in image_gen from the supplied avatar (identity) and idle sheet (style). Exact prompts are in prompts.json.

These are animation source artwork, not imported Godot SpriteFrames. The generator returned 1774x887 RGB images with a baked checkerboard despite the transparent-background request. Background removal, per-frame alignment, native game-resolution cleanup, and animation timing remain necessary before gameplay use. Some loops require pose cleanup: climb does not fully alternate its arms, fall changes orientation, and wall poses need stronger airborne bracing. The existing game assets are unchanged.
