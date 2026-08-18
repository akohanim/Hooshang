# Hooshang

A 2D precision platformer in the spirit of Celeste, built in **Godot 4.6** with
GDScript. Hooshang, an elderly office worker, escapes a dark corporate office;
Rumi, a golden guide figure, grants him abilities at story beats.

---

## Technical Overview

The game renders at a **320×180 design resolution** and is scaled to the window
by whole numbers, so pixel art stays on its grid. The window itself runs at
1280×720 by default and starts maximised.

| Setting | Value | Why |
| --- | --- | --- |
| `display/window/size/viewport_*` | `320 × 180` | The design resolution everything is authored against |
| `window/stretch/mode` | `canvas_items` | The framebuffer is the window, not a 320×180 buffer — this is what lets UI type rasterise sharply |
| `window/stretch/scale_mode` | `integer` | Whole-number scaling only; no shimmering half-pixels |
| `textures/canvas_textures/default_texture_filter` | `0` (Nearest) | Pixel art must not be smoothed |
| `2d/snap/snap_2d_transforms_to_pixel` | `true` | Sprites land on whole pixels |
| `renderer/rendering_method` | `gl_compatibility` | Widest hardware support; the game needs no advanced rendering |

### Two render surfaces

The single most important architectural decision: **the world and the UI render
on separate surfaces.** `systems/screen.gd` (the `Screen` autoload) owns both.

```
root viewport  (window resolution)        ← UI: dialogue, overlays, fades
  └─ GameView  (SubViewportContainer)
       └─ GameViewport (320 × 180)        ← the world: levels, player, tiles
```

The world is rasterised at 320×180 and integer-upscaled. UI is drawn at the
window's real resolution, so a font can use as many scanlines as it needs.
Neither surface can affect the other's sampling.

This exists because they were once the same surface, and the coupling caused a
real regression: raising the whole window to native resolution so dialogue type
could be sharp *also* stopped the world being rasterised at 320×180, and the
player's sprites — 88 px source art displayed at `0.39` scale — silently gained
about 2.6× detail. Tiles were unaffected (authentic 16 px art shown at 16 px),
which is exactly why a spot check missed it. **Only art whose source resolution
exceeds its on-screen size is sensitive to this.**

Consequences worth knowing before you touch anything:

- **Load levels with `Screen.load_scene(path)`, never
  `get_tree().change_scene_to_file()`** — the world has to land *inside* the
  sub-viewport. `Screen.current` and `Screen.current_path()` replace
  `get_tree().current_scene`.
- **Spawn world objects into the world**, not `get_tree().current_scene`. That
  is the UI surface now, and is `null` outright once the debug picker frees
  itself on launch.
- **A `SubViewport` receives no key events of its own.** `Screen` forwards them
  from `_unhandled_input`, which means UI gets first refusal: the dialogue box
  calls `set_input_as_handled()` on the key that advances a line, so that press
  cannot also make Hooshang jump.
- **Positional audio needs `audio_listener_enable_2d`** on the sub-viewport, or
  every `AudioStreamPlayer2D` in the world plays silently.

### Autoloads

| Name | Script | Responsibility |
| --- | --- | --- |
| `Screen` | `systems/screen.gd` | Owns the two render surfaces; loads worlds into the game viewport |
| `Dialogue` | `scenes/ui/DialogueBox.tscn` | Celeste-style dialogue box — `Dialogue.say(speaker, text, tint, portrait)` |
| `Game` | `systems/game.gd` | Level progression through `Game.LEVELS` + fade transitions |
| `Collectibles` | `systems/collectibles.gd` | Lemon total + the top-left counter, and the fruit's flight into it; survives every level change |
| `Deaths` | `systems/deaths.gd` | The run's death count + the top-right counter |

`Screen` is registered first because `Game` loads levels through it.

### Two level pipelines

The project contains two coexisting ways to build a level. Both are live.

**1. LDtk-authored (current).** Levels are drawn in the LDtk editor and imported
by the `ldtk-importer` addon. One `.ldtk` project holds many rooms; the whole
Act imports as a single scene whose children are the rooms, already positioned
at their world coordinates.

`scripts/ldtk_world.gd` (`LdtkWorld`) drives them Celeste-style: **every room in
the Act stays loaded at once**, so moving between rooms costs no scene load and
no fade — a transition is the camera sliding and the active room's bounds
changing. It owns camera limits, the kill plane, respawn, checkpoints, room
ceilings, and two-way exits.

Three import hooks re-apply project rules on every import, so they can never be
clobbered by a re-export from LDtk:

- `ldtk_tileset_post_import.gd` — per-tile collision on the world layer
- `ldtk_entities_post_import.gd` — turns LDtk entities into real nodes
  (PlayerStart, Door, Checkpoint, Hazard, RumiTrigger, Exit, MusicNote1–5,
  Lemon)
- `ldtk_level_post_import.gd` — assigns draw bands and neutralises the
  importer's IntGrid debug swatch layers

**2. Hand-built, Python-generated (legacy).** `scenes/levels/act1_office/*.tscn`
are emitted by the generators in `tools/`. **Re-running a generator overwrites
hand-edits to its `.tscn`** — change the generator, not the scene. These levels
extend `scripts/level_base.gd` and chain through `Game.LEVELS`.

---

## File Structure

```
res://
├── project.godot            Autoloads, input map, display + physics layer names
│
├── systems/                 Autoload singletons (cross-level services)
│   ├── screen.gd            Screen: the two render surfaces; world loading
│   ├── game.gd              Game: level progression + fade transitions
│   ├── collectibles.gd      Collectibles: lemon total + counter HUD
│   └── deaths.gd            Deaths: death count + counter HUD
│
├── scenes/
│   ├── characters/hooshang/
│   │   ├── Hooshang.tscn    CharacterBody2D + sprite + camera + Juice
│   │   ├── player.gd        Movement state machine (see below)
│   │   ├── Juice.tscn
│   │   └── juice.gd         Squash/stretch, dash trail, camera shake, hitstop
│   ├── props/
│   │   ├── Checkpoint.tscn / checkpoint.gd
│   │   ├── Door.tscn / door.gd            (+ DoorGlass, DoorMetal variants)
│   │   ├── ExitSign.tscn
│   │   ├── NoteTile.tscn / note_tile.gd   Musical puzzle tile
│   │   ├── Lemon.tscn / lemon.gd   Collectible ("coin")
│   │   ├── backdrop/        OfficeBackdrop.tscn, MoonWindow.tscn
│   │   ├── hazards/         Hazard.tscn / hazard.gd
│   │   └── lighting/        LampFixture.tscn / lamp_fixture.gd
│   ├── ui/
│   │   ├── DialogueBox.tscn / dialogue_box.gd
│   │   └── DebugOverlay.tscn / debug_overlay.gd     (F3)
│   ├── levels/
│   │   ├── TestLevel.tscn                 Movement gym, 8 mechanic sections
│   │   └── act1_office/                   Generated levels + level1_office.gd
│   └── debug_level_picker.tscn / .gd      Main scene during development
│
├── scripts/                 Scripts with no single owning scene
│   ├── ldtk_world.gd        LdtkWorld: the Celeste-style room manager
│   ├── ldtk_*_post_import.gd    The three import hooks
│   ├── ldtk_door.gd, ldtk_rumi_trigger.gd
│   ├── act1_beats.gd        Act I's scripted story beats
│   ├── note_sequence.gd     Musical-tile puzzle ordering + glow reward
│   └── level_base.gd        LevelBase, for hand-built levels
│
├── ldtk/
│   ├── hooshang_claude.ldtk        The LDtk project (edit in the LDtk app)
│   ├── Act1World.tscn              Playable Act I: world + lights + music + beats
│   ├── levels/                     Imported room scenes (generated)
│   ├── tilesets/                   Imported tilesets (generated)
│   └── art/                        Source art referenced by the .ldtk file
│
├── assets/                  Art, audio, fonts, SpriteFrames, portraits
├── tests/                   Headless test scenes (see Getting Started)
└── tools/                   Python generators for levels, tiles, audio
```

---

## Architecture & Layering

### Visual Layers

Depth is decided in three places, in this order of authority: **which render
surface**, then **`CanvasLayer`**, then **`z_index`**.

#### 1. Render surface

The coarsest separation. Anything inside `Screen.viewport` is the world;
anything outside it is UI drawn over the top. See *Two render surfaces* above.

#### 2. CanvasLayer (UI depth)

All UI is inside a `CanvasLayer`, which decouples it from the game camera.
Higher numbers draw in front.

| Layer | Node | Purpose |
| --- | --- | --- |
| `128` | `Game`'s fade + banner (built in code) | Level transitions — above everything, deliberately |
| `100` | `scenes/ui/DebugOverlay.tscn` | F3 debug readout |
| `95` | `scenes/ui/DialogueBox.tscn` | Dialogue banner + portrait |
| `90` | `Act1Beats`' fade (built in code) | The opening fade-up from black — under dialogue, over the world |
| `0` | `Screen`'s `GameView` | The world's sub-viewport |

The dialogue box is authored in a **1280×720 space inside a `CanvasLayer` with
`scale = 0.25`**. That constant is not window-dependent: the canvas stretch maps
180 design px to the window height, and the UI wants 720 mapped to the same
height, so the ratio is always `180/720`. Glyphs therefore rasterise at 4× the
size they would in game space.

#### 3. z_index (world depth bands)

Inside the world, three bands are used:

| Band | Used by | Notes |
| --- | --- | --- |
| `-1` | LDtk `Background` tile layer; `LdtkWorld`'s per-room backdrop panel | Scenery the player walks **in front of** |
| `0` | Tiles, entities, the player, dash afterimages | The playable area (Godot's default) |
| `1` | LDtk `Foreground` tile layer | Scenery the player walks **behind** |

Bands are assigned **by LDtk layer name** in `ldtk_level_post_import.gd`
(`Z_BANDS`), so ordering is explicit rather than an accident of sibling order.

Two details worth understanding:

- The per-room backdrop panel and the `Background` tile layer share `z_index -1`;
  the panel is moved to child index 0 so sibling order keeps it behind.
- **Dash afterimages sit at `z_index 0`, not `-1`.** They are a player effect,
  and `-1` is the background band — putting them there would draw the trail
  behind floors and walls. Within a band, draw order is sibling order, so
  `juice.gd` inserts each afterimage at the player's own index: in front of the
  tiles, behind the player.

#### Parallax backdrops

`scenes/props/backdrop/OfficeBackdrop.tscn` uses **`Parallax2D`** (Godot 4.3+),
not the legacy `ParallaxBackground` / `ParallaxLayer` pair. Three depths:

| Node | `scroll_scale` | Contents |
| --- | --- | --- |
| `Background` | `0.2` | Brick wall — barely moves |
| `Midground` | `0.5` | `MoonWindow.tscn` |
| `Atmosphere` | `0.7` | Drifting-paper `GPUParticles2D` |

The backdrop root is a plain `Node2D`, instanced as the level's **first** child
so normal draw order puts it behind everything. It is deliberately **not**
wrapped in a `CanvasLayer`: `Parallax2D` tracks the active camera on its own, and
a `CanvasLayer` renders in screen space in the editor, which breaks authoring.

### Physics & Collision Masks

Four 2D physics layers, explicitly named in `project.godot`:

```
2d_physics/layer_1 = "world"
2d_physics/layer_2 = "player"
2d_physics/layer_3 = "hazards"
2d_physics/layer_4 = "triggers"
```

Godot's inspector numbering is 1-based while the stored value is a bitmask:
layer 1 = `1`, layer 2 = `2`, layer 3 = `4`, layer 4 = `8`.

| Node | Layer | Mask | Notes |
| --- | --- | --- | --- |
| `Hooshang.tscn` (`CharacterBody2D`) | `2` player | `1` world | The only thing on layer 2 |
| Imported tileset physics | `1` world | `0` | Static geometry never scans |
| `LdtkWorld` room ceilings | `1` world | `0` | Invisible lids, built in code |
| `NoteTile` solid body | `1` world | `0` | Landable, head-buttable block |
| `Hazard.tscn` | `4` hazards | `2` player | Detects the player; nothing detects it |
| `Checkpoint.tscn` | `8` triggers | `2` player | |
| `NoteTile` → `Touch` area | `8` triggers | `2` player | Oversized contact skin |
| LDtk `Exit` trigger | `8` triggers | `2` player | Built by the entities hook |
| `LdtkRumiTrigger` | `8` triggers | `2` player | Full-height pillar; cannot be jumped over |
| `Lemon.tscn` | `8` triggers | `2` player | Collectible; only the player can take it |
| `LdtkWorld` return door | `8` triggers | `2` player | Makes an exit two-way |
| Level trigger areas (`.tscn`) | `8` triggers | `2` player | Intro / dash / exit triggers |

**The governing rule: every trigger and hazard masks *only* the player layer.**
That is what guarantees trigger isolation — an enemy on layer 3 can never start a
conversation, because no trigger scans layer 3.

Note the direction of the relationship: **areas detect the player; the player
does not scan for areas.** The player masks only layer 1 (world). Hazards,
checkpoints and triggers are `Area2D`s that scan layer 2 and react. Anything new
that must interact with Hooshang should follow that pattern rather than widening
the player's mask.

`StaticBody2D` emits no contact signals of its own, which is why `NoteTile` pairs
a solid body on layer 1 with a slightly oversized `Area2D` skin on layer 4 —
resting *on* a surface is a touch, not an overlap.

### Player state machine

`scenes/characters/hooshang/player.gd` is a small state machine:

```
IDLE · RUN · JUMP · FALL · DASH · WALL_SLIDE · DEAD
```

Every physics constant is an `@export` with a one-line comment, grouped in the
Inspector (Run / Jump / Gravity / Dash / Glow / Wall). Abilities gate on flags
(`has_dash`, `has_glow`); cutscenes set `input_locked`; all visuals are decided
in one place, `_update_visual()`.

**One invariant is load-bearing:** `_state_ground()` (IDLE / RUN) applies no
gravity, because on the floor there is nothing to fall towards. A ground state
must therefore never survive being airborne — otherwise nothing pulls the player
down and he keeps his vertical speed forever, which reads in game as floating up
to the ceiling and hanging there. `_post_move()` enforces this at the end of
every frame. **If you add a state, ask whether it applies gravity; if it does
not, it needs the same guard.**

---

## Getting Started / Setup

### Requirements

- **Godot 4.6**
- **LDtk 1.5.3+** to edit levels (optional — only for level design)
- **Python 3** for the generators in `tools/` (standard library only)

The `ldtk-importer` addon is committed under `addons/` and enabled in
`project.godot`; no plugin installation is needed.

### Running

1. Open Godot → Import → select this folder's `project.godot`.
2. Press **F5**. The main scene is `scenes/debug_level_picker.tscn`, a launcher
   listing the LDtk Act, each individual room, and the legacy hand-built levels.
   Room buttons are generated from the world scene, so rooms added in LDtk
   appear automatically.

Before shipping, point `application/run/main_scene` at the real first level.

### Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | WASD / Arrows | D-pad / L-stick |
| Jump | Z / Space | A (bottom) |
| Dash | X / Shift | X (left) / RB |
| Retry | R | — |
| Debug overlay | F3 | — |

### Tests

All suites are headless and exit `0` on success. **Run them after any player,
level, or layering change.**

```bash
GODOT=/path/to/Godot
for t in smoke_test level1_test level2_test world_bounds_test \
         flow_test backtrack_test intro_test screen_test; do
  "$GODOT" --headless --path . res://tests/$t.tscn
done
```

| Suite | Covers |
| --- | --- |
| `smoke_test` | Movement physics: run, jump, dash, wall slide, death/respawn, and the airborne-ground-state invariant |
| `level1_test` | Level 1 story beats |
| `level2_test` | Level 2 jump calibration (which jumps genuinely need the dash) |
| `flow_test` | Level 1 → Level 2 transition |
| `world_bounds_test` | LDtk rooms are sealed at the top — a jump+dash can't leave through the ceiling |
| `backtrack_test` | Exits work both ways, all the way back, not just one room deep |
| `intro_test` | Act I dialogue order, portrait per line, dashless start, dash granted in room 2 |
| `screen_test` | UI and world stay on separate surfaces; restyling dialogue can't touch the game |
| `lemon_test` | Collectible pickup, and the total surviving level changes and death |

`tests/screenshot.tscn` renders a level **windowed** and saves viewport PNGs —
useful for checking visuals without opening the editor.

### Collectibles (lemons)

Place **`Lemon`** entities by hand in LDtk — that is the whole authoring
step, there are no fields to fill in. `ldtk_entities_post_import.gd` turns each
one into `scenes/props/Lemon.tscn`, which spins, bobs, glows faintly so it
is findable in the dark rooms, and pops when Hooshang touches it.

The running total lives in the `Collectibles` autoload, so it carries across
rooms, levels, Acts and deaths. It also records which fruit have been taken, keyed
by world position — otherwise reloading a world would re-spawn ones you had
already banked and let you farm the count.

Add the entity definition to a fresh `.ldtk` (or restore it if a save wipes it):

```bash
python3 tools/ldtk_entities.py
```

### Editing levels

- **Level design** happens in the LDtk app on `ldtk/hooshang_claude.ldtk`.
  **Never hand-edit a `.ldtk` file**: LDtk keeps the whole project in memory and
  rewrites the entire file on save, so on-disk edits are silently reverted.
  Systemic fixes belong in the Godot import hooks, where they re-apply on every
  import.
- **Generated levels** (`scenes/levels/act1_office/`) are written by
  `tools/gen_level*.py`. Change the generator, not the `.tscn`.
- If the editor is open, a headless `--import` may stall — retry once, or close
  the editor.

### Conventions

`STYLE_GUIDE.md` is the full reference and should be followed by default;
`LIGHTING.md` covers lighting rooms by hand. In short: composite objects are their own `.tscn` prefab tweaked via `@export`s,
never assembled inline in a level; scripts live next to their scene; scenes and
nodes are `PascalCase`, scripts and variables `snake_case`; use groups
(`player`, `lights`, `checkpoint`, `hazard`, `exit`, `story_door`, `note_tile`)
to find things; prefer signals and public methods over reaching across the tree.
