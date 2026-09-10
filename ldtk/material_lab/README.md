# Office material lab

Open `office_materials.ldtk` in LDtk. Run
`scenes/levels/material_lab/LaunchMaterialLab.tscn` in Godot (F6).
The launcher uses the game's real 320×180, nearest-filtered Screen viewport.
Normal movement/jump/dash controls apply; **G** toggles collision-only graybox.
The room is 24×12 cells at 8px: a little wider than 20×12 to expose a 22-cell edge.

## Authoring

Paint **Solids**, choosing Brick, Scaffolding, Concrete, Ceiling or Floor.
Their linked `*Art` auto-layers use all nonzero material values as neighbors:
joining different materials does not produce a false exterior highlight.
Paint **BackgroundGeometry** for background masonry; erase cells for windows.
Its artwork also has small transparent holes. Place ForegroundProp and
BackgroundProp on Props, choosing an array of OfficeProp variants. Import
selects a stable variant from the entity IID; moving it does not reroll it.
No props collide. PlayerStart is a real spawn marker, not a shipped placeholder.

Collision is regenerated every import using the existing vendored importer
2.0.1 and its preserved Hooshang atlas patch. **Only Solids-values collides**;
all art and background swatches are explicitly non-colliding. Thus geometry
still works when the art layers are hidden or have no generated placements.

## Add or redraw a material

`tools/build_material_lab.py` owns atlas layout and rule templates. Each sheet
uses 16 columns, 8px cells: 46 boundary topologies × `VARIANTS` (currently 4),
then `INFILL_COUNT` (10) dark variants, then a shared flat interior tile:
**195 tiles**, padded to a 128×104 PNG. Diagonals matter only when both adjoining
cardinal neighbors are solid. This covers isolated cells, thin beams, ends,
convex and concave corners without rotation changing the light direction.

Duplicate a material AutoLayer, link it to Solids, assign the new sheet, and
add its integer value to Solids. Duplicate its four rule groups in this order:
Corners, Edges, Infill, Interior. Change each rule's center to the new value;
keep wildcard neighbor conditions. The 5×5 infill rules inspect the two-cell
ring; their alternatives contain nine dark clusters and one plain shared fill
(10% empty *detail*, never a hole in foreground collision). Deep interior
falls through to the single shared fill. All palettes begin with #191d29.

For generated changes, close this LDtk project first. The builder preserves
existing level instances by default; `--reset-room` explicitly resets the demo.
It uses the existing Act 1 project as its JSON-schema template. Reopen and save
in LDtk to rebuild auto-tiles. `tools/bake_material_lab.py` is a restricted
bootstrap/CI fallback for these non-flipped, deterministic Single rules; it
rejects unsupported settings. Its random seed algorithm differs from LDtk's,
so the editor may change variant choices on the next bake, not geometry.

Import after saving. On a fresh checkout Godot may import LDtk before its new
PNGs: finish the first import, touch this `.ldtk`, then import again. Close the
Godot editor before headless imports and reopen afterward, as required by the
repository's import-cache conventions. Do not kill an open editor process.

## Rendering and limits

The reusable MaterialAtmosphere scene contains ParallaxBackground /
ParallaxLayer for the existing Act 1 painting (0.2 speed), and two one-pixel
CPUParticles2D rain systems (12–16 versus 30–38 px/s). Background masonry
scrolls at 0.7; solids at 1.0. The background tile script snaps offsets to pixels.
The small demonstration room fits inside the viewport, so camera travel is
best inspected after enlarging a room. Horizontal tint is a stretch goal.

Transparent one-pixel **convex corner chips are cosmetic**. Collision follows
full IntGrid squares, not the alpha silhouette at those corner pixels. Exact
alpha-shaped collision and perfectly invariant square graybox collision are
not the same contract; this demo preserves the game's square terrain physics.
Existing Act 1/2 world art has not been migrated to this separate library.

## Verification

- [x] Imported room contains independent material/background TileMapLayers.
- [x] Real player stands on solids and jumps with art hidden.
- [x] Background/props are non-colliding; eight placed entities resolve.
- [x] Background window cells are empty and show the existing painting.
- [x] 320×180 viewport and nearest filtering checked in a running scene.
- [x] Actual GPU-rendered preview saved as `preview.png`.
- [x] Opened and saved in LDtk 1.5.3; all four material rule groups load.
- [ ] Pattern-size limit directly exercised through the LDtk UI (9×9 maximum verified in installed renderer source).
- [ ] Exact pixel-alpha collision (corner-chip exception above).
- [x] 22-cell ceiling edge contains four native LDtk-selected variants; rendered preview reviewed for an irregular infill transition.
- [ ] Direct F6 play confirmation in the Godot editor: launcher opens, but UI input automation did not start it. The separate Godot render/test process passes.

Run `tests/material_lab_test.tscn` headless; use `-- --capture` without headless
for an actual rendered preview. Reference methodology:
[Aran P. Ink](https://aran.ink/posts/celeste-tilesets),
[LDtk rule documentation](https://ldtk.io/docs/general/auto-layers/auto-layer-rules/).
Installed LDtk 1.5.3 renderer source confirms odd rule sizes 1–9 and uniform
selection among `tileRectsIds` alternatives, not arbitrary per-alternative
weights (`Const.MAX_AUTO_PATTERN_SIZE`, `getRandomTileRectIdsForCoord`).

Regression results: material_lab_test, smoke_test, world_bounds_test and screen_test pass. Existing shutdown resource-leak warnings still occur in world/screen tests.
