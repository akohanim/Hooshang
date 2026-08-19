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

### Player state invariants

`_state_ground()` (IDLE / RUN) deliberately applies **no gravity** — standing on
the floor there is nothing to fall towards. That makes one rule load-bearing:

- **A ground state must never survive being airborne.** Airborne in IDLE/RUN
  means nothing pulls the player down, so he keeps his vertical speed forever.
  With upward speed that is a permanent float: constant rise, ceiling, velocity
  zeroed by the collision, and then he hangs there for good. `_post_move()`
  enforces the invariant at the end of every frame; the coyote-time branch above
  it cannot, because it requires `velocity.y >= 0.0`, which is exactly false in
  the case that strands him.
- When adding a state, ask which of them apply gravity. If a new state doesn't,
  it needs the same guard.

Guarded by `tests/smoke_test.tscn`, which forces the stranded state directly
rather than trying to reproduce the input timing that produced it.

## 9. LDtk-authored levels

Levels built in the LDtk editor (rather than the Python generators in §7) live
under a top-level **`ldtk/`** folder, separate from `scenes/levels/` — LDtk
projects aren't tied to one act/scene the way a generated `.tscn` is, and a
single `.ldtk` file commonly holds many levels as entries within it.

- **`ldtk/*.ldtk`** — the source project file(s), hand-edited in the LDtk app.
  This is the thing you open and save in LDtk; treat it as source, like a
  `tools/gen_*.py` script.
- **`ldtk/art/`** — tileset/reference PNGs the `.ldtk` project points at. Kept
  separate from `assets/` since these are LDtk-specific inputs, not runtime
  textures Godot loads directly (Godot never references `ldtk/art/*.png`
  itself — only the `.ldtk` file and, indirectly, the importer's generated
  `TileSet` resources do).
- **`ldtk/levels/*.scn`** — auto-generated by the `godot-ldtk-importer`
  addon (`addons/ldtk-importer/`) every time the `.ldtk` file is saved/
  reimported. **Never hand-edit these** — same rule as §7's generated
  `.tscn` files, for the same reason (next reimport overwrites them).
- The addon writes its output as siblings of wherever the `.ldtk` file sits
  (a `levels/` folder appears next to it automatically) — that's why the
  source file and its output share the `ldtk/` root rather than nesting
  under a specific act's folder.
- Entity wiring (spawning real `Door`/`Checkpoint`/`Hazard` prefabs where LDtk
  entities were placed) is a `scripts/ldtk_entities_post_import.gd` hook,
  wired via the `.ldtk.import` file's `entities_post_import` param. LDtk field
  values come through `null` when a field exists but hasn't been typed into
  yet (not merely absent) — `Dictionary.get(key, default)` only falls back on
  a *missing* key, so every field read there goes through a small
  `_field_str()` helper rather than a raw `.get()`.
- **If an entity needs a signal connection (a trigger zone, anything with
  `body_entered`), don't connect it inside the post-import hook — give the
  node its own tiny script and connect in that script's `_ready()` instead**
  (see `scripts/ldtk_rumi_trigger.gd`, built by the `RumiTrigger` case
  above). A connection made once at import time — a lambda closure,
  especially — does not survive being packed into the saved `.scn` and
  reloaded; `PackedScene` can only serialize connections to a named method
  on a script. The symptom is silent: no error anywhere, the trigger just
  never fires, because the connection quietly never existed in the loaded
  scene. `_ready()` sidesteps this entirely since it re-runs fresh every
  time the node actually enters a live tree — exactly how `checkpoint.gd`/
  `hazard.gd` already do it.
- **Do NOT spawn the player via a `level_post_import` hook.** The importer's
  own save step (`recursive_set_owner`, in `addons/ldtk-importer/ldtk-importer.gd`)
  walks into whatever you add and reassigns ownership of its children to the
  level being packed — for a plain node that's fine, but for an *instanced
  sub-scene* (like `Hooshang.tscn`, which has its own children) it causes
  those children to get serialized twice into the saved `.scn` (confirmed by
  instrumenting the hook: it's called exactly once and produces a clean
  4-child player, but the file Godot loads back has 8). Instead, spawn the
  player at **runtime**: a tiny wrapper scene (e.g. `ldtk/Level_1_Office_Test.tscn`)
  instances the generated level as a plain child and instances the player at
  its `PlayerStart` marker in `_ready()`. The generated `.scn` stays pure
  level-geometry-plus-markers, same as `entities_post_import` already
  produces correctly for simpler (non-nested) prefabs.
- **The auto-generated `TileSet` has no collision by default**, even with
  `integer_grid_tilesets` on and `collision_enabled` set on the
  `TileMapLayer` — that flag only means the layer *participates* in physics;
  each tile still needs its own collision shape, and the importer only
  builds the visual atlas.
  `scripts/ldtk_tileset_post_import.gd` (wired via `tileset_post_import`)
  fixes this **every import**, not just once: it adds a physics layer and a
  full 16x16 collision square to every tile that doesn't already have one.
  This project's greybox tiles are all simple full-square solids (no
  slopes — same convention as `tools/gen_level*.py`), so "every tile is
  fully solid" is always correct here.
  A one-off manual fix (scripting the `TileSet` API once, by hand) was tried
  first and DID survive a reimport — but only until the tileset needed a
  full rebuild (e.g. adding a new tile in LDtk), which silently wiped it and
  reintroduced fall-through collision with no error. The self-healing hook
  has no such gap: it re-applies on every single import regardless of what
  changed, so this class of bug can't recur.
- **A tileset-less IntGrid layer always renders as coloured swatches**, and
  the `integer_grid_tilesets` import option does NOT suppress it — the addon
  branches on `not has_tileset or integer_grid_tilesets`
  (`addons/ldtk-importer/src/layer.gd`), so a purely *semantic* layer (this
  project's `Collision`: Solid / OneWay / Hazard / UnderworldTrigger, no
  tileset) unconditionally gets a `<name>-values` TileMapLayer of flat colour
  blocks — which the collision hook above then makes solid too. Symptom: a
  grey `#6B7280` rectangle (Solid's editor colour) floating in the level,
  blocking the player. `scripts/ldtk_level_post_import.gd` neutralises every
  `*-values` layer (`visible = false`, `collision_enabled = false`); real
  geometry is unaffected because it lives on IntGrid layers that DO have a
  tileset (`Collisions`, brick auto-tiles), which the addon emits as an
  ordinary tile layer. Consequence: painting a tileset-less semantic layer
  now does nothing in-game — wiring up OneWay/Hazard/UnderworldTrigger means
  reading the IntGrid values and building real nodes, not leaning on swatches.
### Connecting rooms (Celeste-style, no loading)

An LDtk project imports as ONE scene whose children are its levels, already
positioned at their world coordinates. Those children are the **rooms**, and
`scripts/ldtk_world.gd` (`LdtkWorld`) drives them — see `ldtk/Act1World.tscn`.

- **One `.ldtk` per Act.** Rooms inside an Act transition seamlessly; Act ->
  Act is a real scene change through `Game` (a load + fade suits a scenery and
  story break, and keeps each LDtk file quick to open).
- **Every room in the Act stays loaded.** A transition is therefore just the
  camera moving and the active room's bounds changing — no `change_scene_to_file`,
  no fade. `Game.advance()` cannot be made seamless (it fades to black and
  loads), so it is deliberately NOT used between rooms.
- **`LdtkWorld` owns what `LevelBase` owns for hand-built levels**, but keyed to
  the *current room* rather than the scene: camera limits, kill plane, respawn
  point, checkpoint tracking. Hand-built levels keep using `LevelBase`; this is
  additive.
- **Room order is by world position** (left to right, then top to bottom). An
  `Exit` entity's `NextRoom` field overrides that for non-linear jumps.
- **The camera slide detaches the camera** (`set_as_top_level`) and tweens it
  from the old room's view centre to the new one. Do NOT try to read
  `Camera2D.get_screen_center_position()` back after moving the camera's parent
  in the same frame — it returns the stale value, which silently produces a
  zero-length slide. `_view_centre_for()` computes the clamped centre up front
  instead.
- **Anything that finds nodes by group must be scoped to a room.** With the
  whole Act loaded, an unscoped `get_nodes_in_group()` reaches rooms the player
  has never visited — this already bit the Rumi trigger, which was swinging
  open every `story_door` in the Act. Compare parents (same room's `Entities`
  layer) before acting.
### UI and world render on separate surfaces

`systems/screen.gd` (`Screen` autoload) owns two surfaces:

```
root viewport (window resolution)      <- UI: DialogueBox, overlays, fades
  └─ GameView (SubViewportContainer)
       └─ GameViewport (320x180)       <- the world: levels, player, tiles
```

The world is rasterised at 320x180 and integer-upscaled, exactly as pixel art
wants. UI is drawn at the window's real resolution, so type can be sharp.
Neither can affect the other's sampling — which is the whole point.

This exists because they were once the same surface. Making the window render at
native resolution so the dialogue font could be sharp *also* stopped the world
being rasterised at 320x180, and Hooshang's sprites — 88px source art shown at
0.39 scale — silently gained about 2.6x detail. The tiles were unaffected
(authentic 16px art at 16px), which is exactly why a spot-check missed it: this
only bites art whose source resolution exceeds its on-screen size.

- **Load levels with `Screen.load_scene()`**, never
  `get_tree().change_scene_to_file()` — the world has to land inside the
  sub-viewport. `Screen.current` / `Screen.current_path()` replace
  `get_tree().current_scene`.
- **UI that needs real type is authored at 1280x720 in a CanvasLayer with
  `scale = 0.25`** (see `scenes/ui/DialogueBox.tscn`). 0.25 is a constant: the
  window's canvas_items stretch maps 180 design px to the window height, and the
  UI wants 720 mapped to the same height.
- **A SubViewport receives no key events of its own.** `Screen` forwards them
  from `_unhandled_input`, which also means UI gets first refusal: the dialogue
  box calls `set_input_as_handled()` on the key that advances a line, so that
  press can't also make Hooshang jump.
- **Positional audio needs `audio_listener_enable_2d` on the sub-viewport**, or
  every `AudioStreamPlayer2D` in the world plays silently.

Guarded by `tests/screen_test.tscn`, which restyles the dialogue box mid-test and
asserts the game viewport and the player's sprite are untouched.

- **One music player per Act, on the world node** — `Act1World.tscn`'s `Music`
  (`AudioStreamPlayer`, `autoplay`, `volume_db = -10`). Not one per room: every
  room of the Act lives in that one scene, so a single player runs the track
  unbroken across room transitions and respawns, where per-room players would
  restart it every time you crossed a seam. Looping belongs on the **import**
  (`loop=true` in the `.mp3.import`), not the node — Godot's mp3 importer
  defaults it to false and the node has no loop of its own, so an autoplaying
  track just stops dead after one pass. (Note the `.import` change only takes
  effect after a `--import`.) Don't put explanations in a `.tscn`: the editor
  rewrites the whole file on save and strips comments.
- **Re-arm the return door every time you enter a room, including backwards.**
  Walking back through an Exit consumes the door that brought you there, so if
  arriving backwards doesn't hang a new one, backtracking works exactly one room
  deep. Worse than merely stopping: you land beside that room's own forward
  Exit, which is then the only live trigger in reach, so trying to go back again
  throws you forward instead. Arriving forward arms `came_from`; arriving
  backwards arms `_room_before()` of the room you land in.
- **Rooms are sealed at the top by `LdtkWorld`, not by tiles you paint.** An
  unpainted cell in a room's ceiling row is a hole the player can leave through:
  a jump + up-dash out of Level_3's ceiling gap measured 44px above the room,
  and since the camera stays clamped to the room, he just vanished off the top
  of the screen. `seal_room_ceilings` caps every room with an invisible lid
  sitting *outside* the room rect (so it costs no playable space and, because
  rooms sit side by side, can't intrude on a neighbour). Don't rely on having
  painted a complete ceiling — but do note that the lid means a room's top edge
  is now a hard surface you will bonk your head on. The floor is deliberately
  left open; falling out the bottom is the kill plane's job.
- **Leave no gap between rooms in the LDtk world** if you want the cleanest
  pan: the camera travels through whatever is between them, so rooms spaced
  wider than their own width show dead space mid-slide.

- **Don't hand-edit a `.ldtk` file to fix level data.** LDtk keeps the whole
  project in memory and rewrites the entire file on save, so any on-disk edit
  is silently reverted the next time the author saves from an open LDtk
  session — confirmed here when two stray cells deleted from disk came back at
  the exact same coordinates. Fix level-data problems in the LDtk app, or (for
  anything systemic) on the Godot side in an import hook, where the fix
  re-applies every import and can't be clobbered.

## 10. After any change

Run the headless tests (exit 0 = pass) and confirm a clean boot:

```
Godot --headless --path . res://tests/smoke_test.tscn    # movement physics
Godot --headless --path . res://tests/level1_test.tscn   # Level 1 beats
```
