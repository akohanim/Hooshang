extends Node
## Regression: a jump + up-dash must never take the player out of the top of a
## room. Level_2's ceiling row is unpainted above the ledge that holds its Exit,
## and an up-dash from there used to peak 44px above the room — the camera stays
## clamped, so the player vanished off the top of the screen. LdtkWorld's
## seal_room_ceilings caps every room; this checks the cap holds.
## Run:  godot --headless res://tests/world_bounds_test.tscn
##
## THE LAUNCH POINTS ARE FOUND, NOT WRITTEN DOWN, and that is the whole reason
## this file was rewritten. It used to carry three hand-measured coordinates:
##
##     0: Vector2(72, 240),     # Level_1_Office, cubicle floor
##     2: Vector2(912, 180),    # Level_2, the Exit ledge under the ceiling gap
##     3: Vector2(984, 180),    # Level_3, top-left shelf by the PlayerStart
##
## Rooms then moved — every room from 1 on shifted right, and a new room was
## inserted at the front — and all three landed in empty space in the wrong room.
## The player fell, `is_on_floor()` came back true on some other floor entirely,
## and every assertion passed while testing nothing: the recorded peak was 84px
## BELOW the ceiling it was supposed to be pressed against. A vacuous pass is
## worse than a failure, because nothing ever asks about it again.
##
## So each room now names its own launch point: the topmost cell of its collision
## layer that has clear space above it — the highest place a player can stand,
## which is the only kind of place the ceiling is reachable from. That also lets
## this sweep EVERY room instead of the three somebody had the patience to
## measure, which is what the hand-written list was really a workaround for.

var failures: Array[String] = []
var world: LdtkWorld
## Best vertical reach seen across the sweep. A jump+dash that never leaves the
## floor is the failure mode this whole file just walked into once.
var _reached := 0.0

## Clear cells needed above a tile before it counts as standable. His hitbox is
## 12px on a 16px grid, so one is enough to stand in; two keeps him out of the
## slots where the ceiling is a tile away and the jump is not a jump.
const HEADROOM_CELLS := 2
## The LDtk grid.
const CELL := 16.0


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(10)
	var checked := 0
	for room: Node2D in world.rooms:
		if await _check_room(room):
			checked += 1
	_check(checked >= world.rooms.size() - 2,
		"found a standable launch point in %d of %d rooms" % [checked, world.rooms.size()])
	_check(_reached >= 40.0,
		"the launches actually left the ground  [best reach %.0fpx]" % _reached)
	if failures.is_empty():
		print("WORLD BOUNDS TEST: ALL PASS")
	else:
		print("WORLD BOUNDS TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Jump + up-dash from `room`'s highest standable tile. Returns false if the room
## has nowhere to launch from, which is not a failure on its own — the count is
## asserted once at the end, so a single odd room can't fail the run but the
## whole world quietly going unstandable still does.
func _check_room(room: Node2D) -> bool:
	var from := _launch_point(room)
	if from == Vector2.INF:
		return false
	world.current_room = room
	var top := world.room_rect(room).position.y
	var p := world.player
	# Act I opens on a locked player mid-cutscene and with the dash not yet
	# granted, and neither of those is this test's subject. Left alone they make
	# every press a no-op: the run passes with the peak sitting exactly on the
	# floor he started from, which is what "0px of reach" in the output means and
	# how this went unnoticed. The reach is printed for that reason — an
	# assertion about how high he got is worthless without it.
	p.input_locked = false
	p.has_dash = true
	p.respawn(from)
	var landed := false
	for i in 90:
		await _frames(1)
		if p.is_on_floor():
			landed = true
			break
	if not landed:
		return false
	# He must have settled where he was put, not fallen out of the room and onto
	# something below it — the exact failure the old fixed coordinates hid.
	if absf(p.global_position.y - from.y) > 24.0:
		_check(false, "%s — launch point (%.0f,%.0f) is standable (settled at y=%.0f)"
			% [room.name, from.x, from.y, p.global_position.y])
		return false

	var launch_y := p.global_position.y
	Input.action_press("jump")
	await _frames(5)
	Input.action_release("jump")
	Input.action_press("move_up")
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	var peak := p.global_position.y
	for i in 90:
		await _frames(1)
		peak = minf(peak, p.global_position.y)
		if i > 10 and p.is_on_floor():
			break
	Input.action_release("move_up")
	# `peak` is the player's ORIGIN; his head is 6px above it (8x12 hitbox).
	var head := peak - 6.0
	_reached = maxf(_reached, launch_y - peak)
	_check(head >= top - 0.5,
		"%s — jump+dash stays under the ceiling  [head %.1f, ceiling %.0f, %.0fpx of reach]"
			% [room.name, head, top, launch_y - peak])
	return true


## The highest place in `room` a player could stand.
##
## Read off the room's own collision layer rather than measured by hand, so it
## follows the room when the room moves. LDtk's import puts every solid tile in
## "Collisions"; the other TileMapLayers are paint.
func _launch_point(room: Node2D) -> Vector2:
	var layer: TileMapLayer = room.get_node_or_null("Collisions")
	if layer == null:
		return Vector2.INF
	var solid := {}
	for c: Vector2i in layer.get_used_cells():
		solid[c] = true
	# The candidate has to be INSIDE the room, and the first version of this was
	# not: a room's topmost collision cells are its own border, which has nothing
	# above it and therefore reads as the best place in the world to stand. Every
	# room duly launched him from the roof, where he was already 14px past the
	# ceiling before he jumped and the assertion could only fail. Inset by a cell
	# so the floor he stands on is a floor and not the seal.
	var inner := world.room_rect(room).grow(-CELL)
	var best := Vector2.INF
	for c: Vector2i in solid:
		var clear := true
		for up in range(1, HEADROOM_CELLS + 1):
			if solid.has(c + Vector2i(0, -up)):
				clear = false
				break
		if not clear:
			continue
		# map_to_local gives the tile's CENTRE.
		var centre := layer.to_global(layer.map_to_local(c))
		if not inner.has_point(centre):
			continue
		if best == Vector2.INF or centre.y < best.y:
			best = centre
	if best == Vector2.INF:
		return Vector2.INF
	# Stand him a little above the tile's top face and let the settle loop drop
	# him onto it, rather than trying to place his 12px body exactly on it.
	return best - Vector2(0.0, CELL)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
