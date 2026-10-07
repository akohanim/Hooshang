# Shared world scripts

Reusable props and character controllers live beside their scenes in `scenes/`.
This directory holds the world integration and shared authoring hooks:

- `ldtk_world.gd`: room lifecycle, transitions, checkpoints and world geometry.
- `act1_beats.gd`, `act2_beats.gd`, `act2_expansion.gd`, `act1_chase_pacing.gd`:
  story/Act orchestration; save state remains with each owner.
- `ldtk_*_post_import.gd`: import-time conversion of LDtk entities and tiles.
  Editing these does not automatically reimport the source world.
- `ldtk_door.gd`, `ldtk_rumi_trigger.gd`: runtime behavior attached by importers.
- `jump_tutorial.gd`, `dash_tutorial.gd`: contextual mechanics lessons.
- `dialogue_script.gd`, `hooshang_dialogue_animator.gd`: shared dialogue parsing
  and the matrix portrait fallback (still instanced by DialogueBox).
- `ldtk_water_layer.gd`, `ldtk_thought_hazard_layer.gd`, `scaffolding_variation.gd`,
  `terrain_variation.gd`:
  dynamic terrain behavior and visual variation.
- Backdrop and material-lab scripts: runtime/editor support for their scenes.
- `level_base.gd`: the hand-built TestLevel gym, not the playable LDtk Acts.

Do not identify unused resources by text search alone. Packed `.scn` files are
binary, class names can resolve scripts without a literal path, and portrait/
audio manifests construct resource paths at runtime.

## Act One thought dust

`ldtk_dust_hazard_layer.gd` replaces only the office thought sheet's presentation
with `scenes/props/hazards/thought_dust/ThoughtDust.tscn`. The LDtk IntGrid and
imported cells remain the hazard authority; this renderer never changes collision.
Other Acts keep `ThoughtHazardLayer` and their own atlas art. Editing paint at
runtime rebuilds the occupancy texture. Each prefab owns its shader material.

Motion was inspected directly in the installed Celeste.exe (DustGraphic.Update,
Render, AddNode, the BlinkRoutine iterator, and DustEdges.BeforeRender): four
separately phased diagonal lobes draw a base at +rotation and overlay at -rotation,
advancing 0.5 rad/s; the center turns at 0.6 rad/s. Half of creatures get eyes,
30% of those follow the player, with vector approach at 12 units/s. Blinks wait
2–3.5s, close the left eye, close the right 20–70ms later, hold 250ms, then reopen.
Celeste's DustEdges composites an entire dust mask through a noise-colored edge
pass; the public Everest patch also documents its camera culling:
https://github.com/EverestAPI/Everest/blob/dev/Celeste.Mod.mm/Patches/DustGraphic.cs

Our adaptation uses original procedural tufts, cell-hashed phases, an occupancy
mask union and pixel-sized crimson edge noise. Speeds and eye timing follow the
measured behavior; geometry is scaled for 8px paint, not Celeste's larger spinner
entities. It does not copy Celeste textures or its compiled noise shader. A
one-cell border holds the cosmetic fringe; the lethal cell never follows it.
The render test guards animated output, solid connected interiors, and no inner
outline seams. Local inspection dumps live in ignored output/dust_research/.
