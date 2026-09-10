extends Node
## Regression: play order is the LEVEL IDENTIFIER, not where the room sits.
##
## The escape row (14-22) runs RIGHT to left across the bottom of the LDtk grid,
## so sorting rooms by world position reads it 22, 21, 20 … 15, 14 — backwards.
## Every "next room" fallback in ldtk_world.gd is "the next entry in that array",
## so walking out of Level_16's Exit handed you Level_15: the room you had just
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
	# NOT "every room carries a number" — TEST and Level_V_test are real,
	# deliberately unnumbered scratch rooms (see check 4 below), so a plain
	# count would fail forever on their account. Whether the NUMBERED ones are
	# complete and gapless is exactly what check 3's curated-chain comparison
	# already pins, more precisely than a count could.

	# 2. The specific reversal that was reported. Checked by NAME rather than by
	#    index so the assertion still means something when rooms are added.
	for n in range(13, 22):
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

	# 3. The curated chain: 0..6, then the whole V1..V7 block, then the escape
	#    row 14..25 — Level_7..13 are SHELVED (LdtkWorld.SHELVED_ROOMS) and must
	#    not appear at all. This array is not a cosmetic listing: no Exit in the
	#    .ldtk carries a NextRoom override — checked directly, every one is empty
	#    — so it is the ONLY thing that routes actual play. Get it wrong and the
	#    game does not misnumber a menu, it dead-ends (a rename to Level_V6/V7
	#    once left V5/V6/V7 in the sort-last bucket, routing 6->V1..V4 then
	#    nowhere; see INSERTED_ROOMS).
	var expected: Array[String] = []
	for n in range(0, 7):
		expected.append("Level_%d" % n)
	for v in range(1, 15):
		expected.append("Level_V%d" % v)
	for n in range(14, 26):
		expected.append("Level_%d" % n)

	var have_names: Array[String] = []
	for r in world.rooms:
		have_names.append(r.name)
	# Filtered both ways to the rooms that actually exist in this checkout, so
	# the assertion is about RELATIVE order and survives a room being added or
	# still mid-build rather than demanding all of them be present.
	var present := expected.filter(func(n: String) -> bool: return have_names.has(n))
	var got := have_names.filter(func(n: String) -> bool: return present.has(n))
	_check(got == present,
		"the curated chain comes out in order  [%s]" % " ".join(got))

	# 3b. The shelved rooms are genuinely gone from the route (not merely last).
	for n in range(7, 14):
		_check(not have_names.has("Level_%d" % n),
			"Level_%d is shelved and off the play route" % n)

	# 4. Scratch rooms (no recorded place in the chain) sort AFTER it, not into
	#    the middle of it.
	var last_curated := have_names.find("Level_25")
	for name in ["Level_V_test", "TEST"]:
		if have_names.has(name):
			_check(have_names.find(name) > last_curated,
				"%s sorts after the curated chain, not into it  [position %d, chain ends at %d]"
					% [name, have_names.find(name), last_curated])

	# 5. The first room is still where the game opens.
	_check(world.rooms[0].name == "Level_0",
		"the world still starts at Level_0  [%s]" % world.rooms[0].name)

	# 6. Identifier ordering isn't special-cased to Act 1's bare "Level_N"
	#    names. Act 2 and Act 3 rooms are prefixed to stay unique across the
	#    importer's one shared ldtk/levels/ folder (Act_2_Level_3, Act3_Level_0
	#    — CLAUDE.md's "prefixed uniquely" rule) and used to silently fall into
	#    the "sort last" bucket, because index_in_name() only matched a name
	#    that BEGAN WITH "Level_" — exactly the bug this file exists to catch,
	#    just triggered by an Act prefix instead of a right-to-left grid. Pure
	#    string logic against the function under test; no Act 2/3 world needed.
	_check(LdtkWorld.index_in_name("Act_2_Level_3") == 300,
		"Act_2_Level_3 orders the same as a bare Level_3 would  [%d]"
			% LdtkWorld.index_in_name("Act_2_Level_3"))
	_check(LdtkWorld.index_in_name("Act3_Level_0") == 0,
		"Act3_Level_0 orders the same as a bare Level_0 would  [%d]"
			% LdtkWorld.index_in_name("Act3_Level_0"))
	_check(LdtkWorld.index_in_name("Act_2_Level_10") > LdtkWorld.index_in_name("Act_2_Level_2"),
		"Act_2_Level_10 still sorts after Act_2_Level_2, not lexicographically before it  [%d vs %d]"
			% [LdtkWorld.index_in_name("Act_2_Level_10"), LdtkWorld.index_in_name("Act_2_Level_2")])

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
