class_name LdtkWorld
extends Node2D
## Celeste-style room manager for an LDtk world (see STYLE_GUIDE.md §9).
##
## An LDtk project is imported as ONE scene whose children are the levels,
## already positioned at their world coordinates. Those are the "rooms". This
## keeps every room loaded and alive at once, so moving between them costs no
## scene load and no fade — a transition is just the camera moving and the
## active room's bounds changing. That is how Celeste actually works, and it is
## why this exists instead of Game.advance() (which fades to black and calls
## change_scene_to_file — fine for Act -> Act, impossible to make seamless).
##
## Responsibilities, all keyed off the CURRENT room:
##   - camera limits clamp to the room's rect
##   - the kill plane sits below the room's floor
##   - death respawns at the room's PlayerStart (or its last checkpoint)
##   - touching an Exit slides the camera to the next room, and hangs a return
##     door on the edge you came in through so the Exit works BOTH ways
##
## Room order is play order — see rooms_in() below — which an Exit's NextRoom
## field can override for a non-linear jump. None currently has one set: every
## transition in the game runs on rooms_in()'s array order alone, which is why
## that ordering has to be exactly right rather than just close.

signal room_changed(room: Node2D)
## Fired the instant a room slide BEGINS, carrying the room being entered — so
## anything gated on "which room is live" (the moon and its floor pool, see
## MoonVisibility) can wake the destination up as it scrolls IN rather than a
## beat after the slide lands. room_changed still fires at the slide's END, once
## the player has fully arrived; nothing that resets a room's state (hazards,
## doors, checkpoint) may move to this earlier edge.
signal transition_started(target: Node2D)

## The imported .ldtk world (its children are the rooms).
@export var world_scene: PackedScene
@export var player_scene: PackedScene = preload("res://scenes/characters/hooshang/Hooshang.tscn")

@export_group("Lighting")
## Flat back-wall panel drawn behind each room so 2D lights have a SURFACE to
## fall on. Without it a room whose LDtk `Background` layer is empty shows the
## bare viewport clear colour, which is not a CanvasItem — no light and no
## CanvasModulate can touch it, so the room stays flat grey no matter how the
## lighting is tuned. Painting real wall tiles on the LDtk `Background` layer
## supersedes this; turn it off then.
@export var draw_room_backdrops := true
## Base colour of that panel, BEFORE the level's CanvasModulate darkens it —
## so pick something fairly bright here and let the modulate do the dimming.
## Only used as a FALLBACK, when room_backdrop_texture is unset — see it below.
@export var room_backdrop_color := Color(0.42, 0.3, 0.27)
## Art for that panel, stretched to fill each room's own rect — Act I's dim,
## desaturated office wash (assets/background/office_gradient_backdrop.png).
## Takes over from room_backdrop_color whenever it is set (the default): a
## painted gradient reads as atmosphere, a flat tint under it would only mud
## the colours the art was already mixed with. Downsized from a 2048px source
## (sips -z 512 512) — the gradient carries no fine detail to lose, and this
## project's other backdrop art is sized the same way (night_sky.png is
## 320x160). Kept at LINEAR filtering rather than the world viewport's default
## NEAREST — see _add_backdrop's own note, the same reasoning DialogueBox's
## Portrait node documents for a painted image over pixel art.
@export var room_backdrop_texture: Texture2D = \
	preload("res://assets/background/office_gradient_backdrop.png")
## CanvasModulate colour for a room holding a musical-tile puzzle (NoteTile,
## group "note_tile" — see scenes/props/NoteTile.tscn): those rooms show
## nothing but their own hand-placed Light2D fixtures, no ambient fill at all.
## Every other room gets whatever colour the world's own CanvasModulate node
## was AUTHORED at (captured into _ambient_color below, once, in _ready() —
## the same "capture the authored value" move _music_base_db makes for the
## Music node) — so this script carries no opinion of its own on what "dim"
## means, and Act II's CanvasModulate (a different mood entirely) is
## untouched by this file simply because Act II has no note tiles to match.
@export var music_room_color := Color.BLACK
## Room-specific pixel art, keyed by exact LDtk identifier.
@export var room_backdrop_overrides: Dictionary[String, Texture2D] = {}
## Per-wall reflectance, without retuning fixtures or tinting child windows.
@export var room_backdrop_tints: Dictionary[String, Color] = {}
## Background art brightness; lower values separate the player from scenery.
@export_range(0.0, 1.0, 0.05) var background_brightness := 1.0
## Pixel rectangles around every painted moon in a room-specific texture.
@export var room_moon_regions: Dictionary[String, Array] = {}
const OFFICE_MOON := preload("res://scenes/props/backdrop/office_moon/OfficeMoon.tscn")
@onready var _canvas_modulate: CanvasModulate = $CanvasModulate
var _ambient_color := Color.BLACK

@export_group("Bounds")
## Cap every room with an invisible ceiling sitting just above its top edge.
##
## A room is only meant to be left through an Exit or a Door, but nothing was
## stopping a jump + up-dash from leaving through the TOP. Level_4's ceiling row
## is unpainted above the ledge that holds its Exit, and a measured jump-dash
## from that ledge peaks 44px above the room — the camera stays clamped to the
## room, so the player simply vanishes off the top of the screen before falling
## back in ("flies to the ceiling"). Sealing it HERE rather than painting the
## missing tiles in LDtk gives every room ever authored the same guarantee, and
## costs no playable space: the cap lives entirely outside the room rect, and
## rooms sit side by side, so it can never intrude on a neighbour.
##
## The FLOOR is deliberately left open — falling out the bottom of a room is
## what the kill plane below is for.
@export var seal_room_ceilings := true
## How thick that cap is. Must comfortably exceed the distance a dash covers in
## one physics frame (260 px/s at 60fps = 4.4px) so nothing can tunnel through.
@export var ceiling_thickness := 16.0

@export_group("Transition")
## How long the camera takes to slide from the old room to the new one.
@export var slide_time := 0.55
## Coming BACK into a room, how far to the approach side of its Exit the player
## is placed. Must clear the Exit's own trigger box (16px wide) or you would
## re-enter it on arrival and be bounced straight forward again.
@export var back_entry_offset := 20.0
## Falling this far below a room's bottom edge kills the player.
@export var kill_margin := 24.0
## Delay between death and respawn. Kept tiny for a Celeste-fast retry loop.
@export var respawn_delay := 0.15

@export_group("Music")
## How far background music ducks while a dialogue line is on screen, in dB
## below whatever the Music node was authored at (so this is a RELATIVE drop,
## not an absolute volume — an Act that authors its track quieter or louder
## still ducks by the same felt amount). Listens to Dialogue's own
## dialogue_opened/dialogue_closed rather than reaching into DialogueBox, so
## it costs this world nothing to add a line anywhere.
@export var music_duck_db := 14.0
## Fade time each way. Generous on purpose: say() closes and reopens the
## banner between every LINE of a conversation (not just between separate
## conversations), and a fade this long never fully recovers in that gap — so
## a multi-line exchange reads as one continuous duck rather than the music
## flickering back up between lines. See _duck_music/_unduck_music.
@export var music_duck_fade := 0.35
## The Music node's own AUTHORED volume — captured once, so ducking always
## returns to whatever THIS world's track was actually mixed at rather than a
## hardcoded assumption. Missing "Music" child (a world with no track, or a
## test world) is not an error: _music simply stays null and both handlers
## below no-op.
@onready var _music: AudioStreamPlayer = $Music if has_node("Music") else null
var _music_base_db := 0.0
var _music_tween: Tween

## Name of the room to open in, instead of the first one.
##
## Named for the debug picker, which is what first needed it, but it is now the
## project's ONE answer to "which room does this world open in": the picker drops
## straight into a room without playing up to it, SaveGame.resume() names the room
## a slot left off in, the level select names the room being replayed, and the
## tests name the room under test. A static var survives a scene load (it lives on
## the class, not the instance), which is exactly why a caller can set it and then
## load the world.
##
## Callers should ALWAYS set it — "" for a normal run — since a stale value would
## otherwise carry into the next launch.
static var debug_start_room := ""

var player: Player
var current_room: Node2D
## The room a slide is currently travelling INTO, or null when not sliding.
## current_room only advances at the slide's END (a death mid-slide must respawn
## in the room you left), but the destination is already on screen and already
## holds the player the whole way across — so "which room is visually live" is
## current_room OR this. See is_room_active() and MoonVisibility.
var transition_target: Node2D
var rooms: Array[Node2D] = []

var _world: Node2D
var _transitioning := false
var _checkpoint := Vector2.ZERO
var _slide_tween: Tween

# The Exit is a two-way door. Going forward drops an invisible return door at
# the spot you arrive on; walking back into it takes you to the previous room,
# beside ITS Exit. It has to ARM first (you start standing in it, so it only
# becomes live once you have stepped off) or you would bounce straight back.
var _return_zone: Area2D
var _return_room: Node2D
var _return_pos := Vector2.ZERO
var _return_armed := false

# The current room's paintable thought-hazard TileMapLayer (null if the room has
# none painted). Cached on room entry so the per-frame overlap check is cheap.
var _thought_layer: TileMapLayer

# The current room's paintable Water TileMapLayer (null if the room has none
# painted) — same caching reason as _thought_layer above. This is the
# tile-painted counterpart to a placed Pond entity; both end up calling the
# same Player.enter_swim()/exit_swim(), this world node standing in as the
# "zone" token for the tile-based path since there is no per-instance node to
# use instead (see _in_water_tile()).
var _water_layer: TileMapLayer

# Rooms whose way back the story has re-pointed: room name -> the room walking
# back out of it actually leads to. See set_way_back().
var _way_back := {}


func _enter_tree() -> void:
	_drop_editor_preview()


func _ready() -> void:
	_ambient_color = _canvas_modulate.color
	_world = world_scene.instantiate()
	add_child(_world)

	rooms = rooms_in(_world)
	_scatter_moss()

	if draw_room_backdrops:
		for room in rooms:
			_add_backdrop(room)
	for room in rooms:
		for background_name in ["RoomBackdrop", "BG Image", "Background"]:
			var background := room.get_node_or_null(background_name) as CanvasItem
			if background != null:
				background.modulate *= Color(background_brightness, background_brightness, background_brightness, 1.0)
	if seal_room_ceilings:
		for room in rooms:
			_add_ceiling(room)

	player = player_scene.instantiate()
	add_child(player)
	player.died.connect(_on_player_died)
	_build_return_zone()

	for ex in get_tree().get_nodes_in_group("exit"):
		ex.body_entered.connect(_on_exit_reached.bind(ex))
	for d in get_tree().get_nodes_in_group("story_door"):
		if d is LdtkDoor:
			d.walked_through.connect(_on_door_walked.bind(d))
	for cp in get_tree().get_nodes_in_group("checkpoint"):
		cp.activated.connect(_on_checkpoint_activated)
	if _music != null:
		_music_base_db = _music.volume_db
		Dialogue.dialogue_opened.connect(_duck_music)
		Dialogue.dialogue_closed.connect(_unduck_music)

	if rooms.is_empty():
		push_error("LdtkWorld: the world scene has no rooms.")
		return
	_clamp_exit_signs()
	_restore_state()
	_enter_room(_start_room(), true)
	# A room's return door is normally armed by _arm_return() as a SIDE EFFECT of
	# walking into it — _slide_to_room calls it after a forward Exit, and
	# _on_return_entered calls it after backtracking. Starting the world already
	# IN a room (debug picker, "open as a finished player") skips both, so a
	# restored way_back re-route is never wired to anything a player can walk
	# into. That is invisible for every ordinary room — no Exit means no forward
	# progress either way, so "no return door" reads as "look but don't touch,"
	# exactly what a debug picker promises. It is NOT invisible for the boss
	# room: Level_14 carries no Exit at all, its ONLY way onward is this door,
	# and a "finished" player dropped there with the re-route already in
	# `_way_back` would stand in a dead end with no way to reach Level_15 —
	# no bug in the re-route itself would ever be reachable to test.
	if _way_back.has(_start_room().name):
		_arm_return(_room_before(_start_room()))


# --- Moss scatter -------------------------------------------------------------
# Act 1's brick is one shared 8px tile, so a single tile can never look random:
# every wall cell is byte-identical. tools/gen_bricks_8px.py instead appends a
# set of MOSS VARIANT tiles (clean brick + a distinct clump each) after the eight
# base tiles, and this pass sprinkles them over the plain-fill cells keyed off
# ABSOLUTE cell position -- clustered into patches by value noise, heavier where a
# brick sits against the wall's exposed top or face -- so WHICH bricks are mossy,
# and how much, varies irregularly across the whole wall the way real growth does.
# It only rewrites a cell's atlas coordinates, so collision (and every test that
# reads which cells are filled) is untouched: a mossed brick is the same solid
# brick. Gated on the source actually having the variant tiles, which only Act 1's
# widened Bricks8px does -- Act 2/3 share the PNG but keep the 8-tile def, so they
# are skipped automatically.
const _MOSS_FILL_ATLAS := Vector2i(0, 0)
# Atlas X of the moss variants on the sheet, light -> heavy. Must match the order
# gen_bricks_8px.py appends them (columns 8..13).
const _MOSS_VARIANT_COLS: Array[int] = [8, 9, 10, 11, 12, 13]
const _MOSS_THRESHOLD := 0.60      # below this a cell stays clean brick
const _MOSS_PATCH_CELLS := 3.5     # value-noise wavelength -- rough patch size

func _scatter_moss() -> void:
	for room in rooms:
		var layer := room.get_node_or_null("Collisions") as TileMapLayer
		if layer != null and layer.tile_set != null:
			_scatter_moss_layer(layer)
			preload("res://scripts/scaffolding_variation.gd").apply(layer)


func _scatter_moss_layer(layer: TileMapLayer) -> void:
	# Snapshot the ORIGINAL tiles first, so every decision reads the wall as
	# imported rather than one we have already half-mossed this pass.
	var cells := layer.get_used_cells()
	var atlas := {}
	var srcs := {}
	for c in cells:
		atlas[c] = layer.get_cell_atlas_coords(c)
		srcs[c] = layer.get_cell_source_id(c)
	for c in cells:
		var a: Vector2i = atlas[c]
		if a != _MOSS_FILL_ATLAS:
			continue
		var sid: int = srcs[c]
		var source := layer.tile_set.get_source(sid) as TileSetAtlasSource
		if source == null or not source.has_tile(Vector2i(_MOSS_VARIANT_COLS[0], 0)):
			continue                       # not Act 1's variant-bearing bricks
		var col := _moss_pick(c, atlas)
		if col >= 0:
			layer.set_cell(c, sid, Vector2i(col, 0))


## Clean (-1) or a moss variant's atlas X for a fill cell. Clustered growth,
## thicker against exposed tops and faces, with the exact variant jittered so a
## patch is a mix of stamps rather than one repeated.
func _moss_pick(cell: Vector2i, atlas: Dictionary) -> int:
	var region := _vnoise(cell.x, cell.y, _MOSS_PATCH_CELLS, 11)
	var fine := _hash01(cell.x, cell.y, 7)
	var amount := region * 0.85 + fine * 0.15
	if _surface_adjacent(cell, atlas):
		amount += 0.18                     # first course under a lip / against a face
	if amount < _MOSS_THRESHOLD:
		return -1
	var span := _MOSS_VARIANT_COLS.size()
	var idx := int((amount - _MOSS_THRESHOLD) / (1.30 - _MOSS_THRESHOLD) * span)
	idx = clampi(idx, 0, span - 1)
	idx = clampi(idx + (int(_hash(cell.x, cell.y, 3) % 3) - 1), 0, span - 1)
	return _MOSS_VARIANT_COLS[idx]


## True where a fill brick touches the wall's surface on top or a side -- an
## empty neighbour, or a lip/edge tile (anything that is not another plain fill).
## Moss creeps in from those, so they carry more of it.
func _surface_adjacent(cell: Vector2i, atlas: Dictionary) -> bool:
	var neighbours: Array[Vector2i] = [Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x - 1, cell.y), Vector2i(cell.x + 1, cell.y)]
	for n in neighbours:
		if not atlas.has(n):
			return true
		var a: Vector2i = atlas[n]
		if a != _MOSS_FILL_ATLAS:
			return true
	return false


## 0 .. 0x7FFFFFFF integer hash of a cell coordinate. Multipliers and masks keep
## every product inside 63 bits, so it is exact (no reliance on int overflow) and
## deterministic -- the same wall mosses identically every load.
func _hash(x: int, y: int, salt: int) -> int:
	var h := (x & 0xFFFF) * 73856093
	h ^= (y & 0xFFFF) * 19349663
	h ^= (salt & 0xFFFF) * 83492791
	h &= 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return h ^ (h >> 16)


func _hash01(x: int, y: int, salt: int) -> float:
	return _hash(x, y, salt) / float(0x7FFFFFFF)


## Smooth value noise: a hashed value per coarse lattice point, bilinearly and
## smoothstep-interpolated, so moss forms soft blobs a few cells across instead
## of salt-and-pepper speckle.
func _vnoise(cx: int, cy: int, scale: float, salt: int) -> float:
	var fx := cx / scale
	var fy := cy / scale
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := _smoothstep01(fx - float(x0))
	var ty := _smoothstep01(fy - float(y0))
	var top: float = lerp(_hash01(x0, y0, salt), _hash01(x0 + 1, y0, salt), tx)
	var bot: float = lerp(_hash01(x0, y0 + 1, salt), _hash01(x0 + 1, y0 + 1, salt), tx)
	var out: float = lerp(top, bot, ty)
	return out


func _smoothstep01(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## What this world contributes to a save slot (see systems/save_game.gd).
##
## Three things, and every one of them is invisible when it goes missing. The
## ROOM is what a slot is nominally about. `_way_back` is the Darkshang re-route
## and is the reason a save cannot be "which room" alone: lose it and the doorway
## out of the boss room silently points back at the room he already cleared,
## undoing a story beat in a save that otherwise looks perfect. `has_dash` is
## here because Hooshang.tscn ships with the dash ON and only the waking scene
## takes it away — so a load that says nothing about it gets whatever the prefab
## happened to have, which is "yes" no matter where the run actually was.
func save_state() -> Dictionary:
	return {
		"room": current_room.name if current_room != null else "",
		"way_back": _way_back.duplicate(),
		"has_dash": player != null and player.has_dash,
	}


## Take that state back, from whatever slot SaveGame has staged.
##
## PULLED here rather than pushed in from outside, because the two things being
## restored are created by this very _ready — there is no moment after the load
## when they exist and nothing has used them yet. Empty state (a new game, the
## debug picker, a test) restores nothing and leaves every default alone.
##
## Which room to open in is deliberately NOT read from here: that comes through
## `debug_start_room` like every other "start me there" in the project, so there
## is one answer rather than two that can disagree.
func _restore_state() -> void:
	var state := SaveGame.state_for("world_state")
	if state.is_empty():
		return
	var routes: Variant = state.get("way_back", {})
	if typeof(routes) == TYPE_DICTIONARY:
		for from in (routes as Dictionary):
			_way_back[str(from)] = str((routes as Dictionary)[from])
	if state.has("has_dash") and player != null:
		player.has_dash = bool(state["has_dash"])


## The rooms of an ALREADY INSTANTIATED LDtk world scene, in PLAY order.
##
## Play order is the LEVEL IDENTIFIER — `Level_0`, `Level_3`, `Level_4` — which
## is the rule the whole project already runs on (CLAUDE.md: "Level identifiers
## ARE the play order"), and is why inserting a room means renumbering the ones
## after it.
##
## This used to sort by world POSITION, left to right then top to bottom. That
## agreed with the identifiers exactly as long as the world was one left-to-right
## row, and stopped the moment the escape row was added: rooms 12-21 run RIGHT to
## left across the bottom of the grid, so position order reads them 21, 20, 19 …
## 13, 12 — precisely backwards. Every fallback in this file is "the next room in
## this array", so walking out of Level_16's Exit sent you to Level_15, the room
## you had just come from.
##
## Position is kept as the tiebreak, so a room whose name carries no number (or
## two rooms sharing one) still lands somewhere stable rather than in whatever
## order the scene tree happened to hold them. A handful of rooms carry no
## number AT ALL but do have a real place in the sequence — see
## INSERTED_ROOMS below play_index(), and read its comment before assuming a
## trailing digit is enough to sort a new room correctly.
##
## Static, and taking the world as an argument, so the debug picker can list the
## rooms of a world without standing up a whole LdtkWorld (player, lights,
## backdrops, signal wiring) just to read four names — and so there is only one
## definition of the ordering for both to agree on.
static func rooms_in(world: Node) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for child in world.get_children():
		if child is Node2D and child.has_node("Entities"):
			if str(child.name) in SHELVED_ROOMS:
				continue  # on hold — out of the play route (see SHELVED_ROOMS)
			found.append(child)
	found.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var na := play_index(a)
		var nb := play_index(b)
		if na != nb:
			return na < nb
		if is_equal_approx(a.position.y, b.position.y):
			return a.position.x < b.position.x
		return a.position.y < b.position.y)
	return found


## Rooms with no number of their own but a curated place in the sequence
## anyway, inserted between two numbered rooms by hand rather than by anything
## derivable from their name. Keyed by identifier; value is [the numbered room
## they follow, their order among any others inserted at the same point].
##
## `Level_V1`..`Level_V7` all land between Level_6 and the escape row as one
## block — the current spine of the game is `Level_0`..`Level_6` then this V
## block then `Level_14`..`Level_25`, with `Level_7`..`Level_13` on hold (see
## SHELVED_ROOMS below). THIS TABLE IS THE ONLY PLACE THAT SAYS SO — the .ldtk's
## own Exit entities carry no NextRoom override for any of this (checked: every
## one is empty), so index_in_name() below is not just how the debug picker
## numbers things, it is the ONLY thing routing actual play through here. Get it
## wrong and the game does not misnumber a menu, it walks into a dead end: that
## is what an empty NextRoom chain plus the OLD digit-matching rule did — `V1`..
## `V7` all carry a non-digit after `Level_` and fall to index_in_name()'s
## sort-last bucket unless they are pinned here (which is exactly the state a
## rename to `Level_V6`/`Level_V7` left them in before this table was updated:
## routed 6->V1->V2->V3->V4, then a dead end, with V5/V6/V7 orphaned at the very
## end of the array). Add to this block rather than trusting a V-room's digits.
const INSERTED_ROOMS := {
	"Level_V1": [6, 0], "Level_V2": [6, 1], "Level_V3": [6, 2], "Level_V4": [6, 3],
	"Level_V5": [6, 4], "Level_V6": [6, 5], "Level_V7": [6, 6],
}

## Rooms taken OUT of the play route for now (a level-design pass shelved
## `Level_7`..`Level_13`; they were also moved well clear in the .ldtk). rooms_in
## skips them: no Exit ever slides into one, the debug picker does not list them,
## and the escape row (`Level_14`..) follows the V block directly. Their NODES
## still exist in the loaded world, so a name lookup that used to find one
## (act1_beats' `music_room_name` = "Level_7", say) now resolves to null and its
## caller no-ops gracefully rather than crashing. Empty this array to bring them
## back. NOTE: several tests still target these rooms (music/intro/chase_route/
## save) and will fail until retargeted — shelving is a routing change, not a
## deletion, so that is expected and left for a follow-up.
const SHELVED_ROOMS: Array[String] = [
	"Level_7", "Level_8", "Level_9", "Level_10", "Level_11", "Level_12", "Level_13",
]

## The number in a room's identifier — the 16 in `Level_16` — or an
## INSERTED_ROOMS entry's position just past the room it follows. Rooms
## matching neither sort last, together, so they cannot silently displace the
## numbered sequence (Level_V_test, the greybox TEST room, and any future
## scratch room fall here).
static func play_index(room: Node) -> int:
	return index_in_name(str(room.name))


## The same, from a name alone. Split out because a save slot remembers the room
## it left off in as a STRING — there is no node to ask when the menu is drawing
## a card for a world it hasn't loaded — and two copies of "which digits count"
## is exactly how a menu ends up numbering rooms differently from the game.
##
## Scaled by 100 so an inserted room can land strictly between a numbered room
## and the next: Level_6 is 600, an insertion after it is 610-619, Level_7 is
## 700 — comfortable room for a INSERTED_ROOMS entry to grow past ten without
## a collision.
##
## Matches the trailing "Level_<digits>" REGARDLESS of what comes before it —
## not just names that BEGIN with "Level_". Act 1's rooms are bare (`Level_16`),
## but Act 2's and Act 3's are prefixed to stay unique across the importer's one
## shared `ldtk/levels/` folder (`Act_2_Level_3`, `Act3_Level_0` — see
## CLAUDE.md's "prefixed uniquely" rule), and a plain `begins_with("Level_")`
## check silently failed every one of those: they fell into the "sort last"
## bucket and the whole room lost identifier ordering to a worldY/worldX
## position tiebreak instead — the exact bug this function exists to prevent
## for Act 1's escape row, just triggered by an Act-prefixed name rather than a
## right-to-left grid.
static func index_in_name(name: String) -> int:
	if INSERTED_ROOMS.has(name):
		var after: Array = INSERTED_ROOMS[name]
		return int(after[0]) * 100 + 10 + int(after[1])
	const MARKER := "Level_"
	var pos := name.rfind(MARKER)
	if pos == -1:
		return 1 << 30
	var suffix := name.substr(pos + MARKER.length())
	if suffix == "":
		return 1 << 30
	for c in suffix:
		if c < "0" or c > "9":
			return 1 << 30
	return int(suffix) * 100


## Room to open in: the first, unless the debug picker asked for another one.
func _start_room() -> Node2D:
	if debug_start_room != "":
		for room in rooms:
			if room.name == debug_start_room:
				return room
		push_warning("LdtkWorld: debug_start_room '%s' matches no room." % debug_start_room)
	return rooms[0]


## Keep every Exit sign inside its own room.
##
## The sign hangs above its Exit trigger, which is fine for a doorway on the
## floor but pushes it out of the level when the Exit sits high up — an Exit
## placed a cell below the ceiling ended up ABOVE it, invisible, because the
## camera is clamped to the room. The same overhang on the x axis let a sign
## near a room's right edge poke through the seam and show up in the NEXT room
## (every room is loaded at once), which reads as a stray green block.
## Clamping here rather than in the import hook because this is where room
## rects are known.
func _clamp_exit_signs() -> void:
	const HALF := Vector2(16.0, 8.0)  # sign panel half-size, plus a pixel
	for ex in get_tree().get_nodes_in_group("exit"):
		var sign_node := (ex as Node).get_node_or_null("ExitSign") as Node2D
		if sign_node == null:
			continue
		for room in rooms:
			if not room.is_ancestor_of(ex):
				continue
			var r := room_rect(room)
			var g := sign_node.global_position
			sign_node.global_position = Vector2(
				clampf(g.x, r.position.x + HALF.x, r.end.x - HALF.x),
				clampf(g.y, r.position.y + HALF.y, r.end.y - HALF.y))
			break


## Back wall for one room: room_backdrop_texture stretched to the room's rect,
## or a plain ColorRect when no texture is set. Being a CanvasItem either way,
## it is lit by Light2D and dimmed by CanvasModulate, which is the whole point
## — see draw_room_backdrops above.
func _add_backdrop(room: Node2D) -> void:
	if room_backdrop_overrides.has(str(room.name)):
		var old_image := room.get_node_or_null("BG Image") as CanvasItem
		if old_image != null:
			old_image.hide()
	var r := room_rect(room)
	var panel: Control = _backdrop_panel(str(room.name))
	panel.name = "RoomBackdrop"
	panel.position = r.position - room.position  # room-local
	panel.size = r.size
	panel.self_modulate = room_backdrop_tints.get(str(room.name), Color.WHITE)
	# Background band. Sibling order (move_child below) is what keeps it behind
	# the room's own Background tile layer, which shares this z-index.
	panel.z_index = -1
	# The wall carries a SECOND light-mask bit that nothing else in the room has,
	# which is what lets WallPattern aim a light at the wall alone. Bit 1 is kept
	# so every ordinary lamp still lights it exactly as before — a light's
	# range_item_cull_mask defaults to bit 1 and this is an OR, not a swap.
	panel.light_mask = 1 | WallPattern.BACKDROP_MASK
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(panel)
	room.move_child(panel, 0)
	if panel is TextureRect and room_moon_regions.has(str(room.name)):
		panel.clip_contents = true
		var wall_material := ShaderMaterial.new()
		wall_material.shader = preload("res://scenes/props/backdrop/office_moon/moonless_wall.gdshader")
		var regions := PackedVector4Array()
		for region: Rect2 in room_moon_regions[str(room.name)]:
			regions.append(Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
		assert(regions.size() <= 64, "A moon backdrop supports at most 64 authored regions")
		wall_material.set_shader_parameter("moon_count", regions.size())
		regions.resize(64)
		wall_material.set_shader_parameter("moon_regions", regions)
		panel.material = wall_material
		for region in [room_moon_regions[str(room.name)][0]]:
			var moon := OFFICE_MOON.instantiate()
			panel.add_child(moon)
			moon.configure(panel.texture, region)
			var left_positions := {"Level_0": 184.0, "Level_1": 91.0, "Level_2": 64.0, "Level_3": 250.0, "Level_4": 190.0, "Level_5": 244.0, "Level_6": 85.0}
			moon.position.x = left_positions.get(str(room.name), moon.position.x - 8.0) - 4.0 * float(rooms.find(room)) / maxf(rooms.size() - 1, 1)
			moon.set_window_openings(OfficeWindowPanes.for_room(str(room.name)))
			moon.set_pool_enabled(false)
			# The floor pool follows the same "is this room live" rule as the moon
			# disc, re-evaluated on BOTH edges: transition_started (the slide
			# begins — this room may be the destination scrolling in) and
			# room_changed (the slide lands). Reading is_room_active() rather than
			# comparing to the emitted room is deliberate — mid-slide BOTH the
			# room being left and the one being entered are live, so a single
			# "winner" broadcast would switch the departing pool off too early.
			var follow_pool := func(_room: Node2D) -> void:
				moon.set_pool_enabled(is_room_active(room))
			room_changed.connect(follow_pool)
			transition_started.connect(follow_pool)


## The unsized, unpositioned backdrop node itself — a TextureRect painted with
## room_backdrop_texture (stretched to whatever size _add_backdrop gives it,
## same as the room it sits behind), or the old flat ColorRect when no texture
## is set.
##
## LINEAR filtering, not the world viewport's default NEAREST: this is a
## painted gradient, not pixel art, the same call DialogueBox's Portrait node
## makes for the same reason (see its class doc's PORTRAIT FILTERING note) —
## nearest-sampling a smooth low-frequency image stretched across a room would
## show its 512px source grid as visible banding instead of the soft wash it
## was painted as. Left at the texture's own colours (no modulate tint): the
## art already carries Act I's dim, desaturated mood, and multiplying
## room_backdrop_color over it would only mud a gradient that was mixed for
## exactly this shot in the first place.
func _backdrop_panel(room_name: String = "") -> Control:
	var chosen: Texture2D = room_backdrop_overrides.get(room_name, room_backdrop_texture)
	if chosen == null:
		var flat := ColorRect.new()
		flat.color = room_backdrop_color
		return flat
	var tex := TextureRect.new()
	tex.texture = chosen
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if room_backdrop_overrides.has(room_name) \
		else CanvasItem.TEXTURE_FILTER_LINEAR
	return tex


## Throw away the editor's authoring copy of the world before it can wake up.
##
## ldtk/Act1World.tscn contains an `EditorPreview` node — a real, saved instance
## of the imported world — purely so the rooms are visible in the editor and
## lights can be dragged onto actual geometry. A tool script that BUILT that
## preview at edit time was tried first and is not usable: nodes a tool script
## adds at runtime never appear in the Scene dock, so there is nothing to drag
## against.
##
## It has to go before the game runs, or every room exists twice. This is done in
## _enter_tree rather than _ready deliberately: a node's _enter_tree runs BEFORE
## its children enter the tree, so the preview's contents are freed without their
## _ready ever firing. Do it later and the preview's triggers, note tiles and
## lemons all register themselves in groups first — the musical-tile puzzle
## would count ten tiles instead of five.
func _drop_editor_preview() -> void:
	var preview := get_node_or_null("EditorPreview")
	if preview == null:
		return
	remove_child(preview)
	preview.free()


## Invisible lid for one room, resting on top of the room rect (see
## seal_room_ceilings). Layer 1 = world, so the player's mask already sees it.
func _add_ceiling(room: Node2D) -> void:
	var r := room_rect(room)
	var body := StaticBody2D.new()
	body.name = "RoomCeiling"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(r.size.x, ceiling_thickness)
	shape.shape = rect
	body.add_child(shape)
	room.add_child(body)
	body.position = r.position - room.position \
		+ Vector2(r.size.x * 0.5, -ceiling_thickness * 0.5)


## Rect of a room in world space. Starts from the widest tilemap the room
## actually uses, then grows to at least the room's own LDtk-declared size
## (LDTKLevel.size — set on import straight from the level's pxWid/pxHei) if
## that is bigger.
##
## The declared size alone used to be unreliable enough that this measured
## tile content instead (LDtk rooms have no intrinsic size once imported —
## see the addon's own LDTKLevel node, which DOES carry one now). Content
## alone breaks the moment part of a room is deliberately empty air with
## nothing painted in it — a climbing shaft, an open sky above a platforming
## room — since get_used_rect() only ever sees painted cells: extending
## Act_2_Level_0 upward into open sky left its camera limits, kill plane and
## ceiling seal all still clamped to the highest painted row, so the new
## space was there in LDtk but physically unreachable in play. Taking the
## LARGER of the two keeps every already-painted room exactly as measured
## before (declared size there is never smaller than content) and only
## changes anything for a room whose real footprint reaches past its tiles.
func room_rect(room: Node2D) -> Rect2:
	var used := Rect2()
	var found := false
	for child in room.get_children():
		if child is TileMapLayer:
			var layer: TileMapLayer = child
			var cells := layer.get_used_rect()
			if cells.size == Vector2i.ZERO:
				continue
			var cell := layer.tile_set.tile_size
			var r := Rect2(
				Vector2(cells.position * cell) + layer.position,
				Vector2(cells.size * cell))
			used = r if not found else used.merge(r)
			found = true
	if room is LDTKLevel and (room as LDTKLevel).size != Vector2i.ZERO:
		var declared := Rect2(Vector2.ZERO, Vector2((room as LDTKLevel).size))
		used = declared if not found else used.merge(declared)
		found = true
	if not found:
		return Rect2(room.position, Vector2(320, 180))
	return Rect2(used.position + room.position, used.size)


func spawn_point_for(room: Node2D) -> Vector2:
	var marker := room.get_node_or_null("Entities/PlayerStart")
	if marker != null:
		return (marker as Node2D).global_position
	return room_rect(room).get_center()


## Does this room hold a musical-tile puzzle? Checked against the "note_tile"
## group (every NoteTile joins it, see scenes/props/NoteTile.tscn) rather than
## a hardcoded room-name list, so a puzzle moved or added to a new room stays
## correct without this file having to know its name.
func _room_has_music_puzzle(room: Node2D) -> bool:
	for tile in get_tree().get_nodes_in_group("note_tile"):
		if room.is_ancestor_of(tile):
			return true
	return false


## Whether a room is the one the player is actually in RIGHT NOW, for anything
## that must be lit/awake the moment the room is on screen rather than the moment
## the camera finishes arriving. True for current_room, and — mid-slide — also
## for the room being entered (the player is teleported into it when the slide
## starts, so it is live for the whole crossing). This is what keeps the moon
## from popping in a beat after entry.
func is_room_active(room: Node2D) -> bool:
	return room != null and (room == current_room or room == transition_target)


func _enter_room(room: Node2D, snap: bool) -> void:
	current_room = room
	_canvas_modulate.color = \
		music_room_color if _room_has_music_puzzle(room) else _ambient_color
	_checkpoint = spawn_point_for(room)
	var r := room_rect(room)
	player.set_camera_limits(Rect2i(r))
	if snap:
		player.global_position = _checkpoint
		player.camera.reset_smoothing()
	# A story door is walked through once per VISIT, not once per game. Doing it
	# here covers every way back into a room — the return strip, a re-route, a
	# save resumed into it — rather than only the one path that happened to be
	# tested. Harmless on a door the story has not opened yet, which stays shut.
	var door := _door_in(room)
	if door != null:
		door.rearm()
	# Same rule as the door above: a room is restored per VISIT, so walking back
	# into one finds its floor the way it was first seen — and its moving
	# hazards at the start of their cycle, so a room presents the same pattern
	# every time you walk into it and not whichever phase the clock happens to
	# be at.
	# Crumbling platforms persist across visits; only respawn/reset restores them.
	DarkThought.reset_all(get_tree())
	MysteryBox.reset_all(get_tree())
	MagicCarpet.reset_all(get_tree())
	_thought_layer = room.get_node_or_null("ThoughtHazards") as TileMapLayer
	_water_layer = room.get_node_or_null("Water") as TileMapLayer
	room_changed.emit(room)


func _physics_process(_delta: float) -> void:
	if current_room == null or _transitioning:
		return
	if player.state == Player.State.DEAD:
		return
	var rect := room_rect(current_room)
	if player.global_position.y > rect.end.y + kill_margin:
		player.die()
		return
	if _in_thought_tile() and not player.has_thought_immunity():
		player.die()
		return
	# Painted water works the same way a Pond entity does — grabbed on
	# overlap alone, asked fresh every frame (a checkpoint under the surface,
	# a room load with him already in it, and a teleport all have to work
	# with no boundary ever crossed; see slide_zone.gd's own note on this
	# family of bug) — just checked against the tile grid instead of an
	# Area2D, since a painted shape has no single box to overlap.
	if _in_water_tile():
		if not player.swimming():
			player.enter_swim(self)
	else:
		player.exit_swim(self)


func _in_thought_tile() -> bool:
	if _thought_layer == null:
		return false
	var cell := _thought_layer.local_to_map(_thought_layer.to_local(player.global_position))
	return _thought_layer.get_cell_source_id(cell) != -1


## Is he in painted water? Asked with HYSTERESIS, deliberately: getting IN
## needs his centre under the surface, staying in only needs his body still
## touching it.
##
## A single point for both is what this used to be, and at the surface it
## flickered — measured in Act_2_Level_0, fifteen SWIM/FALL changes in 150
## frames, several a second, because buoyancy lifts him until his centre
## clears the top row and gravity drops him straight back in. That flicker is
## what made him wall-slide down the side of a full pool (WALL_SLIDE can only
## be entered from FALL, and half those frames were FALL), sink and stand on
## the bottom (real gravity applies during the FALL half), and snap between
## the swim and fall clips several times a second. The float now settles
## against a real surface (Player's swim_float_depth) so it never reaches the
## top row on its own, and this margin means even a deliberate breach has to
## clear his whole body before the swim ends.
func _in_water_tile() -> bool:
	if _water_layer == null:
		return false
	if player.swimming():
		return _water_overlaps_body()
	return _water_layer.has_water_at(player.global_position)


## Does any painted cell overlap his hitbox? Inset a pixel a side so merely
## grazing the surface — standing on a bank whose floor is flush with it, say
## — is not "still swimming".
func _water_overlaps_body() -> bool:
	var box := player.hitbox_rect().grow(-1.0)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return _water_layer.has_water_at(player.global_position)
	for corner in [box.position, Vector2(box.end.x, box.position.y),
			Vector2(box.position.x, box.end.y), box.end,
			Vector2(box.get_center().x, box.position.y),
			Vector2(box.get_center().x, box.end.y)]:
		if _water_layer.has_water_at(corner):
			return true
	return _water_layer.has_water_at(box.get_center())


## World Y of the water surface above `world_pos`, for Player's own buoyancy.
## This world node stands in as the "zone" token for painted water (see
## _physics_process), so it answers this under the SAME name a Pond does —
## Player asks whichever zone is holding him without knowing which kind it is.
## INF when that point is not in water.
func surface_y_at(world_pos: Vector2) -> float:
	if _water_layer == null:
		return INF
	return _water_layer.surface_y_at(world_pos)


func _unhandled_input(event: InputEvent) -> void:
	# R = instant retry from the last checkpoint.
	if event.is_action_pressed("respawn") and player.state != Player.State.DEAD \
			and not player.input_locked and not _transitioning:
		player.die()


func _on_checkpoint_activated(cp: Checkpoint) -> void:
	_checkpoint = cp.global_position
	for c in get_tree().get_nodes_in_group("checkpoint"):
		c.is_active = c == cp


## Hold long enough for the death animation to play, then put him back.
##
## maxf, not either number alone: `death_time` belongs to dying and is the same
## everywhere, `respawn_delay` belongs to this level and may want to be longer.
## Taking the larger means a level can never cut the burst off half way.
##
## process_always = false so the hold STOPS while the game is paused. A
## SceneTreeTimer keeps counting through a pause by default, which would respawn
## him behind the pause menu and hand back a different world than the one that
## was paused (see scenes/ui/pause_menu.gd).
func _on_player_died() -> void:
	await get_tree().create_timer(
		maxf(respawn_delay, player.death_time), false).timeout
	player.respawn(_checkpoint)
	# A respawn TELEPORTS him straight to the checkpoint, which the physics
	# engine cannot tell apart from having just walked there — so if the
	# checkpoint happens to sit inside an already-armed return-door strip (see
	# _resolve_return_arming's note; Level_v6 is the room this was found in),
	# the door would otherwise fire and bounce him straight into the room
	# behind the instant he respawns. Re-run the same "landed inside it? wait
	# for body_exited" check a fresh arrival already gets. Harmless where
	# there is nothing to overlap — one more overlap query and two frames.
	await _resolve_return_arming()
	# Put the room's crumbling platforms back BEFORE he lands, not after: a
	# retry that starts with the floor already missing is a room that gets
	# harder every time you fail it, which turns a retry loop into a restart.
	# Covers R-to-retry too — that route calls player.die() rather than
	# respawning directly, exactly so there is one path through here.
	CrumblingPlatform.reset_all(get_tree())
	# The same argument for a hazard that MOVES, and it bites harder: a crumbled
	# floor is at least visibly missing, while a drifting hazard half a lap out
	# of step just looks like bad luck. Every retry gets the pattern the room was
	# built around.
	DarkThought.reset_all(get_tree())
	# And the same again for a block already popped: retrying a room should not
	# find its mystery boxes spent from an attempt that just ended in death.
	MysteryBox.reset_all(get_tree())
	# And a moving carpet: back to its placed point and the start of its cycle,
	# same reasoning as DarkThought above.
	MagicCarpet.reset_all(get_tree())


## A story door in a room OWNS that room's doorway: you leave by walking
## through it (dissolving into the void), not by tripping the Exit. The Exit
## sign is normally placed right on top of the door, so without this the Exit's
## trigger wins the race and whisks you onward with the door beat never playing.
func _door_in(room: Node2D) -> LdtkDoor:
	for d in get_tree().get_nodes_in_group("story_door"):
		if d is LdtkDoor and room.is_ancestor_of(d):
			return d
	return null


## Walking through the story door is what advances that room — restore the
## player afterwards, since the walkthrough deliberately left him faded out
## and with his controller frozen.
func _on_door_walked(door: LdtkDoor) -> void:
	if _transitioning:
		return
	var came_from := current_room
	var exit := _exit_in(came_from)
	var target := _next_room(exit) if exit != null else _room_after(came_from)
	if target == null:
		return
	await _slide_to_room(target)
	player.visible = true
	player.modulate.a = 1.0
	player.set_physics_process(true)
	_arm_return(came_from)


func _room_after(room: Node2D) -> Node2D:
	var i := rooms.find(room)
	return rooms[i + 1] if i != -1 and i + 1 < rooms.size() else null


## The room you would back INTO from `room`. Used when arriving backwards, where
## there is no "came from" to reuse — you came from the room ahead, but the door
## to hang next is the one leading further back.
func _room_before(room: Node2D) -> Node2D:
	var i := rooms.find(room)
	return rooms[i - 1] if i > 0 else null


func _on_exit_reached(body: Node2D, exit: Node2D) -> void:
	if body != player or _transitioning:
		return
	if not current_room.is_ancestor_of(exit):
		return  # Only allow exits inside the active room to be triggered
	if _door_in(current_room) != null:
		return  # the door handles this doorway — see _door_in above
	var target := _next_room(exit)
	if target == null:
		return  # last room of the Act — Game.advance() territory, not ours
	var came_from := current_room
	await _slide_to_room(target)
	_arm_return(came_from)


func _build_return_zone() -> void:
	_return_zone = Area2D.new()
	_return_zone.name = "ReturnDoor"
	_return_zone.collision_layer = 8  # layer 4 "triggers"
	_return_zone.collision_mask = 2  # player only
	_return_zone.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 44)
	shape.shape = rect
	_return_zone.add_child(shape)
	add_child(_return_zone)
	_return_zone.body_exited.connect(_on_return_exited)
	_return_zone.body_entered.connect(_on_return_entered)


## After arriving from `from_room`, hang the return door along the edge of the
## current room that FACES that room — the way you came in. Walking back into
## that edge returns you, which is how Celeste reads, and unlike a door parked
## on the arrival spot it works whether you leave and come back or turn round
## on the spot. The strip covers the room's full height so falling out that
## side counts too.
func _arm_return(from_room: Node2D) -> void:
	_return_room = from_room
	if from_room != null:
		_return_pos = _re_entry_point(from_room)
	_apply_way_back()
	# Nothing behind the first room and no re-route either — leave no door rather
	# than a dangling one.
	if _return_room == null:
		_clear_return()
		return

	var rect := room_rect(current_room)
	var shape: CollisionShape2D = _return_zone.get_child(0)
	(shape.shape as RectangleShape2D).size = Vector2(16, rect.size.y)
	# The edge the door hangs on comes from where you physically WALKED IN FROM
	# (from_room), never from _return_room after _apply_way_back may have swapped
	# it for the story's reroute target. Those are different rooms for a reason:
	# Darkshang re-points the boss room's doorway at the escape row while the
	# player is still standing where they walked in, and "the way out is the way
	# he came" (act1_beats.gd) means the door stays on that same physical edge —
	# it is only what lies beyond it that changes. Computing the edge from the
	# REROUTE target instead (Level_15's own forward Exit, an unrelated doorway
	# with no physical relationship to Level_14) is what used to fling the door
	# to Level_14's far wall, past Darkshang's own spawn point, the moment the
	# encounter fired.
	#
	# Normally from_room is physically adjacent, but for non-contiguous
	# transition portals reached the ordinary way (like Level_V1 -> Level_2), we
	# still need to look at which half of from_room its OWN forward Exit — the
	# doorway that actually led here — is located in.
	var on_left := from_room != null and from_room.position.x < current_room.position.x
	var exit := _exit_in(from_room) if from_room != null else null
	if exit != null:
		var r_rect := room_rect(from_room)
		on_left = exit.global_position.x > r_rect.get_center().x
	var x := (rect.position.x + 6.0) if on_left else (rect.end.x - 6.0)
	_return_zone.global_position = Vector2(x, rect.get_center().y)
	_return_zone.monitoring = true
	await _resolve_return_arming()


## You normally arrive clear of the strip, so arm as soon as we can confirm
## that; if you did land inside it, wait for body_exited to arm it once you
## actually walk clear — checked twice a physics frame apart, since a body
## just placed by script has not been through collision processing yet.
##
## Shared by _arm_return (a fresh arrival can land inside the strip — a room
## whose PlayerStart sits close to the edge it was entered through) and by
## _on_player_died (see the note there: a respawn TELEPORTS the player, which
## looks to the physics engine exactly like walking in, so a checkpoint that
## happens to sit inside an already-armed strip would otherwise fire the
## backtrack the instant he respawns — measured, this is exactly what made
## dying/retrying in Level_v6 bounce straight back to Level_v5: its
## PlayerStart sits 16px off the edge it's entered through, and the strip
## that hangs there is 16px wide starting 6px in, so the two overlap by a
## couple of pixels).
func _resolve_return_arming() -> void:
	_return_armed = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _return_room != null and not _return_strip_rect().intersects(player.hitbox_rect()):
		_return_armed = true


## The return door's strip, as a plain Rect2 in world space — read straight off
## the shape/position that were just assigned in _arm_return, not asked of the
## Area2D. `Area2D.overlaps_body()` reflects the physics server's own
## MONITORING CACHE, which lags a teleport (a plain `global_position`
## assignment, not `move_and_slide`) by an extra physics step — measured,
## `body_entered` for a respawn landing back inside an already-armed strip
## fired on the THIRD physics frame after the teleport, one frame later than
## the two-frame wait above used to check it with. That let a stale "clear"
## reading arm the door right before the real, late signal walked straight
## back into it — see tests/level_v6_return_race_test.tscn, which is built
## around exactly that respawn. A Rect2 built from the shape's own size and
## the zone's current global_position has nothing to catch up on: it reads
## whatever is true on the frame it is called, teleport or not.
func _return_strip_rect() -> Rect2:
	var shape: CollisionShape2D = _return_zone.get_child(0)
	var size: Vector2 = (shape.shape as RectangleShape2D).size
	return Rect2(_return_zone.global_position - size * 0.5, size)


## Where to stand a player who has just walked BACK into `room`:
## `back_entry_offset` px to the INSIDE of that room's own Exit, so he lands
## clear of the trigger instead of on top of it.
##
## WHICH SIDE IS "INSIDE" HAS TO BE DERIVED. This used to subtract the offset
## flat, which silently assumed every room is walked left to right — true of the
## outbound rooms 0-11, whose Exits sit on their right-hand wall, and wrong for
## every single room of the escape. Rooms 12-21 run RIGHT TO LEFT across the grid
## (CLAUDE.md: level identifiers are play order, not world position) and their
## Exits are on their LEFT wall, so subtracting pushed the returning player out
## through that wall and into the NEXT room along.
##
## That is both halves of the bug it caused. He was placed outside the room the
## manager had just decided he was in — standing in the seam, in another room's
## geometry — and one step from there put him inside triggers belonging to a room
## he was not in, which bounced him somewhere else again.
##
## Reading it off the geometry fixes both rows at once and needs no per-room
## data: an Exit in the left half of its room has its room's interior to the
## right, and vice versa.
func _re_entry_point(room: Node2D) -> Vector2:
	var exit := _exit_in(room)
	if exit == null:
		return spawn_point_for(room)
	var rect := room_rect(room)
	var inward := 1.0 if exit.global_position.x < rect.get_center().x else -1.0
	return exit.global_position + Vector2(inward * back_entry_offset, -10.0)


## Point the doorway you came IN through at a different room, permanently.
##
## The way back out of a room is normally the room behind it, which is right for
## every room that is walked through once in one direction. The Darkshang
## encounter breaks that: Level_14 is entered from the left and the reveal turns
## Hooshang round, so walking back out of it is the escape CONTINUING — into
## Level_15, which hangs below the row and is itself authored right to left — and
## not an undo of the room he just arrived in.
##
## Kept as a room -> room map rather than a one-off overwrite of `_return_room`
## because that door is rebuilt every time it is used (see _arm_return): a single
## assignment would hold only until the first time the player walked back INTO
## the room, and the route would then quietly revert to the layout order. A room
## with no entry here is untouched, so this changes nothing anywhere it has not
## been asked for.
##
## Called from the story script rather than from an entity — which room the
## chase spills into is Act I's business, not the room manager's.
func set_way_back(room: Node2D, to_room_name: String) -> void:
	if room == null:
		return
	_way_back[room.name] = to_room_name
	# Reciprocal, because a re-routed door is still a two-way door — the rule the
	# whole room manager is built on. Without the return half, the room you land
	# in falls back to layout order for what is behind IT, and layout order is the
	# one thing already known to be wrong here: Level_15 is reached from Level_14
	# but sits between Level_16 and the world's edge on the grid, so _room_before
	# would hang its way back on Level_16 — forward, onto the same edge its own
	# Exit already occupies.
	_way_back[to_room_name] = room.name
	# Re-hang the door that is already up. Without this the re-route would only
	# take effect the next time the player entered the room, i.e. never — the
	# encounter happens while he is standing in it. Re-arming rather than patching
	# the destination in place also moves the strip to the right edge and covers
	# the case where there was no door at all (a re-routed room with nothing
	# behind it), which a bare assignment would leave unmonitored.
	#
	# _return_room can be null here — a room reached by dropping straight into
	# it (debug_start_room, a "finished" open) rather than by walking in, so no
	# earlier _arm_return ever ran. _room_before(room) is the same fallback
	# _ready() uses for the identical case at world-boot: the array-order
	# neighbour standing in for "the room he came from" when nothing recorded
	# one. Passing null through unchanged used to fall back to a bare geometry
	# comparison in _arm_return, which had no "came from" side to read and
	# hung the door on the room's FAR wall instead of the one he is standing
	# next to — invisible, since the strip has no art, and unreachable by
	# walking the way the story says to.
	if room == current_room:
		_arm_return(_return_room if _return_room != null else _room_before(room))


## Swap the story's destination in for the current room's way back, if it has one.
##
## Arrival is at that room's PlayerStart — its entrance — rather than beside its
## Exit the way an ordinary backtrack lands. A re-routed door is a way ONWARD, so
## it puts you where the room begins.
func _apply_way_back() -> void:
	if current_room == null:
		return
	var named := str(_way_back.get(current_room.name, ""))
	if named == "":
		return
	for room in rooms:
		if room.name == named:
			_return_room = room
			_return_pos = spawn_point_for(room)
			return
	push_warning("LdtkWorld: way back from '%s' names no room '%s'."
		% [current_room.name, named])


func _clear_return() -> void:
	# _return_room is cleared immediately (it is what actually gates re-entry);
	# `monitoring` must be deferred because Godot forbids toggling it from
	# inside the body_entered/body_exited callback that is firing right now.
	_return_room = null
	_return_armed = false
	_return_zone.set_deferred("monitoring", false)


func _on_return_exited(body: Node2D) -> void:
	if body == player:
		_return_armed = true


func _on_return_entered(body: Node2D) -> void:
	if body != player or not _return_armed or _transitioning or _return_room == null:
		return
	var room := _return_room
	var pos := _return_pos
	_clear_return()
	await _slide_to_room(room, pos)
	# Arm the NEXT step back, or backtracking would only ever work one room deep:
	# the door that brought us here has just been consumed, so without this the
	# room we land in has nothing behind it. You would be stranded beside that
	# room's own forward Exit — the only live trigger left — and walking into it
	# sent you straight back where you came from, which is what this looked like
	# in play ("go back from 4 to 3, try to go back again, end up in 4").
	_arm_return(_room_before(room))


## The Exit belonging to one room (rooms each hold their own in Entities).
func _exit_in(room: Node2D) -> Node2D:
	for n in get_tree().get_nodes_in_group("exit"):
		if n is Node2D and room.is_ancestor_of(n):
			return n
	return null


func _next_room(exit: Node2D) -> Node2D:
	var named := str(exit.get_meta("next_room", ""))
	if named != "":
		for room in rooms:
			if room.name == named:
				return room
		push_warning("LdtkWorld: Exit's NextRoom '%s' matches no room." % named)
	var i := rooms.find(current_room)
	return rooms[i + 1] if i != -1 and i + 1 < rooms.size() else null


## Where the camera actually settles when framing `focus` inside `rect` —
## Godot's own limit clamping, computed up front. Needed because
## Camera2D.get_screen_center_position() does NOT update in the same frame you
## move the camera's parent, so reading it back after a teleport returns the
## stale value (it silently produced a zero-length slide).
func _view_centre_for(rect: Rect2, focus: Vector2) -> Vector2:
	var view: Vector2 = get_viewport_rect().size / player.camera.zoom
	var half := view * 0.5
	var c := focus
	# A room smaller than the view can't be panned within — it just centres.
	c.x = rect.get_center().x if rect.size.x <= view.x \
		else clampf(c.x, rect.position.x + half.x, rect.end.x - half.x)
	c.y = rect.get_center().y if rect.size.y <= view.y \
		else clampf(c.y, rect.position.y + half.y, rect.end.y - half.y)
	return c


## The seamless bit: no load, no fade. The player is placed in the next room
## immediately, but the VIEW is detached (set_as_top_level) and eased across
## from the old room to the new one, so it reads as the camera travelling.
## `arrive_at` overrides where the player lands; Vector2.INF (the default)
## means "use the target room's PlayerStart", which is the forward case.
## Going backwards passes an explicit point beside the previous room's Exit.
func _slide_to_room(target: Node2D, arrive_at := Vector2.INF) -> void:
	_transitioning = true
	# The destination is live from here on — the player is placed in it below and
	# the camera only travels to catch up. Announcing it now (not at slide end)
	# is what lets its moon and pool scroll IN already lit instead of popping in.
	transition_target = target
	transition_started.emit(target)
	player.input_locked = true

	var cam := player.camera
	var from_rect := room_rect(current_room)
	var to_rect := room_rect(target)
	var spawn := spawn_point_for(target) if arrive_at == Vector2.INF else arrive_at

	var from := _view_centre_for(from_rect, player.global_position)
	var to := _view_centre_for(to_rect, spawn)

	# Limits must span both rooms mid-slide or the camera is clamped back.
	player.set_camera_limits(Rect2i(from_rect.merge(to_rect)))

	# Detach the camera so moving the player doesn't drag the view with him.
	cam.set_as_top_level(true)
	cam.position_smoothing_enabled = false
	cam.global_position = from

	player.global_position = spawn
	player.velocity = Vector2.ZERO

	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.tween_property(cam, "global_position", to, slide_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _slide_tween.finished

	# Hand the camera back to the player.
	cam.set_as_top_level(false)
	cam.position = Vector2.ZERO
	cam.position_smoothing_enabled = true
	transition_target = null
	_enter_room(target, false)
	# Respawn where you actually came IN, not at the room's PlayerStart — enter
	# a room from its right (walking backwards) and dying should not spit you
	# out at the far left. Celeste respawns you at the room's entry point.
	_checkpoint = spawn
	cam.reset_smoothing()
	player.input_locked = false
	_transitioning = false


## Fade the music down while a dialogue line is on screen. Kills any
## in-flight duck/restore tween first — Dialogue fires dialogue_opened again
## for every LINE of a conversation, which can land while the previous
## line's restore tween is still animating back up, and starting a fresh
## tween from wherever THAT one currently sits (rather than fighting it) is
## what keeps the music smoothly ducked instead of stuttering between lines.
func _duck_music() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db",
		_music_base_db - music_duck_db, music_duck_fade)


## Fade back to the track's own authored volume once the box has fully
## closed. Same race as _duck_music above, same fix.
func _unduck_music() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", _music_base_db, music_duck_fade)
