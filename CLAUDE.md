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
  - `Godot --headless --path . res://tests/level_v6_return_race_test.tscn` —
    dying anywhere in Level_v6 past its entrance does not bounce him back to
    Level_v5. It has no Checkpoint of its own, so every death in it respawns
    him at the same PlayerStart the return door hangs off, which overlaps the
    return strip by a couple of pixels (see `backtrack_test.gd`'s note and
    `LdtkWorld._resolve_return_arming`) — walking clear of the strip once arms
    the door, and a LATER death then TELEPORTS him straight back inside it.
    `Area2D.overlaps_body()` reflects its MONITORING CACHE, which lags a
    teleport (a plain `global_position` assignment, not `move_and_slide`) by an
    extra physics step — measured, `body_entered` for a respawn landing back
    inside an already-armed strip fired on the THIRD physics frame after the
    teleport, one frame later than the two-frame wait `_resolve_return_arming`
    used to check it with, so that function read "clear" on stale
    information, armed the door, and then the real signal arrived a frame
    late and fired it. Fixed by checking a plain Rect2
    (`LdtkWorld._return_strip_rect`, against `Player.hitbox_rect()`) instead —
    nothing there depends on the physics server's own cache catching up
  - `Godot --headless --path . res://tests/intro_test.tscn` — Act I's beats:
    dialogue order, dashless start, room 1 grants nothing, room 2 grants dash
  - `Godot --headless --path . res://tests/screen_test.tscn` — UI and world stay
    on separate render surfaces (restyling dialogue can't touch the game), and
    the world's own SubViewport samples NEAREST — a SubViewport built in code
    does NOT inherit the project's `default_texture_filter=0` setting (that
    only seeds the ROOT viewport); every SubViewport starts on the ENGINE's
    hardcoded Linear default regardless, silently. This shipped once: the
    WHOLE GAME rasterised soft instead of crisp — not one prop, everything
    inside `Screen.viewport` — and nothing errored or warned. Found by
    sampling actual rendered pixels (a screenshot's own nearest-neighbour
    upscale on the way to disk, in `room_shot.gd` and elsewhere, cannot
    un-blend pixels that were already blended before it ran)
  - `Godot --headless --path . res://tests/lemon_test.tscn` — collectibles:
    pickup, and the total surviving level changes and death. Also covers the
    strawberry rule's ground check: a CrumblingPlatform reads as floor for
    movement but not as the SOLID ground `Player.is_on_solid_ground()` asks
    for, so a fruit armed above one stays pending until it gives way and he
    reaches the real floor below
  - `Godot --headless --path . res://tests/lemon_glow_test.tscn` — the 'z'
    ability: spend one lemon for `lemon_glow_time` seconds of light on its
    OWN node, LemonGlowLight, rather than the Glow group's GlowLight (that
    one is NoteSequence's reward and it revokes on every room change in the
    whole game — sharing it would snuff out a lemon you just spent the
    moment you walk through any door). Pressing again while already lit
    spends nothing. Blinks a warning through the last `lemon_glow_flicker_time`
    seconds, off a square wave driven by the timer itself rather than an
    accumulating clock, so it can be set directly and checked without ticking
    through real seconds. Dying cuts it immediately and does not refund the
    lemon
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
  - `Godot --headless --path . res://tests/jump_tutorial_test.tscn` — Level_1's
    jump lesson: the prompt appears after `arm_distance` and not before,
    FOLLOWS him rather than pinning him (unlike DashTutorial, nothing here
    takes his controls), starts on the keyboard art and swaps live to the
    controller art on a real joypad button — and back on a real keypress —
    clears on an actual jump and not from anything else, and a death in the
    room re-arms it measured from where he stands back up, not where he died
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
  - `Godot --headless --path . res://tests/thought_tiles_test.tscn` — paintable
    thought-hazard tiles: the ThoughtHazards IntGrid layer imports as a
    pass-through TileMapLayer (collision disabled), the world caches it on room
    entry, an empty cell is not a hazard, a painted cell IS, and stepping into
    one kills the player on the next physics tick. **Also covers the per-cell
    animation**: a painted cell actually cycles frames over time, two painted
    cells read DIFFERENT frames at the same tick (decorrelated, not one shared
    clock), and the same layout reproduces the same frame sequence on a fresh
    scan (hashed from the cell coordinate, not RNG)
  - `Godot --headless --path . res://tests/wall_slide_test.tscn` — a wall on
    only ONE side must never read as a wall-slide on the other: falling next
    to a lone wall always slides on the side it is actually on with
    `is_on_wall()` genuinely true throughout, and holding away from the only
    wall present never enters WALL_SLIDE at all. **Also covers the
    squeeze/chimney entry specifically**, which is what was actually broken
    and reported from play in Level_1: a one-cell shaft mouth that is
    two-sided for only a few pixels (a stair tread's lip ending right where a
    real wall keeps going) used to lock `wall_dir` onto the side about to
    vanish — `_near_wall_dir()` short-circuits on whichever side it checks
    first, which is the right question for its OTHER caller (the wall-jump
    buffer's "is there a wall on either side") and the wrong one here — and
    then drag him sideways into open air toward it, because the squeeze
    continuation check deliberately skips `is_on_wall()` (a genuine chimney
    has ~1px of clearance either side and is never actually touching, see
    `chimney_test.tscn`) so nothing caught the wrong side once it was locked
    in. Fixed by `_walled_both_sides()` — checks BOTH sides, no
    short-circuit — replacing `_near_wall_dir()` for the squeeze path, and by
    no longer nudging him wall-ward at all while squeezing, since a chimney
    already centres him with nothing pulling him off it
  - `Godot --headless --path . res://tests/voice_blip_test.tscn` — the
    Celeste-style dialogue VOICE: synthesized syllable blips (see
    `tools/gen_voice_blips.py`, `systems/voice_blips.gd`) retriggered as the
    typewriter reveals each character. Covers the manifest loading off
    res://, blips firing only while a page with a portrait is actually
    revealing (silence for system text with no portrait, silence during a
    `[p]` pause hold, silence between pages waiting on a press), a page
    completing playing one ENDING-tier blip, "emphasized" never landing
    twice in a row (a structural guarantee from `_last_tier_emphasized`, not
    a probabilistic check), a pool never repeating the same clip twice in a
    row, and switching portrait state mid-conversation switching which
    key's pool gets used — driven by `box._process(delta)` called directly
    with a synthetic delta, the same by-hand trick `thought_tiles_test.gd`
    and `portrait_anim_test.gd` use, and for the same reason: idle-process
    delta has no fixed relationship to wall-clock frames in a headless run
  - `Godot --headless --path . res://tests/mystery_box_test.tscn` — the
    Mario-style "?" block: solid always, and a bump only counts when the hit
    is genuinely UPWARD (`velocity.y < 0`) — resting or drifting against the
    underside does nothing. The sensor that detects it stands PROUD a few
    pixels below the solid box's own underside (mystery_box.gd's own note
    explains why: it has to see him before the solid collision has a chance
    to zero his velocity, the same problem CrumblingPlatform's skin solves
    from the other side). One mushroom per life of the box; both come back
    together on `reset_all`. The mushroom itself: rises straight out with no
    gravity, then drops into walking right with gravity on, reversing off a
    wall and simply falling off a ledge rather than avoiding one. And the
    power an eaten one grants: 30s of thought-hazard immunity — a dark/light
    cloud is passed through and every one of them has its warning glow
    suppressed WORLD-WIDE the instant it is eaten (not per touch), a grey one
    dissolves out of the room on contact instead of killing (and comes back
    on the same `reset_all` sweep), and the paintable `ThoughtHazards` tiles
    stop killing too. A death cuts the power immediately, same as the lemon
    glow.
- If the editor is open, headless `--import` may stall — retry once, or close
  the editor. Never kill the user's `--editor` process.
- **Editing `scripts/ldtk_entities_post_import.gd` does not re-import the
  world.** Godot re-imports a `.ldtk` when the `.ldtk` changes, not when the
  hook that builds its entities changes — so a newly handled (or renamed)
  entity stays raw data in `ldtk/levels/*.scn` and simply never appears, with
  no error anywhere. `touch ldtk/hooshang_act1.ldtk` then `--import`.
- **Level identifiers ARE the play order**, and `LdtkWorld.rooms` is sorted by
  them. `Level_0` is the opening room. The world is no longer one left-to-right
  row: rooms 14-23 are the escape and run RIGHT to left along the bottom of the
  grid, retracing rooms 11-3 (room N pairs with room 26-N). Sorting by world
  position — which this used to do — reads that row backwards, and every "next
  room" fallback then hands you the room you just left. Renumber when you insert
  a room, and re-letter that room's lights with it (`LIGHTING.md`).
  **This is not cosmetic.** No Exit in the `.ldtk` carries a NextRoom
  override — checked directly, every one is empty — so `LdtkWorld.rooms`'s
  array order is not just how the debug picker numbers things, it is the ONLY
  thing that routes actual play from one room to the next. A handful of rooms
  (`Level_V1`..`Level_V4`, `Level_v5`, `Level_v6`) carry no number of their own
  but do have a real place in the sequence, between `Level_6` and `Level_7` —
  `tools/renumber_levels_v2.py`'s block, extended since. Trailing-digit sorting
  cannot place those on its own (`Level_V1` shares its digit with `Level_1`,
  which is exactly the bug this note used to be about: they interleaved one per
  numbered room instead of landing together, and the walk from `Level_0` dead-
  ended at `Level_v6` with rooms 7-25 unreachable). They are pinned by hand in
  `LdtkWorld.INSERTED_ROOMS` instead — read that table's own comment, and add to
  it rather than trusting a new room's digits, before assuming a fifth one will
  sort itself into place.
- **A renamed level needs the import CACHE cleared, not just a re-import.**
  Deleting `ldtk/levels/*.scn` is not enough — the world scene itself is cached
  in `.godot/imported/hooshang_act1.ldtk-*`, and a stale one loaded two rooms
  on top of each other at the same world x while every name looked right.
  `rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/Level_*.scn` then
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
  `force_tileset_reimport=true` is also set in `hooshang_act1.ldtk.import` as
  a second line of defence; nothing is lost by rebuilding the TileSet, because
  the per-tile collision this project needs is re-applied on every import by
  `scripts/ldtk_tileset_post_import.gd`.
- **A running Godot EDITOR re-imports with the state it started with.** It
  re-imported the world seconds after an import flag was set and dropped the new
  tiles right back out, which looked exactly like the fix not working; a newly
  handled ENTITY goes the same way, arriving as nothing while the hook that
  builds it plainly has a case for it. Restart the editor after changing
  anything in a `.import` OR in a post-import hook, and rebuild:
  `rm .godot/imported/hooshang_act1.ldtk-* ldtk/levels/Level_*.scn` then
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
- **Keep LDtk closed while editing `hooshang_act1.ldtk` from code.** LDtk
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

**Act 2's watercolor convention — every new Act 2 GAMEPLAY entity (tileset,
hazards, props) must follow this, not just look "warm and Persian."** Settled
by `experiments/act2_watercolor/README.md`'s own side-by-side test: a heavy-
bleed watercolor generation is gorgeous at concept resolution and turns to mud
the moment it is reduced to this project's actual 8px-tile / small-prop scale
— soft edges either survive as blurry smears or flatten into banding, neither
of which still reads as "watercolor" once small, it just reads as noisy. The
**pulled-back** direction (watercolor-influenced gradient shading, but crisp
pixel edges and restrained bleed) is the one that survives reduction, and is
this project's standing rule for anything gameplay-critical, tiled, or reduced
small — which is every entity, prop, and tile sheet. The reverse case — a
one-off, non-tiled, native-resolution SET-PIECE backdrop that is never
squeezed onto the 8px grid at all (the same exemption `SunShaft`/`WallPattern`
already carry, and the recipe Act 2's own sky backdrop follows, see
`tools/gen_act2_sky_backdrop.py`) — is the ONLY place heavy bleed is fair
game, because nothing there forces a harsh reduction to fight.

**The established pipeline** (worked example: `tools/gen_act2_tileset_8px.py`;
also `gen_act2_thought.py`, `gen_act2_thought_tiles.py`, `gen_act2_cone_spikes.py`,
`gen_spring_platform.py`, `gen_magic_carpet.py`, `gen_key.py`,
`gen_jamshid_cage.py` — every existing Act 2 entity generator follows it
already, so copy the pattern from whichever is closest to what you're adding):

1. Generate a Pixellab source SWATCH (`create_image_pixflux`), explicitly
   asking for the **pulled-back** language, not hard bleed — e.g. "detailed
   pixel art with watercolor-influenced soft gradient shading, clean crisp
   pixel edges, restrained painterly bleed, not flat 8-bit NES retro," plus
   Persian-ornament framing where relevant ("Persian miniature painting
   flat-perspective linework," "khatam marquetry") and the warm palette
   language ("ochre gold turquoise and terracotta" / "cobalt and rose"). Save
   it under that asset's own `.../source/<name>.png`, matching every other
   Pixellab-sourced asset in this project.
2. **Geometry/shape code stays 100% procedural and untouched.** Never crop or
   reduce a Pixellab bitmap into the final small art directly — the same
   lesson `gen_cone_spikes.py`'s own header already recorded for Act 1 (a
   downsampled photo/generation cannot hold a 1px spike apex, a seamless
   brick joint, or a static six-frame contour); only the COLOUR RAMP comes
   from Pixellab, the drawing logic (coursing, taper, motif shapes) is the
   same hand-written PIL it always was.
3. Pull the palette from the source with a small `_ramp_from_source(path, n)`
   helper (copy it from any of the files above — it reads the PNG back,
   counts its most-common opaque colours, and sorts them by luminance),
   rather than hand-picking hex values. This is what makes the art
   reproducible: re-running the script re-reads the same source and rebuilds
   the same ramp. An accent colour the frequency ranking misses (a trim fleck
   that never ranks in the top stops) is picked out by a hue filter instead
   of by rank — see `gen_act2_tileset_8px.py`'s `_TEAL` for the pattern.
4. Keep every existing output path, pixel dimension, and frame/tile layout
   contract EXACTLY as the entity's consuming Godot script or LDtk auto-rule
   already expects (fill/top/left/corner tile order, frame counts, etc.) —
   this pass changes colour only, never the mechanical contract.

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
  **Jump is 'c' only now** — 'z' used to be a second jump key (and the key the
  dialogue box/pause menu/main menu all read as "confirm", since they check the
  `jump` action rather than a raw keycode) but is now its own `glow` action: the
  lemon-glow ability below. A controller still has two ways to jump (button 0
  and the stick's own jump binding are untouched); it is specifically the
  SECOND keyboard key that moved.
  **The lemon glow (`glow` action, 'z') is its own node, LemonGlowLight, not
  the Glow group's GlowLight.** That one belongs to NoteSequence (the musical-
  tile puzzle's reward) and NoteSequence revokes it on every room change in the
  whole game, not just leaving its own room (`note_sequence.gd`) — sharing it
  would mean walking through any door snuffs out a lemon you just spent.
  `_try_lemon_glow()` spends one lemon (`Collectibles.spend()`) for
  `lemon_glow_time` seconds, ignored while one is already running rather than
  refreshing it. The last `lemon_glow_flicker_time` seconds blink as a warning,
  off a square wave read straight from the countdown (`_apply_lemon_glow()`)
  rather than an accumulating clock, so a test can set the timer directly. Dying
  snaps it off immediately and does not refund the lemon — same as every other
  run stat a death does not undo.
  **LemonGlowLight is a Sprite2D, not a Light2D — it SHIPPED as a PointLight2D
  and was wrong.** A real light MULTIPLIES the surface it falls on, so it
  visibly brightened an unlit stretch of room and did almost nothing crossing
  an already-lit patch near a lamp or ceiling panel, which played back as "the
  player only glows in shadow" rather than a steady glow that follows him
  everywhere — the same trap DarkThought's halo documents, plus it was
  competing for this renderer's per-canvas-item light cap (16) in rooms already
  busy with fixtures. `_apply_lemon_glow()` now builds it as unshaded and
  additively blended, same recipe as that halo: adds flat instead of
  multiplying, so it reads the same regardless of what is already lit beneath
  it, is exempt from the light cap, and cannot be crushed by CanvasModulate
  0.05 either. Flicker is now `.visible` on/off rather than an energy of 0;
  brightness lives in `.modulate`, scaled down by the same `PAINT_GAIN` (0.35,
  office-brick albedo) that halo uses, since paint at equal energy lands
  roughly 1/albedo too bright next to the light it replaced.
- `scripts/level_base.gd` — `LevelBase`: camera limits, checkpoint group wiring,
  kill plane (`kill_y`), fast respawn (~0.15s), R = retry, and exit wiring — any
  Area2D in the `exit` group advances the game (see below). Levels `extends
  LevelBase`. Nothing currently does — the pre-LDtk hand-built levels that once
  did (`Level1Office`, `Level2`) were retired once the real content moved into
  the LDtk world, and `Game.LEVELS` (below) is empty as a result.
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
  `spend(amount)` is the other direction — Player's lemon-glow ability pays with
  it — and fails (returns false, changes nothing) rather than letting `total` go
  negative; unlike a pickup there is nothing in flight, so the shown number
  drops immediately instead of trailing `total`.
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
- `systems/input_device.gd` — `InputDevice` autoload: which kind of input he
  was last seen using, keyboard/mouse or a controller. Godot has no "which
  device is active" query, only events, so this just watches every one that
  arrives via `_input()` and remembers the last KIND — a joypad BUTTON or a
  stick past `AXIS_DEADZONE`, not every axis event, since those fire
  continuously at rest with centering noise that would flap the reading back
  and forth for no reason. Exists for on-screen prompts that have to show a
  keyboard key on a keyboard and a controller button on a pad; first (and so
  far only) user is `JumpTutorial`.
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
  transitions, for `LevelBase`-derived scenes. `Game.LEVELS` is the ordered
  scene list — currently EMPTY, since the two scenes it ever chained
  (`Level1Office`, `Level2`) were retired once the LDtk world became the real
  Act 1. `current_index`/`completed` still live here rather than being deleted
  outright, because `SaveGame` persists them as part of a save's schema (see
  below) — advance()/set_current() are otherwise dead code with nothing left
  to call them.
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
- `systems/voice_blips.gd` — the `VoiceBlips` autoload: Celeste-style dialogue
  VOICE. Not recorded speech — short syllables synthesized by
  `tools/gen_voice_blips.py` (pure stdlib formant synthesis, deterministic,
  same recipe as `gen_note_audio.py`), banked per speaker+portrait-STATE and
  per TIER (`passing` most of the time, rarer `emphasized`, one `ending` per
  page) under `assets/voice/<speaker>/<state>/`, indexed by
  `assets/voice/manifest.json` (loaded as a `Resource`, same reasoning as
  `DialogueBox._load_rigs()` — missing/corrupt manifest is silence
  everywhere, not a crash). `DialogueBox` retriggers `VoiceBlips.blip(key,
  tier)` once per newly revealed, non-whitespace character — see the VOICE
  note at the top of `dialogue_box.gd`. **`key` is the exact same string
  `_set_rig`/`_set_loop` already derive from the portrait texture's
  filename** ("hooshang_annoyed", "rumi_wistful", ...), so a beat that
  already names a state gets a voice for free and never has to know this
  exists. One shared, retriggered `AudioStreamPlayer` rather than a pool per
  speaker — this game only ever shows one speaker at a time. `blip()` never
  repeats the same clip twice in a row for the same `(key, tier)` pool (one
  retry, which is guaranteed to land elsewhere since it shifts the index by
  1 mod the pool size), and `DialogueBox` never rolls "emphasized" twice in a
  row either (`_last_tier_emphasized`) — both are the thread's own "no
  consecutive duplicate syllables, reduced emphasis" rules. See
  `voice_blip_test.tscn`.
  **Casting**: Hooshang is the SHARPER, less settled voice (brighter
  formants, a faster/thinner attack, more pronounced vibrato — a wavering
  pitch is what "unsure" sounds like without needing real words). Rumi is
  deliberately the opposite pole on every axis — a base register well below
  Hooshang's, checked so Rumi's brightest/highest state never reaches
  Hooshang's darkest/lowest one, darker formants, a slower/shallower vibrato,
  longer decay, and a quiet sub-octave layer (`sub` in `gen_voice_blips.py`'s
  `VOICES`) mixed in purely for chest weight — the "wise sage" register a
  plain low fundamental alone doesn't quite sell. See the module docstring's
  CASTING note for the full reasoning.
- `scripts/ldtk_world.gd` (`LdtkWorld`) also ducks that Act's background
  MUSIC while dialogue is on screen — `@export_group("Music")`'s
  `music_duck_db`/`music_duck_fade`, listening to `Dialogue`'s
  `dialogue_opened`/`dialogue_closed` signals rather than DialogueBox
  reaching into the world. **The fade is deliberately slow (0.35s) relative
  to how fast those signals actually fire**: `say()` closes and reopens the
  whole banner between every LINE of a conversation, not just between
  separate conversations, so a fade this long never fully recovers in the
  gap between one line's close and the next line's open — a multi-line
  exchange reads as one continuously ducked passage rather than the music
  flickering back up between lines. Ducking restores to whatever the
  `Music` child's own AUTHORED `volume_db` was (captured once in `_ready()`),
  not a hardcoded absolute, so a louder- or quieter-mixed Act's track still
  ducks by the same felt amount. A world with no `Music` child (a test world,
  say) simply never connects the signals — `_music` stays null and nothing
  fires.
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
  motion here is NUMBERS (`Motion`, `Amplitude`, `Speed`, `Phase`, `Clockwise`,
  `Angle`), two thoughts in one room can legitimately want different paths, and
  one whose mode nobody set still visibly drifts. **The placed point is the
  CENTRE of the path in all modes** — a CIRCLE orbits it rather than starting on
  it. `Motion` is `VERTICAL / HORIZONTAL / CIRCLE / LINEAR`; LINEAR swings along
  an arbitrary `Angle` (degrees, 0 = +X), and VERTICAL/HORIZONTAL are just LINEAR
  at 90/0 kept as their own values so every already-placed thought is unchanged.
  The
  red rim is DRAWN as well as lit: a `PointLight2D` alone is not enough against
  office walls already at 255 in the red channel, the case `LIGHTING.md` records
  for Rumi's gift. Anchored against `RoomCollapse` (it is floating, not resting),
  and `DarkThought.reset_all()` puts every one back on its placed point with its
  cycle at the start — called from both of `ldtk_world.gd`'s reset sites, beside
  `CrumblingPlatform.reset_all`. Art from `tools/gen_dark_thought.py`, the entity
  from `tools/ldtk_add_dark_thought.py`.
  `hazards/LightThought.tscn` and `hazards/GreyThought.tscn` are the SAME PROP in
  the other two tones — the same script, path, fields and kill box,
  `tone = LIGHT` / `tone = GREY` — and the three sheets are three palettes off one
  generator, so they cannot drift apart. Grey is the NEUTRAL feeling-tone beside
  the unpleasant (dark) and pleasant (light). Three LDtk entities rather than a
  Tone field purely so the editor SHOWS which you placed
  (`tools/ldtk_add_light_thought.py` and `tools/ldtk_add_grey_thought.py`, each
  building its definition from the DarkThought one and checking it key-for-key
  rather than transcribing the fieldDef shape again).
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
  `MysteryBox.tscn` is the Mario-style "?" block — bump it from underneath
  (jumping or dashing into its underside; see mystery_box.gd for exactly what
  counts as a hit) and `Mushroom.tscn` rises out of it and walks off to the
  right, gravity on, bouncing off a wall and falling off a ledge rather than
  avoiding one — Super Mario 3's beat. `MushroomType` (LDtk field, currently
  just `BlackWhite`) picks which power a given box hands out; a new colour is
  a new palette in `tools/gen_mushroom.py`, a new value in
  `Mushroom.MushroomType`, and a new branch in `_build_mystery_box` — three
  places, not a fourth. The block is SOLID always, even once spent — only the
  face changes — and comes back (unspent, idle face) on the same room-entry
  and respawn sweep as `CrumblingPlatform`/`DarkThought` (`reset_all`).
  **The black & white mushroom** grants 30s of thought-hazard immunity
  (`Player.has_thought_immunity()`) and sparkles him for the duration
  (`Juice.mushroom_sparkle_tick`, thinning out rather than blinking as it
  nears the end — the same warning job `lemon_glow_flicker_time` does with a
  blink instead). While it runs: a `DarkThought`/`LightThought` is passed
  through and EVERY one of them has its warning glow turned off WORLD-WIDE
  the instant the mushroom is eaten (`DarkThought.set_glow_suppressed`), not
  one cloud at a time as each is touched; a `GreyThought` dissolves out of the
  room on contact instead of killing him (and comes back on the same
  `reset_all` sweep as everything else with per-visit state); and the
  paintable `ThoughtHazards` tiles stop killing (`ldtk_world.gd`'s
  `_in_thought_tile` check). A death cuts the power immediately, the same way
  dying does not refund a spent lemon. See `mystery_box_test.tscn`.
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
  **Airtime used to be capped by Level 2's second gap**, a dash GATE — airtime
  times max_run_speed is horizontal reach, and past about +16% a plain running
  jump cleared a gap that existed to teach the dash. **And Level 2's THIRD gap
  capped it from below, much more tightly**: a 94px gap with a 2-tile rise,
  authored so only a near-perfect apex jump+dash cleared it — measured by
  bisection, `max_run_speed` 86 still cleared it and 82 did not, so roughly 5%
  was all the slowing that level tolerated. **This was all about the pre-LDtk
  greybox `Level2.tscn` (built by `tools/gen_level2.py`), which is now
  deleted** — the level and its `level2_test` regression check are both gone.
  Whether the LDtk world's own `Level_2` room (the current dash-teaching room,
  covered by `dash_tutorial_test`) carries an equally tight constraint on
  `max_run_speed`/`apex_gravity_mult` has NOT been re-measured — treat this
  whole note as historical until someone runs `feel_measure` against it and
  confirms one way or the other.
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
- `tools/gen_thought_tiles.py` — the ANIMATED 8px paintable hazard tiles: SIX
  frames × four tile types (fill, top edge, left edge, corner) on a 32×48 sheet.
  Contour SHAPES are static — what animates is a travelling brightness wave
  along the red rim, and (fill tiles only) a pair of dot eyes and a small oval
  mouth that fade in and back out across two of the six frames, giving the
  sludge mass a haunted, living quality. Auto-rules with flipX/flipY give all
  eight edge and corner variants from the four drawn tile types. Painted on
  the `ThoughtHazards` IntGrid layer; `tools/ldtk_add_thought_tiles.py` adds
  the layer, its tileset, and auto-rules to the LDtk project.
  **The six rows are NOT a Godot animation** — `ldtk_level_post_import.gd`
  disables collision on the layer (pass-through), sets `LIGHT_MODE_UNSHADED`
  via a `CanvasItemMaterial` (without it `CanvasModulate` 0.05 crushes the dark
  pixels to invisible, the same trap `DarkThought`, `SunShaft` and
  `WallPattern` all document), and attaches
  `scripts/ldtk_thought_hazard_layer.gd` (`ThoughtHazardLayer`) to the layer
  node — the same "script survives packing, a connection made at import time
  does not" rule `LdtkDoor`/`LdtkRumiTrigger` already use. Godot's own tile
  animation is ONE shared clock per atlas tile, so every painted cell would
  breathe and blink in lockstep — a room full of sludge pulsing as one grid
  rather than many small living things. `ThoughtHazardLayer` instead treats
  the six rows as six ordinary addressable tiles and drives every painted cell
  on its OWN clock, at its OWN speed (0.85–1.15x), started at its OWN phase —
  both HASHED from the cell's coordinate (not RNG: a room has to look the same
  way every time you walk into it, the same reason `DarkThought.reset_all()`
  exists), so two cells never coincidentally sync and the whole layout is
  reproducible run to run. `ldtk_world.gd` checks tile overlap each frame to
  kill the player, unrelated to which frame is currently drawn.
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
- `tools/gen_dark_thought.py` — the drifting clouds, ALL THREE tones, cut from
  one generated strip.
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
  It writes `dark_thought.png`, `light_thought.png` and `grey_thought.png` from
  ONE cut and ONE reduction, differing only in the body ramp (grey is the third,
  NEUTRAL feeling-tone between the unpleasant dark and the pleasant light) —
  verified in the same run: every rim pixel is byte-identical across all three
  sheets and 95%+ of body pixels differ between each pair. One script for all
  three tones, because separate scripts would let a retimed breath land in one
  and not the others, which is hazards that no longer read as the same object.
  (A wobbly-circle PROCEDURAL rewrite was tried and reverted — it read as
  blobs rather than clouds; this Pixellab-cut version is the one that ships.)
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
- `tools/gen_hooshang_portraits.py` — Hooshang's SECOND portrait pass, replacing
  the painted set above wholesale. Source art arrived differently from Rumi's:
  six JPEGs in `assets/portraits/hooshang/raw/`, each an 11-pose PixelLab
  contact sheet (4x3 grid + a text-label cell) for one state, rather than one
  raw generation per pose — so this script PICKS cells instead of patching
  frames, with the picks recorded in `POSES` (state -> source sheet, rest cell,
  talk cells, blink cell) rather than re-derived by eye on every run. Grid
  boundaries are measured per sheet from the grey gutter (a few px of JPEG
  drift between files), and each cropped cell goes through
  `gen_rumi_portraits.flood_background` to swap its cream backdrop for the
  office near-black — reused at a WIDER stability margin (`MAX_DRIFT` 0.02, not
  Rumi's 0.01), because these are JPEGs and even a clean cell carries enough
  compression noise to drift the fill share ~1-1.5 points with no actual leak;
  every cell this script uses was checked visually before that number was
  picked. **Three of six states ship with no blink** (skeptical, vulnerable,
  shocked) — none of their sheets ever draw the eyes fully shut, and forcing a
  squinty cell into the slot would make `gen_portrait_loops.py`'s own
  edge-energy check report a blink that isn't one, same as `rumi_urgent` today.
  **No cell with a hand in frame was used** — a hand that exists in only one
  loop frame would flicker in and out every time the state starts or stops
  talking, so the skeptical sheet's best-acted pose (chin-stroke) was left out
  for exactly that reason; its second talk frame instead reuses the rest cell,
  a plain open/shut mouth-flap. **This art's eyes sit lower than the default
  EYE band assumes**: checked by finding the sclera row-by-row, they cluster at
  y 112-127 across all six rest frames against the default's y 40-68 (tuned for
  the painted set, and effectively sitting on this art's hairline) — so every
  entry is written with its own `eye: [100, 140, 70, 196]`. **The `normal`
  sheet fills the `hesitant` slot, not a new state**: five of the six delivered
  files name existing states exactly (dazed/skeptical/annoyed/vulnerable/
  shocked); `normal` is the only leftover with no match, and `hesitant` is the
  only existing state with no new art, so one fills the other rather than
  hesitant staying painted while its five siblings switch styles. The FACES key
  is still `"hesitant"` — only the art moved.
  Re-run after replacing any raw sheet, then re-run `gen_portrait_loops.py`.
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
- `tools/gen_voice_blips.py` — the dialogue voice blips ->
  `assets/voice/<speaker>/<state>/*.wav` + `assets/voice/manifest.json` (see
  `systems/voice_blips.gd`). Pure stdlib (`wave`/`struct`/`math`/`random`, no
  numpy), matching `gen_note_audio.py`'s recipe. Every clip's RNG is seeded
  from the string `"<speaker>:<state>:<tier>:<index>"`, so re-running
  regenerates byte-identical files — checked directly (a hash diff on every
  `.wav`) before this shipped. Additive harmonic synthesis rather than a real
  formant filter: each harmonic of a per-clip-jittered `f0` is boosted by a
  Gaussian bump wherever it lands near one of two formant centres, which are
  themselves interpolated between a DARK/closed vowel pair and a BRIGHT/open
  one by each STATE's own `brightness` — that interpolation is what gives
  `hooshang_shocked` a different vowel colour than `hooshang_vulnerable`
  rather than every clip being the same bell tone at a different pitch (which
  is what this borrows its envelope shape from). STATE NAMES ARE NOT
  INVENTED HERE: they are exactly `scripts/act1_beats.gd`'s `FACES` /
  `RUMI_FACES` keys (minus the aliases that point at another state's
  painting), so a state that already has a portrait gets a voice for free.

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
- **Revealed text fades in, and a line may carry BBCode emphasis.** `TextLabel`
  is a `RichTextLabel` (`bbcode_enabled`), not a plain `Label`: every reveal
  frame rewraps the page in a `[fade start length]` tag whose window trails
  just behind `visible_characters`, so a freshly-typed run of characters ramps
  up from transparent instead of popping in solid — see
  `DialogueBox._apply_page_text`. A line handed to `say()` may also embed
  Godot's own built-in effect tags directly — `[shake]word[/shake]`,
  `[wave]...[/wave]`, `[color=#ffd16b]word[/color]`, `[pulse]word[/pulse]` —
  for a handful of the most dramatic beats (see the Act I ending in
  `act1_beats.gd`'s `_play_chase_end` for worked examples). **Tags must stay
  bare or `=value`, never `[tag attr=1 attr=2]`** — pagination's word-wrap
  fallback can land a page break on any space in the line, and a tag with an
  internal space is one token by convention but would still corrupt if a break
  landed between its attributes. Pagination, the `[p]` breath mark, and the
  voice blips all still index against the PLAIN rendered text
  (`DialogueBox._strip_tags`), never the raw BBCode source — see that method's
  doc for why a tag ahead of a `[p]` would otherwise shift the breath.
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

