# Hooshang

A 2D precision platformer in the spirit of Celeste. Godot 4.x, GDScript.
Currently: a tuned player controller + one greybox test level.

## Open & play

1. Open Godot 4.x → Import → select this folder's `project.godot`.
2. Press F5 (Run Project). The main scene is `levels/test_level.tscn`.

## Controls

| Action  | Keyboard              | Gamepad          |
|---------|-----------------------|------------------|
| Move    | Arrows / WASD         | D-pad / L-stick  |
| Jump    | Z / Space             | A (bottom)       |
| Dash    | X / Shift             | X (left) / RB    |
| Respawn | R                     | —                |
| Debug   | F3 (overlay toggle)   | —                |

## Layout

- `scenes/` — reusable scenes: player, hazard, checkpoint, debug overlay
- `scripts/` — all GDScript; `player.gd` is the movement state machine
- `levels/` — `test_level.tscn`, a linear gauntlet (8 labeled sections, one per mechanic)
- `assets/` — placeholder tileset
- `tests/` — headless smoke test: `godot --headless res://tests/smoke_test.tscn`
- `tools/gen_level.py` — regenerates the greybox level + tile png (overwrites
  `levels/test_level.tscn`, so don't run it after hand-editing the level)

## Tuning

Select the Player node (in `scenes/player.tscn` or inside the level) — every
physics constant is an exported, grouped, commented property in the Inspector.
Toggle the F3 overlay while playing to watch velocity/state/timers live.
