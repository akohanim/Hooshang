# Hooshang — project context

A 2D precision platformer in the spirit of Celeste. Hooshang, an elderly office
worker, escapes a dark corporate office; Rumi (a golden guide figure) grants
abilities at story beats. Godot 4.6, GDScript. **Art direction: modern detailed
pixel art** (Celeste / Hollow Knight/ Super Mario) — see the Art direction
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
  - `Godot --headless --path . res://tests/level2_test.tscn` — Level 2 jumps
  - `Godot --headless --path . res://tests/flow_test.tscn` — Level 1→2 transition
  - `Godot --headless --path . res://tests/world_bounds_test.tscn` — LDtk rooms
    are sealed at the top (a jump+dash can't leave through the ceiling)
  - `Godot --headless --path . res://tests/backtrack_test.tscn` — Exits work
    both ways all the way back, not just one room deep
  - `Godot --headless --path . res://tests/intro_test.tscn` — Act I's beats:
    dialogue order, dashless start, room 1 grants nothing, room 2 grants dash
  - `Godot --headless --path . res://tests/screen_test.tscn` — UI and world stay
    on separate render surfaces (restyling dialogue can't touch the game)
  - `Godot --headless --path . res://tests/pomegranate_test.tscn` — collectibles:
    pickup, and the total surviving level changes and death
- If the editor is open, headless `--import` may stall — retry once, or close
  the editor. Never kill the user's `--editor` process.

Lighting a room by hand (fixtures, the moon window, seam spill): `LIGHTING.md`.

## Art direction## Art direction

**Modern detailed pixel art** — the fidelity of Celeste / Hollow Knight / Super Mario. Soft gradient shading, dithering, and dynamic 2D lighting are all wanted;
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
  kill plane (`kill_y`), fast respawn (~0.15s), R = retry, and exit wiring — any
  Area2D in the `exit` group advances the game (see below). Levels `extends
  LevelBase` (see `scenes/levels/act1_office/level1_office.gd` for cutscene/
  trigger patterns).
- `systems/screen.gd` — `Screen` autoload: owns the two render surfaces. The
  world lives in a 320x180 `SubViewport` (pixel-art rasterisation, integer
  upscale); UI — dialogue, overlays, fades — sits on the window's own
  full-resolution surface in front of it. **Load levels with
  `Screen.load_scene()`, not `get_tree().change_scene_to_file()`**, or they land
  outside the game viewport; `Screen.current` replaces `current_scene`.
- `systems/collectibles.gd` — `Collectibles` autoload: the pomegranate ("coin")
  total, which carries across rooms, deaths and Act -> Act loads. Also remembers
  WHICH fruit were taken, so reloading a world can't re-spawn banked ones. Owns
  the small on-screen counter, top-left (built in code, CanvasLayer 92). On
  pickup the fruit flies from where it was taken into the counter, and the
  DISPLAYED number ticks over on arrival — `total` banks immediately, so nothing
  else ever waits on the animation (`Collectibles.shown()` is the display).
- `systems/deaths.gd` — `Deaths` autoload: the run's death count, top-right.
  `Player.die()` calls `Deaths.record()` — the player reports its own death
  rather than the counter hunting for a player, which would race every level's
  different build order.
- `systems/game.gd` — `Game` autoload: level progression + Celeste-style fade
  transitions. `Game.LEVELS` is the ordered scene list; reaching a level's exit
  sign fades out, loads the next, fades in. The loaded level is the running
  checkpoint (death respawns at its start; completed levels never replay).
  `Game.test_mode = true` exercises progression without swapping scenes.
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

