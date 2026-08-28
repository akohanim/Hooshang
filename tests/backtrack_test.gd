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
	# Stops at the first room with no way onward of its OWN. Level_14 is the boss
	# room: it has no Exit and no story door, because the Darkshang encounter
	# re-points its entrance instead — a story beat this test has no way to play
	# (see chase_route_test.gd, which owns that route). Before this guard the loop
	# sat on Level_14 forever, failing the same assertion until the run was killed.
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

	# --- Trigger the chase encounter so Level_14 re-routes to Level_15 ------
	# The Darkshang encounter re-points Level_14's return door to Level_15,
	# opening the escape row (levels 14-24). We trigger this the same way the
	# chase_route_test does: emit `triggered` then `chase_begun`.
	var chase_trigger := _find_darkshang_trigger(world.current_room)
	if chase_trigger != null:
		chase_trigger.triggered.emit(world.player)
		await _frames(20)
		chase_trigger.chase_begun.emit()
		await _frames(10)
		_check(true, "triggered Darkshang encounter in %s" % world.current_room.name)
	else:
		_check(false, "could not find DarkshangTrigger in %s" % world.current_room.name)

	# --- Continue through the escape row (the route back: 14-24) ------------
	var back: Array[String] = [world.current_room.name]
	# Walk backward out of Level_14 — the re-routed return door now leads to
	# Level_15, the start of the escape row.
	if world._return_room != null:
		var from: Node2D = world.current_room
		await _go_back()
		_check(world.current_room != from,
			"escape: %s -> %s" % [from.name, world.current_room.name])
		back.append(world.current_room.name)

		# Walk forward through the rest of the escape row (15, 16, ... 24).
		while _has_way_onward(world.current_room):
			from = world.current_room
			await _go_forward()
			if world.current_room == from:
				break  # no more rooms
			_check(true,
				"escape: %s -> %s" % [from.name, world.current_room.name])
			back.append(world.current_room.name)
	_check(back.size() >= 3,
		"walked the escape route  [%d rooms]" % back.size())

	# Every room's re-entry point has to be INSIDE that room, and clear of its own
	# Exit. Checked over the whole world rather than only the rooms this test
	# happened to walk, because the failure is per-room geometry and it hid in the
	# ten rooms a forward walk never backtracks through.
	#
	# The offset used to be subtracted flat, which assumed left-to-right travel.
	# The escape row runs right to left with its Exits on the LEFT wall, so all
	# ten of rooms 12-21 put a returning player through that wall and into the
	# next room along — outside the room the manager thought he was in, and in
	# reach of triggers belonging to a room he was not in.
	var stranded: Array[String] = []
	var on_the_trigger: Array[String] = []
	for room in world.rooms:
		var exit := world._exit_in(room)
		if exit == null:
			continue
		var at := world._re_entry_point(room)
		var rect := world.room_rect(room)
		if not rect.has_point(at):
			stranded.append("%s at x=%.0f, room %.0f-%.0f"
				% [room.name, at.x, rect.position.x, rect.end.x])
		# 16px trigger, so anything inside 8px of its centre is standing on it.
		if absf(at.x - exit.global_position.x) < 8.0:
			on_the_trigger.append(str(room.name))
	_check(stranded.is_empty(),
		"every room re-enters INSIDE itself  [%s]" % ", ".join(stranded))
	_check(on_the_trigger.is_empty(),
		"and clear of its own Exit, not on top of it  [%s]" % ", ".join(on_the_trigger))

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
		# Through the door's OWN detection — walk him to the opening and let it
		# notice — rather than calling _walk_through() directly, which is what
		# this used to do. Poking that method never exercised the path a player
		# takes, so the test passed happily while the real door was spent after
		# one use and room 1 had no way forward at all.
		door.arm()                              # what Rumi does when she leaves
		await _frames(40)                       # the swing (Door.open_time)
		# Step clear of the opening first: a door re-armed on arrival makes him
		# leave it once before it will fire again (LdtkDoor.rearm), so dropping
		# him straight onto it would wait forever.
		var y := world.player.global_position.y
		world.player.global_position = Vector2(door.doorway_centre_x() - 60.0, y)
		await _frames(10)
		world.player.global_position = Vector2(door.doorway_centre_x(), y)
	else:
		var ex := world._exit_in(from)
		var shape_node := ex.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var offset := shape_node.position if shape_node != null else Vector2.ZERO
		var rect := world.room_rect(from)
		var dir := 1.0 if ex.global_position.x < rect.get_center().x else -1.0
		world.player.global_position = ex.global_position + offset + Vector2(dir * 12.0, 0.0)
		await _frames(1)
		world.player.global_position = ex.global_position + offset
	await _settle(from)


## Walk into the return strip on the edge we came in through.
func _go_back() -> void:
	var from: Node2D = world.current_room
	world.player.global_position = world._return_zone.global_position
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


## Recursively find a DarkshangTrigger in a room's subtree.
func _find_darkshang_trigger(node: Node) -> DarkshangTrigger:
	if node is DarkshangTrigger:
		return node
	for child in node.get_children():
		var found := _find_darkshang_trigger(child)
		if found != null:
			return found
	return null
