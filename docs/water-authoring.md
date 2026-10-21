# Act 2 living water

Open `ldtk/hooshang_act2.ldtk`. Paint the **Water** IntGrid for the swimmable
pool. Its `Act2WaterTilesSheet` is the current base-water tileset, including
the depth and shimmer frames; it is not an obsolete version of WaterLife.
Existing and newly painted pools automatically gain:

- Rooted, eight-frame swaying algae on water cells immediately above solid terrain.
- Several koi in broad water lanes. Each patrol stays inside its own uninterrupted horizontal run, including its full sprite width. Thin shafts remain empty.
- Animated waterfalls under unsupported bottom water cells. They stop at the first lower water surface or solid terrain, with a splash. An immediate floor blocks an outlet. Falls are scenery, not swimmable columns; swimming still follows painted Water.

For additional placement control select the new **WaterLife** Tiles layer and use the first row of `Act2WaterLife` (saved selections):

1. **Algae** (first tile): paint inside the water cell resting on the floor.
2. **Fish** (second tile): paint inside a water lane at least three cells wide. Each brush adds a koi; paint several for a school.
3. **WaterfallOutlet** (third tile): paint the bottom water cell above a gap. It must have a pool or solid landing below in the same room. The falling span is built automatically; there is no need to paint each falling segment.

The last two columns and subsequent rows are runtime animation frames, not placement brushes. Markers are visible in LDtk; only the animated effects appear in Godot. WaterLife never adds collision.

Save LDtk, close it before any scripted edits, and restart Godot after import-hook changes. New rooms can use these same layers. No additional entities or player changes are required.

## Art and verification

`assets/props/water_life/source/aquatic_imagegen.png` was created with the built-in ImageGen tool. The exact art brief is in the adjacent README. `tools/gen_water_life.py` reads its colors and builds the 40×64 dressing sheet and 36×8 koi animation with reproducible pixel geometry; it does not call PixelLab. Existing base water and Pond assets retain their contracts.

Run `tests/water_life_test.tscn` for containment, waterfall obstruction/landing, algae support, manual fish painting, erasure and rebuild checks. `tests/water_life_preview.tscn` renders sixteen native-game-resolution frames to `artifacts/water-life-*.png` (windowed). Existing `water_tile_test` and `pond_test` cover swim integration.
