extends Node
## The escape row, walked end to end: every room comes down as he enters it, and
## the last door leads home.
##
## Three things that are each invisible in play until they are wrong:
##   1. Each of rooms 13-22 collapses ONCE, on the way through. A room that
##      collapses on arrival from the wrong side would drop its ceiling while he
##      is walking backwards; a room that collapses twice would re-drop props
##      that are already on the floor, which does nothing visible and hides that
##      the guard is gone.
##   2. Nothing collapses on the OUTBOUND row. The beat is keyed to a range of
##      room numbers, and a range is exactly the kind of thing that quietly grows
##      an off-by-one.
##   3. Room 22's Exit leads to Level_0. Left to play order it runs off the end
##      of the world and returns nothing, so the last door of the game does
##      nothing at all — which reads as a broken door, not as an ending.
## Run:  godot --headless res://tests/escape_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var beats: Act1Beats


func _ready() -> void:
	LdtkWorld.debug_start_room = "Level_15"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(20)
	LdtkWorld.debug_start_room = ""
	for child in world.get_children():
		if child is Act1Beats:
			beats = child
	_check(beats != null, "the world carries Act I's beats")
	if beats == null:
		return _finish()

	# --- 3. the way home, checked before the walk ----------------------------
	# Metadata, not behaviour, so it is readable without playing to room 22 —
	# and it is what the room manager actually consults.
	var last := _room("Level_25")
	_check(last != null, "Level_25 exists")
	if last != null:
		var exit := world._exit_in(last)
		_check(exit != null and str(exit.get_meta("next_room", "")) == "Level_0",
			"Level_25's Exit leads back to Level_0  [%s]"
				% (str(exit.get_meta("next_room", "")) if exit else "no Exit"))
		_check(world._next_room(exit) == _room("Level_0"),
			"...and the room manager resolves it  [%s]" % (
				world._next_room(exit).name if world._next_room(exit) else "nothing"))

	# --- 1. walk the row, one room at a time ---------------------------------
	var fell := {}
	var pads_before := _pad_positions()
	for n in range(13, 23):
		var room := _room("Level_%d" % n)
		if room == null:
			continue
		var hanging_before := RoomCollapse._airborne_in(room).size()
		await _go_forward()
		if world.current_room != room:
			_check(false, "walked into Level_%d  [%s]" % [n, world.current_room.name])
			break
		# Long enough for the lead-in, the staggered fall and the landing squash.
		await _hold(collapse_wait(room))
		var hanging_after := RoomCollapse._airborne_in(room).size()
		fell[n] = [hanging_before, hanging_after]
		if hanging_before > 0:
			_check(hanging_after == 0,
				"Level_%d came down  [%d hanging -> %d]" % [n, hanging_before, hanging_after])
		else:
			_check(true, "Level_%d had nothing hanging to drop" % n)

	_check(beats._collapsed.size() == fell.size(),
		"each room collapsed exactly once  [%d rooms, %d marked]"
			% [fell.size(), beats._collapsed.size()])

	# The sounding pads are NOT scenery and do not come down with the room —
	# rooms 16, 17 and 18 keep a layout you can recognise from its twin on the
	# way out. This is one word in RoomCollapse.FALLS_UNDER and putting it back
	# is silent in play until you notice a room rearranged itself.
	var pads_after := _pad_positions()
	var moved := []
	for pad in pads_after:
		if pads_before.get(pad, pads_after[pad]) != pads_after[pad]:
			moved.append(pad)
	_check(not pads_after.is_empty() and moved.is_empty(),
		"the sounding pads stayed where they were  [%d pads, %d moved]"
			% [pads_after.size(), moved.size()])

	# --- 2. the outbound row is not part of this ----------------------------
	var outbound := []
	for n in range(0, 12):
		if beats._collapsed.has("Level_%d" % n):
			outbound.append(n)
	_check(outbound.is_empty(),
		"no room on the way OUT collapsed  [%s]" % str(outbound))

	# And the last door actually goes home.
	if world.current_room == last:
		await _go_forward()
		_check(world.current_room == _room("Level_0"),
			"walking out of Level_25 arrives in Level_0  [%s]" % world.current_room.name)

	_finish()


## How long to let a room finish falling: what RoomCollapse itself says, plus the
## lead-in the beat waits out first, plus a margin. Asked rather than hardcoded,
## so retuning the fall cannot silently turn this test into a race.
func collapse_wait(room: Node2D) -> float:
	return beats.collapse_lead_in + RoomCollapse.duration(room) + 1.0


func _go_forward() -> void:
	var from: Node2D = world.current_room
	var ex := world._exit_in(from)
	if ex == null:
		_check(false, "%s has no Exit" % from.name)
		return
	world.player.global_position = ex.global_position + Vector2(0, -8)
	for i in 300:
		await get_tree().physics_frame
		if not world._transitioning and world.current_room != from:
			break
	await _frames(25)


func _room(name: String) -> Node2D:
	for r in world.rooms:
		if r.name == name:
			return r
	return null


## Where every sounding pad in the world is, keyed by node path. Taken from the
## group rather than by walking the escape rooms, so a pad that somehow ended up
## in the wrong room still gets watched.
func _pad_positions() -> Dictionary:
	var out := {}
	for pad in get_tree().get_nodes_in_group("note_tile"):
		if pad is Node2D:
			out[str(pad.get_path())] = (pad as Node2D).global_position
	return out


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)


func _finish() -> void:
	if failures.is_empty():
		print("ESCAPE TEST: ALL PASS")
	else:
		print("ESCAPE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
