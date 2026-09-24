# Act 3 — monochrome psychedelia

User direction: 8-bit black/white terrain, optical patterns and surreal thoughts.
All lethal thought variants retain the original hot-red outline and halo.
Cone spikes, glass spikes and paintable thought hazards also have red edges.
The older Act 1/2 palettes remain available and unchanged.

Open `ldtk/hooshang_act3.ldtk`. In **Collisions**, paint `brick`, `Grass`,
and `Scaffolding`. These are the only terrain brushes.
Each brush has all **47 connected shapes**, including inside corners,
one-cell strips, isolated blocks and enclosed fill. As in Acts 1/2, brushes
belong to **VisibleTerrain**, so touching different materials connect without
an internal border. Black negative space dominates, with a few material cues:
brick has broken mortar joints, grass has short branching roots, and scaffold
bays have diagonal braces. Sparse staggered placements appear only near open
edges; deep interiors share the same black fill. Brick uses the lowest density,
grass slightly more, and scaffolding the most. Two variants per material avoid
repeating one mark. These are native LDtk rules, so new paint gets the same art.
Paint or erase the IntGrid normally;
LDtk chooses and updates the surrounding art automatically.

**Act3_Level_0 is initialized as a showcase room.** It contains all three
terrain brushes, a cutout demonstrating inside corners, ascending shelves,
a ladder, two thought hazards and a spike strip, with a safe floor spawn.
`showcase_room.png` is a rendered in-game capture. Ordinary asset rebuilds
preserve edits to this room. Only the explicit initializer
`python3 tools/initialize_act3_level.py --apply` resets it to the starter layout.
Collision paint is solid. Background/Foreground remain available for manual
decoration with the same three looks. Retired materials already painted in
the room are converted to brick while preserving their occupied cells.

Place **DarkThought**, **LightThought**, **GreyThought**, or **Ladder** from
Entities. Act 3 defaults `PsychedelicPalette` to 1. Set it to 0 for the original
art. Thoughts have four rotating-eye frames, unchanged movement and hitboxes.
Ladders repeat a white helix rung on the existing 8px climbing collider.
Cone/glass spikes use the same palette field in all four directions, preserving
their original lethal depths and collider sizes. ThoughtHazards uses its own
six-frame monochrome spiral sheet with red exposed edges.

- `terrain.png`: 64×696, 690 used slots plus six padding slots on an 8px grid.
  The original 408 slots retain their coordinates. Appended slots contain two
  sparse detail variants for every connected shape of the three materials.
  Use **Collisions** brushes for
  connected painting; Background/Foreground remain manual decoration layers.
- `connected_preview.png`: paint-rule preview with holes, branches and mixed
  material joins, rendered from the actual serialized LDtk rules.
- `dark_thought.png`, `light_thought.png`, `grey_thought.png`: 64×16 strips,
  four 16×16 frames each; binary alpha; black/white interiors, red silhouettes.
- `ladder.png`: 8×8 transparent repeat module.
- `cone_spikes*.png`, `glass_spikes*.png`: five-module strips, four facings,
  8px / 16px cells respectively; white/black interiors with red contours.
- `thought_tiles.png`: 32×48; four edge types × six animation frames.
- `preview.png`: nearest-neighbor 4× art review.
- `source/concept_atlas.png`: built-in ImageGen source exploration. This is
  concept art, not the runtime atlas; it predates the red-outline refinement.
- `source/prompt.txt`: original ImageGen prompt.

Rebuild: `python3 tools/build_act3_psychedelic.py` (LDtk must be closed).
Production geometry is authored at native resolution, following AGENTS.md's
asset pipeline; no generated bitmap is downsampled into a gameplay collider.
Reimport in a fresh Godot process after rebuilding, then reload the project in
LDtk. Do not leave either editor holding stale project data while rebuilding.

Verify: `Godot --headless --path . res://tests/act3_art_test.tscn`.
Connected paint regression: `python3 tools/test_act3_connected_terrain.py`.
