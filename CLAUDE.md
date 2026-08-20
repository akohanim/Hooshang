# Hooshang — project context

A 2D precision platformer in the spirit of Celeste. Hooshang, an elderly office
worker, escapes a dark corporate office; Rumi (a golden guide figure) grants
abilities at story beats. Godot 4.6, GDScript. **Art direction: modern detailed
pixel art** (Celeste / Hollow Knight/ Super Mario) — see the Art direction
section below. Everything runs at 320×180 on an **8px tile grid** (viewport
stretch, integer scale, nearest filtering) — the LDtk world was 16px until the
migration described under Art direction, and the greybox levels always were 8px,
so the two agree now. The tiles are still placeholder art.

## Running things

- Godot binary (this machine): `/Users/ari/Downloads/Godot.app/Contents/MacOS/Godot`
- Main scene: `scenes/ui/MainMenu.tscn` (the title screen — NOT the debug
  picker any more, and not a level; it hands worlds to `Screen.load_scene`)
- Movement test gym: `scenes/levels/TestLevel.tscn` (8 labeled sections, one per mechanic)
- Headless tests (run after any player/level change, exit code 0 = pass):
  - `Godot --headless --path . res://tests/smoke_test.tscn` — movement physics
  - `Godot --headless --path . res://tests/level1_test.tscn` — Level 1 beats
  - `Godot --headless --path . res://tests/level2_test.tscn` — Level 2 jumps
  - `Godot --headless --path . res://tests/flow_test.tscn` — Level 1→2 transition
  - `Godot --headless --path . res://tests/world_bounds_test.tscn` — LDtk rooms
    are sealed at the top (a jump+dash can't leave through the ceiling), and
    he cannot STAND out over a drop (`Player.footing_width`)
  - `Godot --headless --path . res://tests/backtrack_test.tscn` — Exits work
    both ways all the way back, not just one room deep
  - `Godot --headless --path . res://tests/intro_test.tscn` — Act I's beats:
    dialogue order, dashless start, room 1 grants nothing, room 2 grants dash
  - `Godot --headless --path . res://tests/screen_test.tscn` — UI and world stay
    on separate render surfaces (restyling dialogue can't touch the game)
  - `Godot --headless --path . res://tests/lemon_test.tscn` — collectibles:
    pickup, and the total surviving level changes and death
  - `Godot --headless --path . res://tests/death_test.tscn` — exactly one death
    counted per respawn, from a hazard and from the kill plane alike
  - `Godot --headless --path . res://tests/slide_test.tscn` — SlideZone: control
    throttled inside, no jump or dash, and everything restored on the way out
  - `Godot --headless --path . res://tests/music_test.tscn` — the tile puzzle:
    the glow needs all five pads, once each, in order, and one landing on a
    seam between two pads counts as one step
  - `Godot --headless --path . res://tests/conveyor_test.tscn` — ConveyorBelt:
    carries a rider at `speed` in `direction`, never touches his velocity, and
    lets go the moment he is airborne
  - `Godot --headless --path . res://tests/chase_route_test.tscn` — meeting
    Darkshang re-points Level_13's ENTRANCE at Level_14 (not back at Level_12),
    it holds however many times that doorway is used, and no other room moves
  - `Godot --headless --path . res://tests/route_order_test.tscn` — play order is
    the level IDENTIFIER, not world position: the escape row (14-23) runs right
    to left across the grid, so position order reads it backwards
  - `Godot --headless --path . res://tests/collapse_test.tscn` — RoomCollapse:
    every prop hanging in the air lands ON the floor, props already down and
    markers/triggers are left alone, and the landing squash springs back
  - `Godot --headless --path . res://tests/save_test.tscn` — the three save
    slots: a full round trip (save, wipe in memory, load, every owner's state
    back), the slots staying independent, a truncated/corrupt/unknown-schema
    file reading as an EMPTY slot rather than crashing the title screen, the
    Darkshang re-route surviving a save and load (walked, not just compared),
    a level-select run writing nothing, and the pause menu's QUIT banking the
    run and handing it to the title screen
  - `Godot --headless --path . res://tests/dialogue_placement_test.tscn` — the
    dialogue box's TOP/BOTTOM placement: flush against whichever screen edge is
    asked for, grows AWAY from that edge as the line gets longer, and switching
    edges between lines leaves nothing behind from the one before
  - `Godot --headless --path . res://tests/intro_video_test.tscn` — the opening
    film: the stream is Ogg Theora (the ONLY container Godot plays — an MP4
    loads as a silent null), it plays on a NEW run, and CONTINUE skips it
  - `Godot --headless --path . res://tests/menu_nav_test.tscn` — menu navigation
    on a CONTROLLER: a stick resting past the walking deadzone moves nothing,
    one push moves exactly one row, a held direction repeats only after a delay
  - `Godot --headless --path . res://tests/dash_tutorial_test.tscn` — Level_2's
    diagonal-dash lesson: the prompt arrives at the dash point, a FLAT dash
    does not clear it and an up-forward one does, and only that room's
    crumbling panels are relaxed
  - `Godot --headless --path . res://tests/platform_test.tscn` — the two office
    ceiling platforms: the solid one holds, the crumbling one gives way in
    under a second and comes BACK on reset (collision, art and its spent flag)
  - `Godot --headless --path . res://tests/pause_test.tscn` — the pause screen:
    the world stops and comes back in exactly the state it stopped in,
    `Engine.time_scale` survives a pause taken mid-hitstop, and pause is refused
    while `input_locked` or when the loaded scene has no player
- If the editor is open, headless `--import` may stall — retry once, or close
  the editor. Never kill the user's `--editor` process.
- **Editing `scripts/ldtk_entities_post_import.gd` does not re-import the
  world.** Godot re-imports a `.ldtk` when the `.ldtk` changes, not when the
  hook that builds its entities changes — so a newly handled (or renamed)
  entity stays raw data in `ldtk/levels/*.scn` and simply never appears, with
  no error anywhere. `touch ldtk/hooshang_claude.ldtk` then `--import`.
- **Level identifiers ARE the play order**, and `LdtkWorld.rooms` is sorted by
  them. `Level_0` is the opening room. The world is no longer one left-to-right
  row: rooms 14-23 are the escape and run RIGHT to left along the bottom of the
  grid, retracing rooms 11-3 (room N pairs with room 26-N). Sorting by world
  position — which this used to do — reads that row backwards, and every "next
  room" fallback then hands you the room you just left. Renumber when you insert
  a room, and re-letter that room's lights with it (`LIGHTING.md`).
- **A renamed level needs the import CACHE cleared, not just a re-import.**
  Deleting `ldtk/levels/*.scn` is not enough — the world scene itself is cached
  in `.godot/imported/hooshang_claude.ldtk-*`, and a stale one loaded two rooms
  on top of each other at the same world x while every name looked right.
  `rm .godot/imported/hooshang_claude.ldtk-* ldtk/levels/Level_*.scn` then
  `--import`.
- **`force_tileset_reimport=true` is set in `hooshang_claude.ldtk.import`, and
  it has to stay on.** Left off, the importer LOADS the existing
  `ldtk/tilesets/tileset_8px.res` and then walks the sheet doing "create the
  tile if it is missing, REMOVE it if it is there" — so every import inverts
  which tiles exist. That is how a 48px sheet kept importing as four tiles with
  the texture arriving at 48px: cells painted with a new value came through as
  nothing at all, in every room, with no missing-tile warning and nothing in the
  output to pull on. On it, the TileSet is rebuilt from the sheet each time.
  Nothing is lost by that — the per-tile collision this project needs is
  re-applied on every import by `scripts/ldtk_tileset_post_import.gd`, which is
  exactly why that hook exists rather than the collision being set by hand.
- **Keep LDtk closed while editing `hooshang_claude.ldtk` from code.** LDtk
  holds the whole project in memory and writes it back wholesale; it has
  already silently reverted one entity rename. Reload the project in LDtk after
  any scripted edit.

Lighting a room by hand (fixtures, the moon window, seam spill): `LIGHTING.md`.

## Art direction## Art direction

**Modern detailed pixel art** — the fidelity of Celeste / Hollow Knight / Super Mario. Soft gradient shading, dithering, and dynamic 2D lighting are all wanted;
**explicitly NOT 8-bit/NES flat-palette retro.** This replaces the earlier
"8-bit" direction. Design doc §7 (Visual & Audio Style) is the source of truth.

Target specs (real art migrates the greybox toward these):
- Character canvas ~32×48 px; base tile grid **8×8 px**. The LDtk world was
  converted from 16px to 8px (`tools/ldtk_to_8px.py`) — nothing moved in pixels,
  every cell was cut into four. Rooms are 40×24 cells.
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
  character, 8×8 tile) — default prompts skew retro.
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
- `systems/collectibles.gd` — `Collectibles` autoload: the lemon ("coin")
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
- `systems/save_game.gd` — `SaveGame` autoload: three slots in
  `user://saves/slot_N.json`, versioned by a `schema` field and written
  tmp-then-rename so an alt-F4 mid-write costs the newest save and not the slot.
  Missing/truncated/corrupt/unknown-schema all read back as `{}` — an empty
  slot — so no file on disk can crash the menu. **Progress here is not "which
  room"**: it is spread across owners that each restore WRONG by default, so
  every one of them exposes `save_state()`/`load_state()` and this only composes
  them (Collectibles' total AND taken set, Deaths, `Game.current_index`,
  LdtkWorld's `_way_back` + `has_dash` + room, Act1Beats' `_opening_played` +
  `_collapsed` + whether Darkshang has been met). The two autoload counters are
  PUSHED before the world loads (a lemon checks `is_taken` in its own
  `_ready`); the world's own state is PULLED by LdtkWorld and Act1Beats in their
  `_ready` via `SaveGame.state_for(key)`, because those nodes are created by the
  load itself. Autosaves on every room transition (deferred a frame, so
  everything else listening to `room_changed` has reacted first) and once more
  when you quit to the title. `SaveGame.slot == -1` means "write nothing" — the
  debug picker, level-select practice runs and every test run unbound, so
  nothing they do can touch a player's save.
- `systems/game.gd` — `Game` autoload: level progression + Celeste-style fade
  transitions. `Game.LEVELS` is the ordered scene list; reaching a level's exit
  sign fades out, loads the next, fades in. The loaded level is the running
  checkpoint (death respawns at its start; completed levels never replay).
  `Game.test_mode = true` exercises progression without swapping scenes.
- `scenes/ui/` — `DialogueBox.tscn` (Celeste-style banner + portrait; registered
  as the `Dialogue` autoload — call `Dialogue.say(speaker, text, tint, face,
  side)`), `EmoteBubble.tscn` (world-space reaction bubble) and
  `DebugOverlay.tscn` (F3). See the dialogue rules below before writing a scene.
  `MainMenu.tscn` is the game's entry point (`run/main_scene`) — same
  1280x720-scaled-by-0.25 CanvasLayer arrangement as the pause menu, on layer
  110. Continue / New Game / Load Game / Level Select / Quit, navigated with the
  pause menu's keys exactly (no mouse). It HIDES rather than frees itself on
  handing over, so the pause menu's QUIT — which now returns here instead of
  ending the process — is a boolean and not a scene load; `MainMenu.open(tree)`
  is the way back and clears the world first, which is also what makes the title
  screen unpausable (`can_pause()` needs a world). The player-facing level
  select offers only rooms a slot has actually stood in and binds no slot;
  the debug picker still lists everything and is on the menu in EXPORTED builds
  too (the `OS.is_debug_build()` gate was removed — it hid the row from the
  itch.io build, which is the one most people play).
  `PauseMenu.tscn` is the `Pause` autoload — Escape / Start / Select opens it,
  the same button closes it, and it is the ONLY node set to
  `PROCESS_MODE_ALWAYS`, so `get_tree().paused` freezes everything else exactly
  where it stood. It refuses to open unless a world is loaded and its player has
  his controls, which makes `input_locked` the single gate covering dialogue
  beats, story doors, room slides and Game's level fade. Opening it also puts
  `Engine.time_scale` back to 1.0, so a pause taken inside Juice's hitstop can
  never resume in slow motion. A respawn hold is therefore a PAUSABLE
  `SceneTreeTimer` (`create_timer(t, false)`) in both `level_base.gd` and
  `ldtk_world.gd` — the default keeps counting through a pause and would respawn
  him behind the menu.
- `scenes/props/` — `Checkpoint.tscn`, `hazards/Hazard.tscn` (both @tool,
  size-exported), `lighting/LampFixture.tscn` (reusable lamp; joins `lights`).
  `lighting/SunShaft.tscn` is the third light source after `LampFixture` and
  `MonitorGlow`, and the only one you look AT: parallel bars of light falling
  from a window with dust drifting in them. The bars are `PointLight2D`s, not
  painted quads — `CanvasModulate` is 0.05 and would eat a painted one — and the
  motes are ordinary sprites LIT by the bars, so they are bright inside a beam
  and invisible between them with nothing masking them. Room 22 is the only
  user; pair it with `backdrop/DawnWindow.tscn` (`MoonWindow`'s warm twin, same
  frame art) and see `LIGHTING.md`.
  `hazards/GlassSpikes.tscn` EXTENDS `Hazard`, so layer, mask and the kill are
  inherited and can't drift from the greybox boxes — it only overrides
  `_build_visual()`/`_update_extents()`. One LDtk entity per surface —
  `GlassSpikes` (floor), `GlassSpikesCeiling`, `GlassSpikesLeftWall`,
  `GlassSpikesRightWall` — each stretchable only ALONG the surface it is stuck
  to; the other axis is forced to one cell on import. Art:
  `tools/gen_glass_spikes.py` draws the floor sheet and transforms the other
  three, keeping the light in the upper left rather than rotating it.
  `backdrop/WallPattern.tscn` is the Persian rosette that blooms on the office
  walls. A LIGHT, not paint — `CanvasModulate` 0.05 would eat a painted one, the
  same trap `SunShaft` documents — with the ornament in the cookie's alpha so one
  texture covers the palette it cycles. `range_item_cull_mask` 2 is the part
  worth knowing: only the room backdrop carries that bit, so the pattern cannot
  wash over the bricks, the props or Hooshang, which is what makes it read as
  being IN the wall. See `LIGHTING.md`.
  `zones/SlideZone.tscn` is a volume, not a prop: inside it Hooshang's steering
  drops to `control_strength`, a drag builds along `angle`, and jump and dash
  are off. The zone only DESCRIBES the slide — `Player.enter_slide()` takes the
  numbers and player.gd does all the moving, so nothing else writes velocity.
  Place it in LDtk as a `SlideZone` and set the three fields per instance.
- `assets/hooshang_frames.tres` = SpriteFrames from the samurai pack
  (`assets/FREE_Samurai .../Sprites`); Rumi reuses it tinted gold.
- `tests/room_shot.tscn` — dev capture harness, not a pass/fail test. Stands the
  player in a named room, photographs the 320x180 game surface and prints the
  frame's mean/peak luminance (the units `LIGHTING.md`'s targets are quoted in).
  Runs WINDOWED — 2D does not rasterise headless — and binds no save slot:
  `Godot --path . res://tests/room_shot.tscn -- Level_24`
- `tests/feel_measure.tscn` — the same idea for MOVEMENT, and also not pass/fail.
  Prints the jump apex, the airtime, the horizontal reach of a running jump and
  a 20-timing sweep of the jump+up-dash. Run it before and after touching
  anything in player.gd's Jump/Gravity groups: those numbers are what the level
  geometry is built against, and "floatier" is very easy to ship as "the 2-cell
  pillars no longer stop anybody". Runs headless:
  `Godot --headless --path . res://tests/feel_measure.tscn`
  **Airtime is capped by Level 2's second gap**, which is a dash GATE — airtime
  times max_run_speed is horizontal reach, and past about +16% a plain running
  jump clears a gap that exists to teach the dash (`level2_test` catches it).
- `tools/ldtk_to_8px.py` — the one-shot 16px -> 8px grid migration, kept for the
  record because it documents what the conversion had to get right. It
  REGENERATES the auto-layer tiles rather than leaving that to LDtk (they live
  in the `.ldtk` and the importer reads them straight out of it), and its
  `--verify` mode repaints the world from the rules and diffs it against what
  LDtk stored — that came back 0/1893 mismatches before anything was written,
  which is the only reason it was trusted. Two non-guessable details it had to
  match: `outOfBoundsValue` is 2, so past a room's edge counts AS brick, and
  every rule also matches its X/Y/XY-mirrored self.
- `tools/gen_bricks_8px.py` — the four 8px wall tiles (fill, top, left,
  corner). Four is the WHOLE tileset: no tile in the world is hand-placed, and
  the four auto-rules never ask for anything else.
- `tools/gen_lemon.py` — the lemon collectible, cut from a generated bounce
  sheet. Two things it has to do that a crop-and-resize does not. The source is
  a JPEG with the **transparency checkerboard baked in as pixels**, and JPEG
  ringing defeats a colour key (77% background at the tightest usable tolerance,
  noise in every column) — so the key is SATURATION, since the fruit is strongly
  coloured and the checkerboard is grey. And the frames are cut by CONNECTIVITY,
  not by row density: the leaf is thin, so a density test reads it as a motion
  swoosh and silently deletes it, which is how the first pass came out as yellow
  blobs. The bounce in the sheet travels more than a body-height, so the offsets
  are kept but SCALED — which is why `Lemon.tscn` sets `bob_height = 0`, or the
  prop's own tween hovers it a second time and the squash drifts out of step.
  Sizes: `10` world, `20 dense`, `16 icon` (writes `ldtk/art/lemon.png`).
- `tools/gen_persian_trim.py`, `gen_persian_glyph.py` — the Persian polish. The
  trim is UI art authored in the dialogue box's own 1280x720 space (a quarter of
  a design pixel each), the glyph is a light COOKIE and therefore white with the
  shape in its alpha.
- `tools/gen_platforms.py` — the two office-ceiling platforms, cut from a pair
  of renders. The repeating unit is 24x8 (3 cells by 1) because the source's
  seam period lands at ~11px once the band is 8px tall, and 24 keeps roughly
  two diagonals per tile; at 16 it reads as corrugation. The crumbling
  platform's three damage frames are the SOLID tile with holes stamped on,
  not cuts from the deteriorated render — eight pixels of height turns that
  render's cracks into speckle, and the worst window came back a black bar.
  `tools/ldtk_add_platforms.py` adds the two LDtk entities (LDtk must be
  CLOSED; it refuses to run otherwise).
- `tools/gen_dust.py` — the puffs kicked up on a jump, a landing and a dash
  start. Its own sheet rather than `death_shard.png` tinted: shards are
  hard-edged debris, and a landing that throws those reads as a small death.
- `tools/gen_dawn_window.py`, `gen_light_shaft.py`, `gen_light_mote.py` — the
  room 23 sunrise art. `light_mote.png` is deliberately NOT `debris_dust.png`:
  a mote must be radially symmetric and shapeless, because particles spin.
- `tools/gen_eclipse_moon.py` — two white alpha masks (umbra + halo) sized to
  `moon.png`'s own disc, which is how `MoonWindow` runs the escape row's blood
  moon as a per-instance ramp instead of ten drawn moons (`LIGHTING.md`).
- `tools/gen_level.py`, `tools/gen_level1.py` — regenerate the greybox levels
  (tilemap bytes + node layout, incl. prefab instances). Re-running OVERWRITES
  hand-edits to the generated `.tscn`. Levels are dark (CanvasModulate ~0.09) +
  `LampFixture` instances.

## Dialogue rules

How a written script becomes a scene. `scripts/act1_beats.gd` is the worked
example; `tests/intro_test.gd` asserts every rule here, so breaking one fails a
test rather than being noticed months later in play.

- **Stage directions are played, never printed.** A parenthetical in a script is
  an instruction to the scene, not words anyone says. `(looking around)` becomes
  `player.look()`; `(a breath)` becomes `DialogueBox.PAUSE_MARK` (`[p]`) placed
  mid-line, which holds the typewriter and is stripped before drawing. Never let
  one reach the screen as text.
- **Punctuation-only lines are reactions, not speech.** `!` and `...` play as an
  `EmoteBubble` over the speaker's sprite — see `Act1Beats.EMOTE_LINES`. A banner
  that slides in, types out `...` and waits for a button press turns a beat of
  silence into paperwork. You watch a reaction; you read a line.
- **Every line types at the same speed.** No per-line `chars_per_second`. A line
  that reveals at its own rate reads as a different KIND of text rather than a
  quieter one — say it with the words and the portrait instead.
- **A speaker's face sits on the side they are standing on.** Pass
  `DialogueBox.Side`; `LdtkRumiTrigger.portrait_side()` derives it from where the
  sprite actually is, so it cannot disagree with the screen. Hooshang is the
  player, so he is the other side.
- **One portrait state per line.** Beats name a state (`"annoyed"`), not a file,
  so re-cutting the portrait sheet never touches the dialogue.
- **Long lines are fine, and they PAGE.** The banner grows to fit up to
  `max_lines` (3) and no further; past that the line is broken into pages at
  SENTENCE boundaries and shown a press at a time (`_paginate`). An ellipsis is
  never treated as a sentence ending, so a held breath cannot become a page turn.
  Do not shrink the font to fit more in — the type size is the thing that makes
  this read like Celeste, and a six-row banner covers the room the scene is set
  in, which is what the cap exists to stop.
- **The banner is closed top and bottom by a Persian khatam border**
  (`tools/gen_persian_trim.py`). It is TILED, so it does not care how wide the
  banner is — but it does care how tall: the bands hang off the banner's own two
  edges, so `TRIM_HEIGHT`, the name label's y and `_fit_banner`'s arithmetic are
  one set of numbers and have to move together. `dialogue_placement_test` checks
  both bands stay on the banner's edges through mirroring, BOTTOM placement and
  pagination growth — the bottom one is POSITIONED rather than shifted, so it is
  the one that gets left behind.
- Dialogue is drawn on the window's own surface at full resolution, the emote
  bubble inside the 320x180 game viewport with the sprites. That split is
  deliberate — see `systems/screen.gd`. Restyling one can never touch the other.

## Physics/level conventions

- Physics layer 1 = world, 2 = player. Areas (hazard/checkpoint/triggers)
  collide with mask 2 only.
- Every tunable is an `@export` with a one-line comment saying what tweaking
  it changes. Feel timers count down as plain floats in `_tick_timers()`.
- Player hitbox 8x12 — one cell wide, one and a half tall on the 8px grid.
  **It is wider than he is drawn** (4.7px), which is why `Player.footing_width`
  exists: Godot keeps a body standing while any part of its shape overlaps the
  floor, so without it he rests with his centre 4px past a ledge and every
  drawn pixel over air. Narrowing the hitbox cannot fix that — it would have
  to go under 4px, narrower than the sprite and no longer the one-cell body
  the grid is built around.
  Interiors: 6 cells = claustrophobic, walkable min is a 2-cell (16px) slot.
  Jump reaches 34px (~4 cells), dash ~39px (~5), jump+dash ~85px (~10).
  **These are pixel figures first.** The grid halving did not move any of them,
  and a future grid change should not either — level geometry is built against
  the pixels, and the cell count is just how it reads on the current grid.
- Checkpoints are silent Area2Ds; death is instant respawn, no penalty.

