extends Node
## Regression: meeting Darkshang re-points the boss room's entrance.
##
## Level_12 is walked into from the left and the reveal turns Hooshang round, so
## the way out is the doorway he came in through. That doorway is the generic
## return door, which leads to the room behind — and the room behind is Level_11,
## a room he has already cleared. The escape actually continues into Level_13,
## which hangs below the row and is authored right to left (PlayerStart at its
## right end, Exit at its left).
##
## Three things this pins, in the order they broke:
##   1. BEFORE the encounter the doorway is ordinary backtracking and must stay
##      ordinary — the re-route is the encounter's doing, not the room's.
##   2. AFTER it, the same doorway lands him at Level_13's ENTRANCE.
##   3. It holds. The return door is rebuilt every time it is used, so a
##      re-route written once into _return_room would survive exactly until the
##      player walked back INTO the boss room and then quietly revert to layout
##      order — which reads in play as "it worked the first time".
## Run:  godot --headless res://tests/chase_route_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var from_room: Node2D
var chase_room: Node2D
var next_room: Node2D


func _ready() -> void:
	# Open in Level_11 rather than at the start of the Act: the opening cutscene
	# locks input and waits on a button press that headless will never send.
	LdtkWorld.debug_start_room = "Level_11"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(10)
	LdtkWorld.debug_start_room = ""

	from_room = _room("Level_11")
	chase_room = _room("Level_12")
	next_room = _room("Level_13")
	_check(from_room != null and chase_room != null and next_room != null,
		"the three rooms of the chase all exist")
	if from_room == null or chase_room == null or next_room == null:
		return _finish()
	_check(world.current_room == from_room,
		"opened in Level_11  [%s]" % world.current_room.name)

	# The wiring itself, before any of the behaviour: Act I claims the encounter.
	# Checked separately because if this connection is missing every assertion
	# below still passes the moment the test emits `triggered` by hand.
	var trigger := _chase_trigger()
	_check(trigger != null, "Level_12 has a DarkshangTrigger")
	if trigger == null:
		return _finish()
	_check(trigger.triggered.get_connections().size() > 0,
		"and something claimed its `triggered` beat  [%d listener(s)]"
			% trigger.triggered.get_connections().size())

	# --- 1. before the encounter, the doorway is an ordinary way back ---------
	await _go_forward()
	_check(world.current_room == chase_room,
		"walked into Level_12  [%s]" % world.current_room.name)
	await _go_back()
	_check(world.current_room == from_room,
		"untriggered, backing out of Level_12 still leads to Level_11  [%s]"
			% world.current_room.name)

	# --- 2. after it, the same doorway continues the escape -------------------
	await _go_forward()
	_check(world.current_room == chase_room, "back in Level_12 for the encounter")
	# The crossing itself, not _play(): the reveal awaits two lines of dialogue
	# and a button press each. `triggered` is what the trigger emits on the frame
	# the player breaks the line, before any of that — see darkshang_trigger.gd.
	trigger.triggered.emit(world.player)
	await _frames(20)
	await _go_back()
	_check(world.current_room == next_room,
		"after meeting him it leads to Level_13 instead  [%s]" % world.current_room.name)
	# At its ENTRANCE — a re-routed door is a way onward, so it lands where the
	# room begins rather than beside the Exit an ordinary backtrack arrives at.
	# _checkpoint is where the slide actually put him, exactly.
	_check(world._checkpoint.is_equal_approx(world.spawn_point_for(next_room)),
		"landing at Level_13's PlayerStart  [%s vs %s]"
			% [world._checkpoint, world.spawn_point_for(next_room)])

	# --- 3. and it holds, however many times the doorway is used --------------
	await _go_back()
	_check(world.current_room == chase_room,
		"Level_13 still backs out into Level_12  [%s]" % world.current_room.name)
	await _go_back()
	_check(world.current_room == next_room,
		"and leaving Level_12 a second time still goes to Level_13  [%s]"
			% world.current_room.name)

	# Level_11 is behind him for good, which is the point: the room he cleared on
	# the way in is not somewhere the chase can spill back into.
	await _go_back()
	_check(world._return_room == next_room,
		"the boss room's doorway no longer points at Level_11  [%s]"
			% world._return_room.name)
	# Only the one doorway moved, and its mirror. Every other room is left to
	# layout order, which is what backtrack_test walks end to end.
	_check(world._way_back.size() == 2
			and world._way_back.get(chase_room.name) == next_room.name
			and world._way_back.get(next_room.name) == chase_room.name,
		"and the re-route is the two halves of one door  [%s]" % world._way_back)

	# --- 4. the chase carries on past Level_13 -------------------------------
	# Level_14 sits to the LEFT of Level_13 on the bottom row, so world-sort order
	# runs ... Level_12, Level_14, Level_13 while the chase runs 11 -> 12 -> 13.
	# Layout order is wrong for this whole branch, and every fallback in the room
	# manager is layout order — which is why both directions are walked here.
	var last_room := _room("Level_14")
	_check(last_room != null, "Level_14 exists")
	if last_room != null:
		await _go_back()             # back into Level_13, facing its Exit
		_check(world.current_room == next_room, "back in Level_13")
		await _go_forward()
		_check(world.current_room == last_room,
			"Level_13's Exit reaches Level_14  [%s]" % world.current_room.name)
		await _go_back()
		_check(world.current_room == next_room,
			"and Level_14 backs out into Level_13  [%s]" % world.current_room.name)

	_finish()


## Leave the current room by tripping its Exit.
func _go_forward() -> void:
	var from: Node2D = world.current_room
	var ex := world._exit_in(from)
	if ex == null:
		_check(false, "%s has no Exit to walk out of" % from.name)
		return
	world.player.global_position = ex.global_position + Vector2(0, -8)
	await _settle(from)


## Walk into the return strip on the edge we came in through. Which edge that is
## comes from the world, not from an assumption here — Level_13 sits to the LEFT
## of Level_12 despite being the room after it, so a hardcoded left edge would
## test the wrong wall on the way home.
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


func _room(name: String) -> Node2D:
	for r in world.rooms:
		if r.name == name:
			return r
	return null


func _chase_trigger(node: Node = null) -> DarkshangTrigger:
	var here: Node = node if node != null else chase_room
	if here is DarkshangTrigger:
		return here
	for child in here.get_children():
		var found := _chase_trigger(child)
		if found != null:
			return found
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)


func _finish() -> void:
	if failures.is_empty():
		print("CHASE ROUTE TEST: ALL PASS")
	else:
		print("CHASE ROUTE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
