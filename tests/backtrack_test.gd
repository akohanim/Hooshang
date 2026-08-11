extends Node
## Regression: the Exit is a TWO-WAY door, all the way back.
##
## Backtracking used to work exactly one room deep — _arm_return() only ran
## after forward moves, so the room you returned into had nothing behind it. You
## were left standing beside that room's own forward Exit, the only live trigger
## in reach, and walking into it threw you forward again ("go back from 4 to 3,
## try to go back again, end up in 4"). This walks the whole Act forward, the
## whole Act back, then forward again.
## Run:  godot --headless res://tests/backtrack_test.tscn

var failures: Array[String] = []
var world: LdtkWorld


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(10)
	_check(world.rooms.size() >= 3, "the world has enough rooms to test backtracking")

	# Forward through every room, so each return door is armed as it is in play.
	#
	# Stops at the first room with no way onward of its OWN. Level_11 is the boss
	# room: it has no Exit and no story door, because the Darkshang encounter
	# re-points its entrance instead — a story beat this test has no way to play
	# (see chase_route_test.gd, which owns that route). Before this guard the loop
	# sat on Level_11 forever, failing the same assertion until the run was killed.
	var forward: Array[String] = [world.current_room.name]
	while world._room_after(world.current_room) != null \
			and _has_way_onward(world.current_room):
		var from: Node2D = world.current_room
		await _go_forward()
		_check(world.current_room != from,
			"forward: %s -> %s" % [from.name, world.current_room.name])
		forward.append(world.current_room.name)
	_check(forward.size() >= 3,
		"walked forward through the Act  [%d rooms]" % forward.size())

	# ...and all the way back. This is the part that used to break at step 2.
	# As far as we actually came, not rooms.size(): the walk above stops short of
	# the rooms only the chase can reach.
	var back: Array[String] = [world.current_room.name]
	for i in forward.size() - 1:
		var from: Node2D = world.current_room
		var want: Node2D = world._room_before(from)
		await _go_back()
		_check(world.current_room == want,
			"back: %s -> %s (wanted %s)" % [from.name, world.current_room.name, want.name])
		back.append(world.current_room.name)

	_check(world.current_room == world.rooms[0], "backtracked to the first room")
	_check(world._return_room == null and not world._return_armed,
		"the first room has no return door left dangling behind it")

	# Turning round again still works — going back must not break going forward.
	var from_first: Node2D = world.current_room
	await _go_forward()
	_check(world.current_room != from_first,
		"forward again after backtracking: %s -> %s" % [
			from_first.name, world.current_room.name])

	print("  route out : %s" % " -> ".join(forward))
	print("  route back: %s" % " -> ".join(back))
	if failures.is_empty():
		print("BACKTRACK TEST: ALL PASS")
	else:
		print("BACKTRACK TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Whether this room can be left forwards under its own steam — the two things
## _go_forward knows how to use.
func _has_way_onward(room: Node2D) -> bool:
	return world._door_in(room) != null or world._exit_in(room) != null


## Leave the current room the intended way: through its story door if it has
## one (the door owns that doorway), otherwise by tripping its Exit.
func _go_forward() -> void:
	var from: Node2D = world.current_room
	var door := world._door_in(from)
	if door != null:
		door._walk_through(world.player)
	else:
		var ex := world._exit_in(from)
		world.player.global_position = ex.global_position + Vector2(0, -8)
	await _settle(from)


## Walk into the return strip on the edge we came in through.
func _go_back() -> void:
	var from: Node2D = world.current_room
	var rect := world.room_rect(from)
	world.player.global_position = Vector2(rect.position.x + 6.0, rect.get_center().y)
	await _settle(from)


func _settle(from: Node2D) -> void:
	for i in 200:
		await _frames(1)
		if not world._transitioning and world.current_room != from:
			break
	await _frames(25)   # let _arm_return finish its two-frame confirmation


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
