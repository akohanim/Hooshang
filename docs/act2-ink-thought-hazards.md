# Act 2 rose-thorn fields

Levels 3–13 use the `InkThoughtHazards` IntGrid layer in
`ldtk/hooshang_act2.ldtk`. Paint value **1 / rose_thorns** with LDtk's regular
brush, line, rectangle or fill tools. Erase with value 0. All sixteen cardinal
neighbor combinations are supported, including isolated cells, strips, corners,
vertical walls and filled regions. Auto-rules choose the matching contour.

The artwork is a tangled field of woody thorn vines, olive leaves, and red/pink
roses. Four variants per connection mix full blooms, buds and bare brambles.
Sharp pale thorns and transparent, irregular edges replace the former solid
ink ribbon. The palette is sampled from the dedicated PixelLab source swatch
`ldtk/art/source/act2_rose_thorns.png`; the final shapes are drawn directly on
the native 8px grid. Six subtle color frames retain static silhouettes.

The layer and PNG keep their original InkThought names for resource compatibility.

The cells are pass-through hazards, not solid terrain. Any overlap with the
player's body is lethal, including a foot or head entering while the centre
remains outside. Exact edge contact without overlap is safe. Mushroom thought
immunity applies, as with the other thought hazards. Carpets can travel through
the tiles. Animation never changes the lethal footprint. The old ThoughtHazards
layer retains its existing centre-based contact behavior.

All former spike entity rectangles in levels 3–13 are painted into this layer;
solid terrain, carpet routes, checkpoints and spring positions are unchanged.
Rooms 0–2 have an empty new layer and retain their original hazards.

## Rebuilding

- `python3 tools/gen_ink_thought_tiles.py` regenerates the 512×48 atlas.
- `python3 tools/build_act2_expansion.py` regenerates the authored expansion,
  installing the brush and converting its spike-shaped authoring markers into
  painted rose-thorn cells. This rebuild overwrites hand-edited expansion rooms, as
  before; keep lasting layout edits in the generator.
- Reimport `ldtk/hooshang_act2.ldtk` in Godot. For targeted command-line import,
  use `Godot --headless --editor --path . --script res://tools/import_act2_expansion.gd`
  after Godot has imported any new PNG asset.

`ink_thought_tiles_test` checks imported coverage, the atlas, body-edge contact
and immunity. `thought_tiles_test` covers the shared independent animation
clock. `act2_routes_test` exercises every route with actual movement input,
including the three dismount/recatch passages in each advanced carpet room.
