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
    he cannot STAND out over a drop (`Player.footing_width`). Its launch point is
    the room's highest tile HIS BODY FITS ABOVE, not merely one with three empty
    cells over it: the seal is an invisible lid outside the tilemap, so the tile
    test alone aimed three rooms at the roof and they read as unstandable. The
    apex is also measured only while he is still IN the room — a launch that ends
    in the kill plane respawns him at the checkpoint, which can be a whole row of
    rooms away, and that landed in the reading as "706px of reach"
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
  - `Godot --headless --path . res://tests/chase_entry_test.tscn` — the shadow
    waits at the threshold: after a respawn or a room change he is parked OUT of
    the room until the player has travelled `entry_hold_distance` (16px) along
    the route. Standing still keeps him out however long, backing UP keeps him
    out too (it is distance along the route, not distance travelled), he cannot
    kill while he waits even with the player standing on him, and crossing the
    line lets him in at the FULL gap measured from where the player is by then
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
  - `Godot --headless --path . res://tests/cone_spikes_test.tscn` — the 8px
    conical spikes: all four facings build five cells from their OWN sheet with
    the kill box leaning towards the points, the lethal band stops exactly where
    the cones end so standing in the base is safe, and a longer strip gets
    longer rather than deeper. The base check is made THROUGH the physics server
    with a 2px probe body — the real player is 12px tall and cannot fit in a 3px
    base, so a test using him could only ever prove the cones kill
  - `Godot --headless --path . res://tests/dark_thought_test.tscn` — the drifting
    cloud: all three motions swing the amplitude they were given and no further
    (each backed by a measured-travel control, so "stays on one x" cannot pass
    for a thought that never moved), a circle stays exactly the radius out and
    goes the way `clockwise` says, `phase` separates two otherwise identical
    thoughts — with a same-phase control proving the gap came from the field and
    not from sampling drift — and `reset_all` restores the placed point AND the
    cycle. A plain Hazard hung at the same height DOES drop when the room
    collapses while the thought stays in its band, which is what makes the
    anchored check mean something. It also holds the GLOW: the prop carries no
    Light2D at all (the assertion nothing else can catch — a change back to a
    PointLight2D looks right in an empty test room and fails only in a full
    one), the halo is unshaded/additive and behind the cloud, and the `Glow`
    field switches it with unset counting as on
  - `Godot --headless --path . res://tests/platform_test.tscn` — the two office
    ceiling platforms: the solid one holds, the crumbling one gives way in
    under a second and comes BACK on reset (collision, art and its spent flag)
  - `Godot --headless --path . res://tests/portrait_anim_test.tscn` — the talking
    dialogue faces: the loop manifest loads off res:// at all, a looped face
    draws its sheet over the still (and leaves the older overlays off) while the
    still underneath still NAMES the face, the frame window stays on the sheet,
    the loop travels with the banner when it mirrors, speech frames run only
    while words are appearing and never land on the rest frame — returning to it
    on a `[p]` breath and the moment the line ends — and the eyes blink
    unprompted, from a blink frame kept OUT of the speech cycle
  - `Godot --headless --path . res://tests/chimney_test.tscn` — Level_1's
    one-cell shaft: standing over its mouth takes him in from anywhere across
    the cell, running over it drops him in rather than across, and once inside
    he wall-slides down at the cap with nothing held and can wall-jump back out
    — coming back to full width on the way. It finds the shaft by sweeping the
    world and asserts it is one cell wide before using it.
    **It also covers the one-cell gaps made of PROPS**, which that sweep cannot
    see: it reads the `Collisions` TileMapLayer, and Level_2's two drop-throughs
    are gaps in a run of platform props under `Entities`. They were reported
    broken from play while this file was passing. Those are found from the
    COLLIDERS — two prop boxes with the same top edge, a cell apart, and room for
    his squeezed body to stand over them, which is what rules out the four
    lookalike gaps between CEILING panels (plugged by the room's invisible lid)
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
- **`addons/ldtk-importer/src/tileset.gd` carries a local PATCH, marked
  `PATCHED (Hooshang)`. Keep it through any addon update.** Upstream builds the
  atlas with "create the tile if it is missing, REMOVE it if it is there", which
  TOGGLES — every import against an already-built tileset inverts which tiles
  exist. A level then references a tile the atlas no longer has and the cell is
  dropped in silence, in every room. That is how two new tiles on a 48px sheet
  kept importing as nothing while the texture arrived at 48px and the `.ldtk`
  held the paint: no error, no missing-tile warning, nothing to pull on. The
  patch is the comment's own stated intent — create in non-empty cells, remove
  in empty ones, leave the rest alone — which makes an import idempotent.
  `force_tileset_reimport=true` is also set in `hooshang_claude.ldtk.import` as
  a second line of defence; nothing is lost by rebuilding the TileSet, because
  the per-tile collision this project needs is re-applied on every import by
  `scripts/ldtk_tileset_post_import.gd`.
- **A running Godot EDITOR re-imports with the state it started with.** It
  re-imported the world seconds after an import flag was set and dropped the new
  tiles right back out, which looked exactly like the fix not working; a newly
  handled ENTITY goes the same way, arriving as nothing while the hook that
  builds it plainly has a case for it. Restart the editor after changing
  anything in a `.import` OR in a post-import hook, and rebuild:
  `rm .godot/imported/hooshang_claude.ldtk-* ldtk/levels/Level_*.scn` then
  `--import`.
- **An LDtk ENUM field arrives QUALIFIED.** `field-util.gd`'s `__parse_enum`
  returns `"ThoughtMotion.Circle"`, never `"Circle"` — the regex there pulls the
  enum's NAME out of the type string, it does not strip it off the value. Match
  the bare name and every value misses and falls through to the default case,
  which is not an error anywhere: the entity imports, draws, kills, and quietly
  behaves as though the field were never set. That shipped once — every
  DarkThought drifted vertically whatever Motion said in LDtk. Read enum fields
  with `_field_enum()`, not `_field_str()`; `dark_thought_test` pins both the
  addon's output shape and the mapping.
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
- `systems/points.gd` — `Points` autoload: the run's SCORE, top-left under the
  fruit count. Not the fruit count times 1000: Collectibles counts lemons and a
  save is really about which fruit are still out there, so the two are separate
  numbers with separate owners. Anything that pays out calls `award(amount,
  source)`, which banks it, rolls the counter up and pops the "+N" over whatever
  earned it — nothing else has to know the tag exists. `_set_shown` KILLS the
  roll before setting the number, because a load that only assigns leaves the
  running tween writing the run you just left over the one you opened.
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
  `hazards/ConeSpikes.tscn` is the SINGLE-CELL version of exactly that: 8px
  conical spikes for a floor you want threatened without giving up two cells of
  the room's height. Same four-entity split (`ConeSpikes`, `ConeSpikesCeiling`,
  `ConeSpikesLeftWall`, `ConeSpikesRightWall`), same axis forcing, art from
  `tools/gen_cone_spikes.py` and the entities from
  `tools/ldtk_add_cone_spikes.py`. **`Hazard.KILL_MARGIN` cannot be used across
  the cones**: it insets 2px a side, which against 5px of cone leaves ONE pixel
  — a hazard you could stand in the middle of. So the across axis uses
  `ConeSpikes.TIP_LENIENCY` (1px) shaved off the POINTED end only, and the kill
  box stops exactly where the cones do, which is what keeps standing in the base
  safe. `CONE_HEIGHT` here and `BASE_TOP` in the generator are one number in two
  files and have to move together.
  `hazards/DarkThought.tscn` is the moving one: a small black cloud with a hot
  red rim, drifting a repeating path through the air and lethal to touch. ONE
  entity with fields, deliberately not four like the spike strips — direction
  there is a binary you can forget to set and the failure is silent, whereas the
  motion here is NUMBERS (`Motion`, `Amplitude`, `Speed`, `Phase`, `Clockwise`),
  two thoughts in one room can legitimately want different paths, and one whose
  mode nobody set still visibly drifts. **The placed point is the CENTRE of the
  path in all three modes** — a CIRCLE orbits it rather than starting on it. The
  red rim is DRAWN as well as lit: a `PointLight2D` alone is not enough against
  office walls already at 255 in the red channel, the case `LIGHTING.md` records
  for Rumi's gift. Anchored against `RoomCollapse` (it is floating, not resting),
  and `DarkThought.reset_all()` puts every one back on its placed point with its
  cycle at the start — called from both of `ldtk_world.gd`'s reset sites, beside
  `CrumblingPlatform.reset_all`. Art from `tools/gen_dark_thought.py`, the entity
  from `tools/ldtk_add_dark_thought.py`.
  `hazards/LightThought.tscn` is the SAME PROP in the other tone — the same
  script, path, fields and kill box, `tone = LIGHT` — and the sheets are two
  palettes off one generator, so the two cannot drift apart. Two LDtk entities
  rather than a Tone field purely so the editor SHOWS which you placed
  (`tools/ldtk_add_light_thought.py`, which builds its definition from the
  DarkThought one and checks it key-for-key rather than transcribing the
  fieldDef shape a second time).
  **Both clouds are drawn UNSHADED and the halo is PAINT, not a light** — and
  that is the fix for glows that appeared in some rooms and not others. This
  renderer lights any one canvas item from **at most 16 lights** and drops the
  rest in SILENCE; a room with eight `CeilingPanel`s already spends 16 (two
  each), so every thought in it was competing for a budget that had run out.
  `CanvasModulate` 0.05 eats a *shaded* painted glow — the rule `SunShaft` and
  `WallPattern` document — but not an unshaded one (measured: the same sprite
  renders 0.047 shaded, 1.000 unshaded), so the halo is an unshaded additive
  sprite that cannot be culled and costs nothing from the room. `PAINT_GAIN`
  (0.35) is the calibration that buys back what a light got for free: a light
  multiplies the surface under it, paint does not, so at equal energy paint
  lands ~1/albedo too bright. `Glow` in LDtk (1/0, unset = on) turns it off.
  Full numbers and the per-item cap: `LIGHTING.md`.
  `backdrop/WallPattern.tscn` is the Persian rosette that blooms on the office
  walls. A LIGHT, not paint — `CanvasModulate` 0.05 would eat a painted one, the
  same trap `SunShaft` documents — with the ornament in the cookie's alpha so one
  texture covers the palette it cycles. `range_item_cull_mask` 2 is the part
  worth knowing: only the room backdrop carries that bit, so the pattern cannot
  wash over the bricks, the props or Hooshang, which is what makes it read as
  being IN the wall. See `LIGHTING.md`.
  `lighting/CeilingPanel.tscn` is the suspended office ceiling: a run of T-bar
  cells with a luminous panel set into one of them, `run_tiles` long and rounded
  UP to an odd count because the panel is the middle cell. Its glow is a
  `PointLight2D` wearing the panel art, not a bright sprite — `CanvasModulate`
  0.05 would eat a painted one. **It is SOLID**: the collider is built from the
  run in `_fit_body()` so it is exactly as wide as the art including that odd
  rounding, and it is gated on `show_body` — which is what makes
  `CeilingLight.tscn` (the same scene with no run drawn, for lighting a PAINTED
  8px ceiling cell) pass-through, since the tile under it already carries the
  room's collision.
  **It can be MOTION ACTIVATED**: `MotionRange` in LDtk (px, **0 = simply on**,
  which is what everything placed before it does) wakes the fixture when he
  comes near and drops it again when he leaves, over `MotionFade` seconds.
  The range is measured to the POOL — `pool_drop` below the panel, where the
  light actually lands — not to the fixture in the ceiling, which is ~164px
  above the floor he walks on and would make every number a designer typed be
  off by the height of the room. The fade is applied to the pool and the panel's
  face follows it for free, because the face is already derived from the pool
  (that is also what keeps the flicker and the sensor from fighting).
  `zones/SlideZone.tscn` is a volume, not a prop: inside it Hooshang's steering
  drops to `control_strength`, a drag builds along `angle`, and jump and dash
  are off. The zone only DESCRIBES the slide — `Player.enter_slide()` takes the
  numbers and player.gd does all the moving, so nothing else writes velocity.
  Place it in LDtk as a `SlideZone` and set the three fields per instance.
- `assets/hooshang_frames.tres` = the player's SpriteFrames: 40 east-facing 88px
  frames across eight clips, played at 0.39 scale. It points at
  `assets/hooshang_sprites/chubby/`, NOT at `.../animations/` — the thin pack in
  `animations/` is the source and `tools/gen_chubby_hooshang.py` is the pass that
  puts the weight on. `dash` is the Slide clip; west is `flip_h`, not art.
  (Rumi still reuses the samurai pack, `assets/FREE_Samurai .../Sprites`, tinted
  gold — `assets/rumi_frames.tres`.)
- `tests/room_shot.tscn` — dev capture harness, not a pass/fail test. Stands the
  player in a named room, photographs the 320x180 game surface and prints the
  frame's mean/peak luminance (the units `LIGHTING.md`'s targets are quoted in).
  Runs WINDOWED — 2D does not rasterise headless — and binds no save slot:
  `Godot --path . res://tests/room_shot.tscn -- Level_24`
- `tests/portrait_shot.tscn` — dev capture harness for the talking portraits,
  not pass/fail. Photographs the banner on every frame of a face's loop, LABELLED
  by role, so you can check that the frame the box calls `rest` really is a shut
  mouth and the one it calls `blink` really is shut eyes. Windowed, like
  `room_shot`. Shots go to `user://portrait_shots` unless a directory is given:
  `Godot --path . res://tests/portrait_shot.tscn -- hooshang_annoyed /tmp/shots`
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
  **And Level 2's THIRD gap caps it from below, much more tightly.** It is a
  94px gap with a 2-tile rise, authored so only a near-perfect apex jump+dash
  clears it, which means the geometry has almost no headroom on the slow side:
  measured by bisection, `max_run_speed` 86 still clears it and 82 does not — so
  roughly **5% is all the slowing this level tolerates**. Below that he still
  crosses the gap horizontally but arrives UNDER the platform lip and falls past
  the edge, which is the rise he can no longer make in time rather than the
  distance. Slowing him further means shortening or lowering P3 in
  `tools/gen_level2.py`; nothing else in the game is this tight.
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
- `tools/gen_cone_spikes.py` — the 8px cone sheets, four facings from one drawn
  floor sheet, same transform table as `gen_glass_spikes.py`. The PALETTE and
  proportions are measured off a Pixellab generation; the bitmap is not reused,
  because at this scale it could not be: it drew 13 cones over 160px (a cone
  every 3px once reduced — a picket fence), its cones run height = 2.35 x
  half-width (a 5px-tall cone at that slope is 5px wide, so two will not fit in
  an 8px cell), and a 4x downsample of a 15px cone loses the apex a spike is
  entirely made of. `tools/ldtk_add_cone_spikes.py` adds the four entities and
  their four 8px tilesets, as TEXT rather than a json round trip — see its
  docstring for why that matters on a 1MB project file.
- `tools/gen_dark_thought.py` — the drifting clouds, BOTH tones, cut from one
  generated strip.
  Three things it has to do that a crop-and-resize does not. The frames are cut
  by CONNECTIVITY: Pixellab returned EIGHT stamps on a 40px pitch rather than the
  five asked for, and the two on the ends are clipped by the canvas edge, so
  slicing the strip into fifths puts a seam through two clouds (the clipped pair
  identify themselves by being narrower than the modal width). The colour is a
  RECOLOUR, not a tint — it came back plum-and-pink, and "black body" and "red
  rim" are two different remaps of the same pixel, which a hue shift cannot do at
  once: the body is crushed toward black along its own luminance so the lobes
  survive as shading, and every opaque pixel with a transparent neighbour is
  repainted hot red AFTER the reduction, so the rim stays one crisp pixel. And
  the loop is a BREATH, a 12/13/12/11px height cycle inside a fixed cell, rather
  than the sideways roil the strip suggests — the prop is already travelling, so
  a drawn offset reads as the sprite lagging its hitbox.
  It writes `dark_thought.png` and `light_thought.png` from one cut and one
  reduction, differing only in the body ramp — verified: all 160 rim pixels are
  byte-identical between the sheets and all 429 body pixels changed. Two scripts
  would let a retimed breath land in one and not the other, which is two hazards
  that no longer read as the same object.
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
- `tools/gen_rumi_loops.py` — Rumi's talking sheets, seven frames per
  expression in the same shape as Hooshang's: the still, five mouth positions,
  a blink. The mouths come from a Pixellab `animate_image` pass and the blink
  from an `edit_image` "eyes closed"; both are 256px and both are REGENERATIONS
  of the whole portrait, which is the thing this tool exists to undo. Measured
  on the first pass, the animator moves the silhouette centroid only 1.6px — the
  head does not really go anywhere — but the mean per-pixel difference from the
  still is ~20/255 spread evenly over turban, beard and shoulders, and the
  busiest rows in the frame were the TURBAN, not the mouth. Played back that is
  a portrait boiling, which on flat pixel art is the most obvious artifact there
  is. So every frame is the STILL with one feathered ellipse composited on:
  the mouth (centred 136, 162, from the motion map of the talking pass) or the
  eyes (136, 110, from the blink's own difference against the still). The head
  cannot drift because there is only ever one head. `gen_portrait_frames.py`
  made the same call for Hooshang's older rig.
  **`gen_portrait_loops.py` needed a per-face eye band for this.** Its default
  is Hooshang's y 40-68; Rumi wears a turban and his eyes are at y 98-124, and
  read in the wrong band the blink is simply never found — the face still talks,
  still rests, and silently never shuts its eyes. Entries may now carry `eye`.
  The indexer then finds Rumi's blink at frame 6 on its own, which is where this
  tool put it — a check rather than a copy.
- `tools/gen_rumi_portraits.py` — Rumi's five dialogue faces, normalised out of
  the raw Pixellab generations in `assets/portraits/rumi/raw/` (the reference
  the likeness came from is kept beside them in `rumi/source/`). The states are
  the file names and the file names are the contract: `Act1Beats.RUMI_FACES`
  preloads `rumi_<state>.png`, so re-cutting a face never touches a beat. What
  the script is for is the GROUND — the generator returns the bust on light
  grey and every Hooshang portrait sits on the office's near-black (55, 50, 46);
  two faces sharing a banner cannot sit on two different fields. It is replaced
  by a flood fill inward from the border, because the turban is cream and the
  undershirt near-white and a plain colour match eats holes in both. **The
  tolerance is picked off a measured plateau, and the guard is a STABILITY test
  rather than a size cap** — the first pass ran wide, took 60% of the undershirt
  and still only moved the fill from 43% to 46% of the canvas, which no
  threshold could have separated. It now runs the fill twice, at the tolerance
  and half of it, and fails if they disagree.
- `tools/gen_portrait_loops.py` — indexes the talking-portrait LOOPS: which
  frame of each sheet is silence, which are speech, which is the blink. The
  sheets themselves are generated art (Pixellab, from one base portrait); this
  turns them into something the box can drive. The blink is found by EDGE ENERGY
  in the eye band, not by brightness or by difference from frame 0: a closed lid
  removes the pupil, the lash line and the iris edge at once so the region goes
  smooth, while plain difference cannot tell a blink from a raised eyebrow —
  measured, both peak on the same frames. The blink frame is kept OUT of `talk`,
  which is what lets the mouth run off the typewriter and the blink run off its
  own clock without the two fighting over a frame.
- `tools/gen_portrait_frames.py` — SUPERSEDED for Hooshang by the loops above,
  and kept for any future face that wants patch overlays instead. Note its
  strips in `assets/portraits/anim/` are warped from the OLD paintings, which
  the loops replaced — they are stale against the current portraits, and only
  unreachable because a loop wins whenever a face has both.
  The talking dialogue faces, WARPED out of the
  painted portraits rather than drawn: a jaw that drops and a lid that closes,
  cut to patch strips in `assets/portraits/anim/` with a `manifest.json` of
  rects. Two things it has to get right that a crop does not. The jaw slide is
  composited through a FEATHERED OVAL over the chin — shifting the full-width
  band under the lip line takes the shirt collar and both cheeks with it — and
  the lid is stretched from a SIX-PIXEL strip, because these paintings leave
  barely any skin between brow and eye and a taller source drags the eyebrow
  down into every blink. `hooshang_dazed` is deliberately unrigged: it is a 3/4
  view with the mouth off the edge of the frame and a tilted eye these
  axis-aligned warps cannot follow. Re-run it after re-cutting any portrait.
- `tools/gen_points_popup.py` — the "+N" that pops off a scoring pickup, as a
  SHEET of eleven glyphs (`+0123456789`) the popup composes at runtime. It was
  one drawn picture of "+1000", which is right up until something awards a
  different number and the tag says 1000 anyway. Neon: dark outline, pale rim one
  pixel inside it, green fill, blurred tint under the lot. Strokes are THREE
  pixels because that order needs a middle — at two, every pixel is an edge, the
  rim eats the fill and the digits come out as hollow rings. Each glyph carries
  its own glow margin and the popup lays them a stroke-width apart, so the halos
  overlap the way they would in one drawing.
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
- `tools/gen_chubby_hooshang.py` — Hooshang with the weight on: the thin sprite
  pack (`assets/hooshang_sprites/animations/`) warped into
  `assets/hooshang_sprites/chubby/`, which is what `hooshang_frames.tres` plays.
  A warp rather than 40 fresh generations, because 40 independent generations
  would have to agree with each other about how fat he is frame to frame and a
  deterministic warp cannot disagree with itself. Run it AFTER `gen_wall_slide.py`,
  which writes into the thin pack. Three things it has to get right: weight is
  added in PIXELS per row and not in percent (a flat 1.6x is a belly on a
  standing frame and a flung-out arm on a running one), each row is scaled about
  a centreline SMOOTHED down the sprite (a raw per-row middle jumps wherever an
  arm enters the silhouette and shears his outline into a staircase), and the
  resample is NEAREST (anything smoother invents colours between two flat pixel
  shades — the palette count is unchanged, which is the cheapest proof it did
  not). Wall_Slide is pinned by its RIGHT edge so his palm stays on the wall.
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
- **A rigged face blinks, and talks only while it is talking.** Hooshang's
  portraits move their mouth for exactly as long as the typewriter is revealing
  — returning to rest on a `[p]` breath and on the last character — and blink on
  their own clock. Nothing in a beat asks for this: the face is found from the
  portrait TEXTURE's path, so a script still just names a state. A face with
  neither a loop nor a rig holds still, which is what every portrait did before.
  **RUMI HAS LOOPS NOW TOO** (`tools/gen_rumi_loops.py`), so that path is only
  reached by a line with no portrait at all.
  **They are LOOPS now** — a sheet of whole faces per emotion in
  `assets/portraits/loops/`, indexed by `tools/gen_portrait_loops.py` — and the
  box DRIVES the sheet rather than playing it, which is the only way those two
  rules survive: a plain looping AnimatedTexture would chew through silences.
  The frame is drawn in `$Portrait/Loop`, a child covering the portrait, and the
  still underneath is deliberately left in place: the still is how a face is
  IDENTIFIED, and an AtlasTexture built at runtime has no `resource_path`, so
  replacing it made every face come back nameless (`intro_test` catches this).
  The waking shot is no longer the deliberately unrigged one — it faces front in
  the new art, so it talks like the rest.
- Dialogue is drawn on the window's own surface at full resolution, the emote
  bubble inside the 320x180 game viewport with the sprites. That split is
  deliberate — see `systems/screen.gd`. Restyling one can never touch the other.

## Physics/level conventions

- Physics layer 1 = world, 2 = player. Areas (hazard/checkpoint/triggers)
  collide with mask 2 only.
- Every tunable is an `@export` with a one-line comment saying what tweaking
  it changes. Feel timers count down as plain floats in `_tick_timers()`.
- Player hitbox 9x12 — a cell and an eighth wide, one and a half tall on the
  8px grid. It was exactly one cell (8x12) until he put on weight; the extra
  half-pixel a side came in with the belly (`tools/gen_chubby_hooshang.py` took
  him from 4.7px drawn across to 7.0). **Keep it modest.** Walkable minimum is a
  2-cell (16px) slot, so 9 clears one with 3.5px a side and 10 starts eating a
  margin the level geometry was authored against; measured, nothing in the world
  passable at 8 is blocked at 9.
  **It is still wider than he is drawn where it matters** — his boots are 3.1px
  across (1.17 left of centre, 1.95 right) — which is why `Player.footing_width`
  exists: Godot keeps a body standing while any part of its shape overlaps the
  floor, so without it he rests with his centre a whole box-half past a ledge and
  every drawn pixel over air. Narrowing the hitbox cannot fix that, and note
  `footing_width` does NOT scale with the box: the check probes a single ray at
  his CENTRE, and the number is that ray's downward reach.
  **A one-cell slot therefore needs the SQUEEZE.** A body a cell wide or more
  cannot pass through a one-cell hole at all — Godot resolves two
  exactly-abutting AABBs as a collision, and measured back at 8px the box entered
  Level_1's 8px shaft from 0 of 33 approach positions (7.99 was no better, and
  `safe_margin` makes no difference: an exact fit is a hard stop). He stood on
  eight pixels of nothing instead. So `Player._tick_squeeze()` narrows his box
  to `squeeze_width` (6) **whenever he is standing over a slot** — no input, a
  hole in the floor takes you — puts him down the middle of it and drops him in.
  `squeeze_width` and `squeeze_probe` are ABSOLUTE and did not move when he did:
  what has to fit is the 8px shaft, which is 8px whatever he weighs.
  He goes back to full width by TRYING the wide box against the world every
  frame, so nothing has to notice him leaving, and he is a full cell everywhere
  else. **That try needs `recovery_as_collision`** — `test_move`'s fifth
  argument, off by default. Without it Godot depenetrates first and reports only
  what is left, so a box buried half a pixel in the brick either side comes back
  "clear": measured on Level_1's shaft the answer was not even monotonic (6 and 7
  fitted, 8 collided, 9 and 10 "fitted"). At exactly a cell he happened to ABUT
  rather than penetrate, so the squeeze held on a coincidence; at 9 he stood up
  on the lip, fell a tenth of a pixel, squeezed, stood up again, and rode that
  loop forever above the hole. **The shaft then wall-slides him without being asked**: dropping down
  the middle of a one-cell slot never touches either wall (a pixel of clearance
  each side), so `is_on_wall()` is false all the way down and the ordinary
  press-into-the-wall rule would free-fall him between two walls he is
  practically resting on. `tests/chimney_test.tscn` holds all of it.
  `_keep_footing()` also leaves him alone when there is ground on BOTH sides —
  that is bridging a slot, not overhanging a ledge, and the ledge slip used to
  shove him sideways off the hole.
  Interiors: 6 cells = claustrophobic, walkable min is a 2-cell (16px) slot;
  a 1-cell slot is a chimney to slide and wall-jump in, not a walkway.
  Jump reaches 34px (~4 cells), dash ~39px (~5), jump+dash ~85px (~10).
  **These are pixel figures first.** The grid halving did not move any of them,
  and a future grid change should not either — level geometry is built against
  the pixels, and the cell count is just how it reads on the current grid.
- Checkpoints are silent Area2Ds; death is instant respawn, no penalty.

