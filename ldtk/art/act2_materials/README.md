# Act 2 terrain

Current setup: **grass only** for all solid terrain. The other terrain brushes
were replaced at the user's request. Water and entity props are unchanged.
`tools/replace_act2_terrain_with_grass.py` performs the conversion and rebuilds
LDtk cache entries as `[rule_uid, x + y * layer_width]` so erasing works.
The multi-material atlas described below remains available as source art; its
brick/stone regions are no longer used by the world.

Paint `grass` on the **Collisions** layer in `hooshang_act2.ldtk`.
The grass cap uses a dark green outline, lime highlight and scalloped fringe,
with warm, speckled earth below, inspired by the supplied Super Mario World reference.

Brick, honey stone, grey stone and grass have distinct exposed rims over the
same soil pixels. All solid terrain brushes in VisibleTerrain connect to each
other: changing material inside a landmass does not draw an internal border.
Legacy brick and ceiling brushes use the matching masonry rules. Scaffolding
keeps its open structural shape and turquoise/brass palette.

Tiles remain 8×8 and fully solid. Existing tile IDs are preserved; grass uses
739–933 in the shared 934-tile atlas. No room geometry or entities were changed.
The Act 2 room previously named Level_2 is now Act_2_Level_2 to avoid overwriting
Act 1's imported scene in the shared levels directory.

Rebuild art: `python3 tools/build_act2_materials.py`
Install/rebake rules with LDtk closed: `python3 tools/build_act2_materials.py --install`
Regenerate the review fixture: `python3 tools/preview_act2_materials.py`
Close Godot before reimporting the LDtk world. The import hook supplies collision.
Verify/import preview with `tests/act2_materials_test.tscn` (graphical mode saves
`output/act2_materials/godot_preview.png`).

Palette source: `source/grass_earth.png`, PixelLab pixflux job
737816b5-aeda-4e6e-aecc-5ba15dc05fde, seed 9843. The generated bitmap is only a
palette swatch; all final tile geometry is procedural in `tools/act2_grass_terrain.py`.
