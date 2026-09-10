# Brick and stone — Act 1

In `hooshang_act1.ldtk`, select **Collisions**, then paint **brick_new** (7)
or **stone** (8). Brick_new replaces the previous experimental brick option;
original brick (2), ceilings, scaffolding and concrete retain their existing art.
No existing room geometry was repainted.

Both materials follow the [Aran Ink guide](https://aran.ink/posts/celeste-tilesets):
five colors including shared #151c27 infill; coherent shaded edge clusters;
four randomized variants for every boundary topology; 5×5 near-edge infill
rules with nine dark abstract variants plus one plain fill (10% quiet detail);
and a single quiet deep interior. Small transparent convex-corner chips are
cosmetic; physics retains the project's full-square 8px collision contract.

Each material has 195 tiles: 46 boundary cases × 4 variants, 10 infill choices,
and one interior. Existing atlas IDs 0–25 remain in place. Brick_new uses
26–220; stone uses 221–415. The standalone 16-column PNGs are artist contact
sheets; the actual Collisions atlas is the single-row `bricks_8px.png`.

Rule groups are ordered Corners → Edges → Infill → Interior. Their neighbor
checks treat the VisibleTerrain group (values 2–8) as solid, avoiding
highlights at material joins while ignoring invisible helper paint (value 1). All placements are selected by LDtk; designers only paint IntGrid values.
Save in LDtk to generate placements before importing into Godot.

Regenerate with `python3 tools/gen_celeste_masonry.py`. To reinstall definitions,
close the Act 1 project in LDtk and run it with `--install`. This refuses a rule
reinstall once either new material is painted, so an authored room's baked art
cannot be silently made stale. Change rules through LDtk at that point.
The legacy `gen_bricks_8px.py` also rebuilds these appended tiles automatically.

`celeste_masonry_preview.png` is the native-pixel material study; the `_4x`
version is nearest-upscaled for inspection. `tests/masonry_tiles_test.tscn`
checks all 390 new tiles and their regenerated collision polygons in Godot.

Import repair: the importer must install the freshly built atlas source even
when a saved TileSet already contains that source UID. Reusing the old source
left 26 tiles against a 416-tile texture, silently dropping all 652 brick cells
in Level_0. The patched importer replaces the atlas source, reloads texture
resources and classifies the current source PNG pixels. If a texture import
lags a size change, it embeds those current pixels for that import. The test
now compares real authored masonry placements with the imported room cells.

Edge-rule regression repair: **VisibleTerrain** is IntGrid group 1 (values
2–8). Masonry rules now use LDtk's group match ±2000, not the ±1000001
"anything nonzero" wildcard. Value 1 is invisible helper paint: it must not
hide an exposed brick/stone edge. Outside-room samples remain solid. The art
generator also restores exposed contact bands after shading every side, so
thin/island tiles cannot overwrite one edge with another side's dark shading.

`python3 tests/masonry_rules_test.py` checks all 256 neighbor masks for both
materials with empty-space AND invisible-helper surroundings (1,024 cases),
every random edge variant's actual pixels, and all authored masonry placements.
`tools/fix_masonry_edges.py` repairs existing baked selections without changing
IntGrid paint; close the project in LDtk before running it. Existing valid
variant choices are preserved. Save/reopen the project in LDtk after external
repairs so its in-memory rules cannot overwrite the corrected file.
