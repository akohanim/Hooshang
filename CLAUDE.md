# Hooshang — project context

A 2D precision platformer in the spirit of Celeste. Hooshang, an elderly office
worker, escapes a dark corporate office; Rumi (a golden guide figure) grants
abilities at story beats. Godot 4.6, GDScript. **Art direction: modern detailed
pixel art** (Celeste / Hollow Knight / Dead Cells) — see the Art direction
section below. The current greybox still runs at 320×180 with 8px placeholder
tiles (viewport stretch, integer scale, nearest filtering); real art migrates to
the target grid.

## Running things

- Godot binary (this machine): `/Users/ari/Downloads/Godot.app/Contents/MacOS/Godot`
- Main scene: `scenes/levels/act1_office/Level1Office.tscn` (Level 1: The Office)
- Movement test gym: `scenes/levels/TestLevel.tscn` (8 labeled sections, one per mechanic)
- Headless tests (run after any player/level change, exit code 0 = pass):
  - `Godot --headless --path . res://tests/smoke_test.tscn` — movement physics
  - `Godot --headless --path . res://tests/level1_test.tscn` — Level 1 beats
- If the editor is open, headless `--import` may stall — retry once, or close
  the editor. Never kill the user's `--editor` process.

## Art direction

**Modern detailed pixel art** — the fidelity of Celeste / Hollow Knight / Dead
Cells. Soft gradient shading, dithering, and dynamic 2D lighting are all wanted;
**explicitly NOT 8-bit/NES flat-palette retro.** This replaces the earlier
"8-bit" direction. Design doc §7 (Visual & Audio Style) is the source of truth.

Target specs (real art migrates the greybox toward these):
- Character canvas ~32×48 px; base tile grid 16×16 px.
- In-engine scale 2×–3× with pixel snapping (nearest filtering, transforms
  snapped to whole pixels) so detail stays crisp.
- Extended palette **per Act (~32–64 colors)**; soft gradients/dithering — not
  flat retro palettes.
- Walk/run = 8–12 frame cycles.

Per-Act mood: Act I office = desaturated / dim / flickering fluorescent; Act II
Iran = warm / saturated / sun-drenched; Act III ocean = luminous, brightens with
depth.

Tooling:
- **Pixellab MCP prompts:** always request *"detailed pixel art, soft shading,
  dynamic lighting, NOT 8-bit/NES"* and state the canvas size (e.g. 32×48
  character, 16×16 tile) — default prompts skew retro.
- **Godot Light2D:** prototype new lighting in an isolated test scene first;
  it's finicky on the first pass (blend modes, masks, normal maps, energy/range).

## Project conventions

**Read `STYLE_GUIDE.md` and follow it by default.** In short: composite objects
(anything that's more than one node acting as one thing) are their own `.tscn`
prefab, instanced everywhere and tweaked via `@export`s — never assembled inline
in a level. Folders mirror categories under `scenes/` (`props/{lighting,
furniture,hazards}`, `characters/`, `levels/`, `ui/`); scripts sit next to their
scene. Scenes/nodes are `PascalCase`, scripts/vars `snake_case`. Use groups to
find things (`lights`, `player`, `checkpoint`, `hazard`), signals + methods over
reaching across the tree, autoloads (`systems/`) for cross-level services, and
`.tres` in `resources/` for data that repeats.

## Layout

- `scenes/characters/hooshang/` — `Hooshang.tscn` + `player.gd`: the whole
  controller, a state machine (IDLE, RUN, JUMP, FALL, DASH, WALL_SLIDE, DEAD),
  all physics as exported/grouped/commented vars. Abilities gate on flags
  (`has_dash`); cutscenes use `input_locked`; all visuals go through
  `_update_visual()`. Cosmetic asks come in via methods (`flash()`,
  `set_camera_limits()`), not reach-ins.
- `scripts/level_base.gd` — `LevelBase`: camera limits, checkpoint group wiring,
  kill plane (`kill_y`), fast respawn (~0.15s), R = retry. Levels `extends
  LevelBase` (see `scenes/levels/act1_office/level1_office.gd` for cutscene/
  trigger patterns).
- `scenes/ui/` — `DialogueBox.tscn` (Celeste-style banner + portrait; registered
  as the `Dialogue` autoload — call `Dialogue.say(speaker, text, tint)`) and
  `DebugOverlay.tscn` (F3).
- `scenes/props/` — `Checkpoint.tscn`, `hazards/Hazard.tscn` (both @tool,
  size-exported), `lighting/LampFixture.tscn` (reusable lamp; joins `lights`).
- `assets/hooshang_frames.tres` = SpriteFrames from the samurai pack
  (`assets/FREE_Samurai .../Sprites`); Rumi reuses it tinted gold.
- `tools/gen_level.py`, `tools/gen_level1.py` — regenerate the greybox levels
  (tilemap bytes + node layout, incl. prefab instances). Re-running OVERWRITES
  hand-edits to the generated `.tscn`. Levels are dark (CanvasModulate ~0.09) +
  `LampFixture` instances.

## Physics/level conventions

- Physics layer 1 = world, 2 = player. Areas (hazard/checkpoint/triggers)
  collide with mask 2 only.
- Every tunable is an `@export` with a one-line comment saying what tweaking
  it changes. Feel timers count down as plain floats in `_tick_timers()`.
- Player hitbox 8x12; interiors: 3 tiles = claustrophobic, walkable min is a
  2-tile (16px) slot. Jump reaches ~3.5 tiles, dash ~5, jump+dash gap ~10.
- Checkpoints are silent Area2Ds; death is instant respawn, no penalty.

## Roadmap (do not build until asked)

- Underworld dimension: palette shift + stay-too-long death timer — hooks
  noted in `level1_office.gd` / `LevelBase` (CanvasModulate is the seam).
- Still Sight black-&-white power mode — CanvasModulate/shader + player state.
- Manager's light-sweep hazard in the corridor (beat 4).
- Musical tile puzzles — planned as a TileMapLayer + conductor node per level.
- Story beats 2+: Rumi returns; dialogue system is ready for sequences.
