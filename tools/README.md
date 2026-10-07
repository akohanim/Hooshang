# Development tools

Run commands from the repository root. Tools are not loaded during gameplay.

## Routine commands

- `python3 tools/build_mobile_web.py`: produce the single itch.io archive,
  `builds/hooshang-web-upload.zip`. Build contents come from the Web preset and
  the explicit files in `web/`.
- `python3 tools/run_tests.py smoke save mobile_input mobile_ui`: run selected
  regression scenes sequentially. Omit names for the headless suite. Logs and
  a machine-readable summary go into `output/regressions/`.
- `Godot --headless --path . --script res://tools/audit_resources.gd`: inspect
  dependencies (including binary scenes) without rewriting or importing levels.
  This detects missing references, not every dynamically constructed asset path.

## Authoring families

- `import_*`, `pack_*`, `build_*`, `gen_*`: art pipelines and scene generators.
  Read the file's docstring before running; many replace their outputs.
- `ldtk_*`, `create_act*`, `act*_terrain*`, `connect_*`, `renumber_*`: level data
  authoring and migrations. Keep LDtk closed before editing its source data;
  follow `AGENTS.md` for the subsequent Godot import procedure.
- `gen_level.py`: the current movement gym generator.
- `archive/`: historical generation recipes. The old `gen_level1.py` and
  `gen_level2.py` produce retired office levels; do not use them to rebuild the
  current Acts. They remain as source history, not active build steps.

Art sources and one-time migration recipes are intentionally retained. A tool
having no caller is normal for a command-line entry point, not proof it is dead.

- `python3 tools/act1_spikes_to_thoughts.py [--apply]`: idempotent Act One migration;
  converts spike rectangles to the existing ThoughtHazards IntGrid, rebuilds its
  auto-tiles (including flipped edges), then removes the spike entities. Requires
  LDtk closed. Changed only 15 strips / 712 cells in seven rooms including TEST.
