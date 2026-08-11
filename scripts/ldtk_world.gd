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
## Room order is by world position (left to right, then top to bottom). An
## Exit's NextRoom field overrides that when you want a non-linear jump.

signal room_changed(room: Node2D)

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
@export var room_backdrop_color := Color(0.42, 0.3, 0.27)

@export_group("Bounds")
## Cap every room with an invisible ceiling sitting just above its top edge.
##
## A room is only meant to be left through an Exit or a Door, but nothing was
## stopping a jump + up-dash from leaving through the TOP. Level_2's ceiling row
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

# Rooms whose way back the story has re-pointed: room name -> the room walking
# back out of it actually leads to. See set_way_back().
var _way_back := {}


func _enter_tree() -> void:
	_drop_editor_preview()


func _ready() -> void:
	_world = world_scene.instantiate()
	add_child(_world)

	rooms = rooms_in(_world)

	if draw_room_backdrops:
		for room in rooms:
			_add_backdrop(room)
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

	if rooms.is_empty():
		push_error("LdtkWorld: the world scene has no rooms.")
		return
	_clamp_exit_signs()
	_restore_state()
	_enter_room(_start_room(), true)


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
## Play order is the LEVEL IDENTIFIER — `Level_0`, `Level_1`, `Level_2` — which
## is the rule the whole project already runs on (CLAUDE.md: "Level identifiers
## ARE the play order"), and is why inserting a room means renumbering the ones
## after it.
##
## This used to sort by world POSITION, left to right then top to bottom. That
## agreed with the identifiers exactly as long as the world was one left-to-right
## row, and stopped the moment the escape row was added: rooms 12-21 run RIGHT to
## left across the bottom of the grid, so position order reads them 21, 20, 19 …
## 13, 12 — precisely backwards. Every fallback in this file is "the next room in
## this array", so walking out of Level_13's Exit sent you to Level_12, the room
## you had just come from.
##
## Position is kept as the tiebreak, so a room whose name carries no number (or
## two rooms sharing one) still lands somewhere stable rather than in whatever
## order the scene tree happened to hold them.
##
## Static, and taking the world as an argument, so the debug picker can list the
## rooms of a world without standing up a whole LdtkWorld (player, lights,
## backdrops, signal wiring) just to read four names — and so there is only one
## definition of the ordering for both to agree on.
static func rooms_in(world: Node) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for child in world.get_children():
		if child is Node2D and child.has_node("Entities"):
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


## The number in a room's identifier — the 13 in `Level_13`. Rooms without one
## sort last, together, so they cannot silently displace the numbered sequence.
static func play_index(room: Node) -> int:
	return index_in_name(str(room.name))


## The same, from a name alone. Split out because a save slot remembers the room
## it left off in as a STRING — there is no node to ask when the menu is drawing
## a card for a world it hasn't loaded — and two copies of "which digits count"
## is exactly how a menu ends up numbering rooms differently from the game.
static func index_in_name(name: String) -> int:
	var digits := ""
	for i in range(name.length() - 1, -1, -1):
		var c := name[i]
		if c < "0" or c > "9":
			break
		digits = c + digits
	return int(digits) if digits != "" else 1 << 30


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


## Back wall for one room: a plain ColorRect behind every layer. Being a
## CanvasItem it is lit by Light2D and dimmed by CanvasModulate, which is the
## whole point — see draw_room_backdrops above.
func _add_backdrop(room: Node2D) -> void:
	var r := room_rect(room)
	var panel := ColorRect.new()
	panel.name = "RoomBackdrop"
	panel.color = room_backdrop_color
	panel.position = r.position - room.position  # room-local
	panel.size = r.size
	# Background band. Sibling order (move_child below) is what keeps it behind
	# the room's own Background tile layer, which shares this z-index.
	panel.z_index = -1
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(panel)
	room.move_child(panel, 0)


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
## pomegranates all register themselves in groups first — the musical-tile puzzle
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


## Rect of a room in world space. LDtk rooms have no intrinsic size once
## imported, so measure the widest tilemap the room actually uses.
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
	if not found:
		return Rect2(room.position, Vector2(320, 180))
	return Rect2(used.position + room.position, used.size)


func spawn_point_for(room: Node2D) -> Vector2:
	var marker := room.get_node_or_null("Entities/PlayerStart")
	if marker != null:
		return (marker as Node2D).global_position
	return room_rect(room).get_center()


func _enter_room(room: Node2D, snap: bool) -> void:
	current_room = room
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
		var exit := _exit_in(from_room)
		_return_pos = (exit.global_position + Vector2(-back_entry_offset, -10.0)) \
			if exit != null else spawn_point_for(from_room)
	_apply_way_back()
	# Nothing behind the first room and no re-route either — leave no door rather
	# than a dangling one.
	if _return_room == null:
		_clear_return()
		return

	var rect := room_rect(current_room)
	var shape: CollisionShape2D = _return_zone.get_child(0)
	(shape.shape as RectangleShape2D).size = Vector2(16, rect.size.y)
	# Which edge the door hangs on comes from where it LEADS, not from where you
	# came in. Those are the same room in the ordinary case; when the story has
	# re-pointed the way back they can differ, and it is the destination that has
	# to be on the far side of the doorway you walk into.
	var on_left := _return_room.position.x < current_room.position.x
	var x := (rect.position.x + 6.0) if on_left else (rect.end.x - 6.0)
	_return_zone.global_position = Vector2(x, rect.get_center().y)
	_return_zone.monitoring = true

	# You normally arrive clear of the strip, so arm as soon as we can confirm
	# that; if you did land inside it, body_exited arms it when you leave.
	_return_armed = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _return_room != null and not _return_zone.overlaps_body(player):
		_return_armed = true


## Point the doorway you came IN through at a different room, permanently.
##
## The way back out of a room is normally the room behind it, which is right for
## every room that is walked through once in one direction. The Darkshang
## encounter breaks that: Level_11 is entered from the left and the reveal turns
## Hooshang round, so walking back out of it is the escape CONTINUING — into
## Level_12, which hangs below the row and is itself authored right to left — and
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
	# one thing already known to be wrong here: Level_12 is reached from Level_11
	# but sits between Level_13 and the world's edge on the grid, so _room_before
	# would hang its way back on Level_13 — forward, onto the same edge its own
	# Exit already occupies.
	_way_back[to_room_name] = room.name
	# Re-hang the door that is already up. Without this the re-route would only
	# take effect the next time the player entered the room, i.e. never — the
	# encounter happens while he is standing in it. Re-arming rather than patching
	# the destination in place also moves the strip to the right edge and covers
	# the case where there was no door at all (a re-routed room with nothing
	# behind it), which a bare assignment would leave unmonitored.
	if room == current_room:
		_arm_return(_return_room)


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
	_enter_room(target, false)
	# Respawn where you actually came IN, not at the room's PlayerStart — enter
	# a room from its right (walking backwards) and dying should not spit you
	# out at the far left. Celeste respawns you at the room's entry point.
	_checkpoint = spawn
	cam.reset_smoothing()
	player.input_locked = false
	_transitioning = false
