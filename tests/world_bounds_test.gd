extends Node
## Regression: a jump + up-dash must never take the player out of the top of a
## room. Level_2's ceiling row is unpainted above the ledge that holds its Exit,
## and an up-dash from there used to peak 44px above the room — the camera stays
## clamped, so the player vanished off the top of the screen. LdtkWorld's
## seal_room_ceilings caps every room; this checks the cap holds.
## Run:  godot --headless res://tests/world_bounds_test.tscn

var failures: Array[String] = []
var world: LdtkWorld

# Room index -> a spot to launch from, chosen at each room's highest standable
# floor (the only places from which the ceiling is even reachable).
const LAUNCH := {
	0: Vector2(72, 240),     # Level_1_Office, cubicle floor
	2: Vector2(912, 180),    # Level_2, the Exit ledge under the ceiling gap
	3: Vector2(984, 180),    # Level_3, top-left shelf by the PlayerStart
}


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(10)
	for i: int in LAUNCH:
		await _check_room(i, LAUNCH[i])
	if failures.is_empty():
		print("WORLD BOUNDS TEST: ALL PASS")
	else:
		print("WORLD BOUNDS TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_room(index: int, from: Vector2) -> void:
	var room: Node2D = world.rooms[index]
	world.current_room = room
	var top := world.room_rect(room).position.y
	var p := world.player
	p.respawn(from)
	for i in 60:
		await _frames(1)
		if p.is_on_floor():
			break
	_check(p.is_on_floor(), "room %d — launch point (%.0f,%.0f) is standable"
		% [index, from.x, from.y])

	Input.action_press("jump")
	await _frames(5)
	Input.action_release("jump")
	Input.action_press("move_up")
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	var peak := p.global_position.y
	for i in 60:
		await _frames(1)
		peak = minf(peak, p.global_position.y)
		if i > 10 and p.is_on_floor():
			break
	Input.action_release("move_up")
	# `peak` is the player's ORIGIN; his head is 6px above it (8x12 hitbox).
	_check(peak - 6.0 >= top - 0.5,
		"room %d (%s) — jump+dash stays under the ceiling  [head reached %.1f, ceiling %.0f]"
			% [index, room.name, peak - 6.0, top])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
