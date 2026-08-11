extends Node
## Regression: play order is the LEVEL IDENTIFIER, not where the room sits.
##
## The escape row (12-21) runs RIGHT to left across the bottom of the LDtk grid,
## so sorting rooms by world position reads it 21, 20, 19 … 13, 12 — backwards.
## Every "next room" fallback in ldtk_world.gd is "the next entry in that array",
## so walking out of Level_13's Exit handed you Level_12: the room you had just
## come from. In play it looked like the exit was a door back.
##
## This asserts the ORDER itself rather than walking the rooms, because the order
## is the thing that was wrong and a walk can pass for the wrong reason — the
## return doors are two-way, so a reversed row still lets you move, just never
## forwards. backtrack_test walks; this one measures.
## Run:  godot --headless res://tests/route_order_test.tscn

var failures: Array[String] = []


func _ready() -> void:
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(10)

	var order: Array[String] = []
	for room in world.rooms:
		order.append(room.name)
	print("  play order: %s" % " ".join(order))

	# 1. Numbered rooms come out in numeric order, with none missing or repeated.
	var numbers: Array[int] = []
	for room in world.rooms:
		var n := LdtkWorld.play_index(room)
		if n < (1 << 30):
			numbers.append(n)
	var sorted_numbers := numbers.duplicate()
	sorted_numbers.sort()
	_check(numbers == sorted_numbers,
		"rooms come out in identifier order  [%s]" % str(numbers))
	_check(numbers.size() == world.rooms.size(),
		"every room's name carries its number  [%d of %d]"
			% [numbers.size(), world.rooms.size()])

	# 2. The specific reversal that was reported. Checked by NAME rather than by
	#    index so the assertion still means something when rooms are added.
	for n in range(12, 21):
		var here := _room(world, "Level_%d" % n)
		var next := _room(world, "Level_%d" % (n + 1))
		if here == null or next == null:
			continue
		_check(world._room_after(here) == next,
			"Level_%d leads on to Level_%d  [%s]" % [n, n + 1,
				world._room_after(here).name if world._room_after(here) else "nothing"])
		_check(world._room_before(next) == here,
			"...and Level_%d backs into Level_%d  [%s]" % [n + 1, n,
				world._room_before(next).name if world._room_before(next) else "nothing"])

	# 3. The outbound row must be untouched — it read correctly under BOTH
	#    orderings, which is exactly why the bug survived to room 13.
	for n in range(0, 11):
		var here := _room(world, "Level_%d" % n)
		var next := _room(world, "Level_%d" % (n + 1))
		if here == null or next == null:
			continue
		if world._room_after(here) != next:
			_check(false, "Level_%d still leads on to Level_%d" % [n, n + 1])
	_check(true, "the outbound row is unchanged, room 0 through room 11")

	# 4. The first room is still where the game opens.
	_check(world.rooms[0].name == "Level_0",
		"the world still starts at Level_0  [%s]" % world.rooms[0].name)

	if failures.is_empty():
		print("ROUTE ORDER TEST: ALL PASS")
	else:
		print("ROUTE ORDER TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _room(world: LdtkWorld, name: String) -> Node2D:
	for r in world.rooms:
		if r.name == name:
			return r
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
