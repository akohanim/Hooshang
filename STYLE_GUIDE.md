# Hooshang — project conventions

How this project is organized. Follow these by default when adding anything;
they exist so objects are reusable, findable, and cheap to change in one place.

## 1. Composite objects are their own scene (the prefab pattern)

If a thing is **more than one node acting as one "thing,"** it gets its own
`.tscn` and is instanced wherever it's needed — never assembled inline inside a
level scene. Editing the object then means editing one scene, not hunting
through every level.

The worked example is the lamp:

```
scenes/props/lighting/LampFixture.tscn
└── LampFixture (Node2D)          [lamp_fixture.gd]
    ├── Cable  (ColorRect)  — cord to the ceiling
    ├── Bulb   (ColorRect)  — the lamp body
    └── Glow   (PointLight2D) — the actual light
```

Expose per-instance knobs as `@export` vars on the root script so instances can
differ without duplicating the scene (e.g. `light_color`, `light_energy`,
`show_body`, `cable_length`, `flickers`). Level 1's four lamps are all the same
prefab with different exports.

Same rule for any multi-part object as we build it: a desk+monitor+chair cubicle
cluster (`scenes/props/furniture/`), Rumi as a sprite+light (`scenes/characters/rumi/`),
a hazard set piece (`scenes/props/hazards/`), etc.

## 2. Folder structure

```
res://scenes/
    props/       lighting/  furniture/  hazards/   (+ Checkpoint.tscn)
    characters/  hooshang/  rumi/
    levels/      act1_office/  ...          (TestLevel.tscn is the movement gym)
    ui/          DialogueBox.tscn  DebugOverlay.tscn
res://scripts/   only scripts NOT co-located with a scene (e.g. level_base.gd)
res://systems/   autoload singletons (see README there)
res://resources/ .tres data files (see README there)
res://assets/    art, audio, tilesets, SpriteFrames, generated textures
res://tools/     Python level generators (see §7)
res://tests/     headless test scenes
```

Scripts live **next to their scene** by default (`Hooshang.tscn` + `player.gd`
in `scenes/characters/hooshang/`). `res://scripts/` is only for scripts with no
single owning scene — currently just `level_base.gd`, the base class every
level extends.

## 3. Naming

- **Scene files and node names:** `PascalCase` — `LampFixture.tscn`, `DialogueBox`, `Hooshang`.
- **Scripts, variables, functions:** `snake_case` — `lamp_fixture.gd`, `light_energy`, `_on_body_entered`.
- **`class_name`:** `PascalCase` (`LampFixture`, `LevelBase`). It's global, so a
  script can be moved/renamed freely as long as `class_name` stays the same.

## 4. Groups for "find all of a type"

When a system needs every object of a kind, use node groups, not a hardcoded
list. Each prefab joins its group in `_ready()`:

- `player` — the character (one)
- `lights` — every `LampFixture` (`get_nodes_in_group("lights")` for the future
  manager light-sweep)
- `checkpoint` — checkpoint areas
- `hazard` — hazards

## 5. Signals and autoloads over direct references

- Prefer **signals** for one node telling another something happened
  (`player.died`, `checkpoint.activated`, Area `body_entered`) over reaching
  across the tree.
- Don't reach into another node's children. If a level needs the player to do
  something to itself, add a method: `player.flash()`, `player.set_camera_limits()`
  — not `player.visual.self_modulate` / `player.get_node("Camera2D")`.
- **Autoloads** (`res://systems/`, registered in `project.godot`) hold anything
  that outlives one level. The dialogue system is an autoload: any cutscene
  calls `Dialogue.say("Rumi", "line", tint)` — it is not re-instanced per level.
- Per-level plumbing (camera bounds, checkpoints, kill plane, respawn) lives on
  `LevelBase` (`scripts/level_base.gd`); levels `extends LevelBase`. That's
  reuse via inheritance — no autoload needed until there's cross-level state.

## 6. Data over hardcoding, where it's cheap

Content that is just data and repeats across levels should be a `.tres`
Resource in `res://resources/`, not baked into a script. Don't over-engineer a
one-off (Level 1's three dialogue lines are still `const`s); promote to `.tres`
when a conversation grows or recurs.

## 7. Greybox levels are generated

`scenes/levels/**/…tscn` for the greybox levels are written by the Python
generators in `tools/` (`gen_level1.py`, `gen_level.py`) — tilemap bytes + node
layout. **Re-running a generator overwrites hand-edits to that `.tscn`**, so
change the generator, not the scene, for generated levels. Prefab instances,
exports, and paths are emitted from the generator too.

## 8. Parallax backdrops (visual depth layers)

Every level's background is a **backdrop prefab** (`scenes/props/backdrop/`,
e.g. `OfficeBackdrop.tscn`), instanced as the level's first child. It gives the
Celeste-style depth without touching gameplay. Standard structure:

- **The backdrop root is a plain `Node2D`** (e.g. `OfficeBackdrop.tscn`),
  instanced as the level's *first* child — normal 2D draw order then puts it
  behind every later sibling (terrain, decor, player) with no `z_index` needed.
  **Do not wrap it in a `CanvasLayer`.** `Parallax2D` already tracks the active
  camera on its own (`follow_viewport`, default true) with no `CanvasLayer`
  involved. A `CanvasLayer` was tried here for two reasons — render-behind
  (unnecessary, see above) and exempting the backdrop from the level's dark
  `CanvasModulate` — but `CanvasLayer` content does not preview correctly
  nested inside a scene in the Godot **editor**: it renders at a fixed
  screen-space position instead of panning with the rest of the level, so it
  visibly drifts and overlaps the play area as soon as you scroll the 2D view.
  It looked fine at runtime and broke authoring. If a backdrop ever needs to
  ignore the room's `CanvasModulate`, don't reach for `CanvasLayer` or
  overbright inverse-modulate math (tried, produced blown-out color — Godot's
  pipeline isn't a flat linear multiply) — in practice the room's dark tint
  reads fine on backdrop art too (moody, consistent with the foreground), so
  the simplest option — no compensation at all — is usually correct.
- **One `Parallax2D` per depth, back to front**, via `scroll_scale` (lower =
  deeper = moves less):
  - `Background` `0.2` — brick wall (barely moves).
  - `Midground` `0.5` — office decoration: cubicles, the moon-window.
  - `Atmosphere` `0.7` — drifting-paper `GPUParticles2D` (looping, no collision).
- **Foreground = the level's own nodes** (terrain, player, hazards, props) on
  canvas layer 0, moving 1:1. The backdrop never adds collision or gameplay.
- **Coverage rule:** a layer that must fill the screen uses a **`Sprite2D` with
  a `Texture2D`** — never a `TileMapLayer` — because `Parallax2D.repeat_size`
  only tiles textures. Make the texture WIDER than the viewport (the brick strip
  is 896px) and set `repeat_size` to its width. (This was the fix for persistent
  coverage gaps.)
- **Composite background objects are their own prefab** (e.g. `MoonWindow.tscn`
  = navy backing + moon + frame) instanced in the midground — same prefab rule
  as §1.

Dev aid: `tests/screenshot.tscn` renders a level windowed and saves viewport
PNGs at chosen camera x positions — use it to check backdrops without the editor.

## 9. After any change

Run the headless tests (exit 0 = pass) and confirm a clean boot:

```
Godot --headless --path . res://tests/smoke_test.tscn    # movement physics
Godot --headless --path . res://tests/level1_test.tscn   # Level 1 beats
```
