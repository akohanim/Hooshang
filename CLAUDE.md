# Hooshang — project context

A 2D precision platformer in the spirit of Celeste. Hooshang, an elderly office
worker, escapes a dark corporate office; Rumi (a golden guide figure) grants
abilities at story beats. Godot 4.6, GDScript, pixel art at 320x180 (8px tiles,
window 4x, viewport stretch + integer scaling, nearest filtering).

## Running things

- Godot binary (this machine): `/Users/ari/Downloads/Godot.app/Contents/MacOS/Godot`
- Main scene: `levels/level1_office.tscn` (Level 1: The Office)
- Movement test gym: `levels/test_level.tscn` (8 labeled sections, one per mechanic)
- Headless tests (run after any player/level change, exit code 0 = pass):
  - `Godot --headless --path . res://tests/smoke_test.tscn` — movement physics
  - `Godot --headless --path . res://tests/level1_test.tscn` — Level 1 beats
- If the editor is open, headless `--import` may stall — retry once, or close
  the editor. Never kill the user's `--editor` process.

## Layout

- `scripts/player.gd` — the whole controller: state machine (IDLE, RUN, JUMP,
  FALL, DASH, WALL_SLIDE, DEAD), all physics as exported/grouped/commented
  vars. Abilities gate on flags (`has_dash`); cutscenes use `input_locked`.
  All player visuals go through `_update_visual()` only.
- `scripts/level.gd` — `LevelBase`: camera limits, checkpoint group wiring,
  kill plane (`kill_y`), fast respawn (~0.15s), R = retry. Levels extend it
  (see `level1_office.gd` for cutscene/trigger patterns).
- `scripts/dialogue_box.gd` — reusable typewriter dialogue: `await box.say(speaker, text)`.
- `scenes/` — player, checkpoint, hazard (both @tool, size-exported), debug
  overlay (F3), dialogue box. `assets/hooshang_frames.tres` = SpriteFrames
  from the samurai pack (`assets/FREE_Samurai .../Sprites`); Rumi reuses it
  tinted gold.
- `tools/gen_level.py`, `tools/gen_level1.py` — regenerate the greybox levels
  (tilemap bytes + node layout). Re-running OVERWRITES hand-edits to the
  .tscn. Levels are dark (CanvasModulate ~0.09) + PointLight2D lamps using
  `assets/light_radial.png`.

## Conventions

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
