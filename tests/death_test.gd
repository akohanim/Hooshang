extends Node
## One death per respawn, whatever killed him.
##
## Every Hazard actually placed in the LDtk world is walked into, one at a time.
## That breadth is the point, and it is why this test exists in this shape: an
## earlier version stood up a Hazard of its own with Hazard.new(), which did NOT
## reproduce the bug, so a fix that changed nothing in the real game looked
## verified. Hazards as the game builds them — instanced from Hazard.tscn by the
## LDtk import, sitting inside a room — are the only ones worth asserting on.
##
## THE BUG. Death disabled Hooshang's collision and respawn re-enabled it.
## Taking a body out of an Area2D's detection and putting it back makes that area
## fire `body_entered` again at the position it was removed from — so every spike
## killed him a second time ~25 frames after he respawned, 200px away. He is
## alive by then, so die()'s "already DEAD" guard cannot catch it. Toggling
## `collision_layer` instead has the identical fault; the fix is to never remove
## him at all.
##
## The kill plane never doubled, which is why both paths are checked: they have
## to keep agreeing.
## Run:  godot --headless res://tests/death_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var player: Player


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	await _frames(20)
	player = world.player
	player.input_locked = true  # no stray input walking him back in

	var hazards: Array[Node] = []
	_collect(world, hazards)
	_check(hazards.size() > 0, "the world has hazards to test (%d)" % hazards.size())

	var doubled: Array[String] = []
	for h in hazards:
		var hz: Hazard = h
		world._enter_room(_room_holding(hz), true)
		await _frames(10)
		Deaths.reset()
		player.global_position = hz.global_position
		# Long enough to cover the respawn AND the window the phantom landed in.
		await _frames(120)
		if Deaths.total != 1:
			doubled.append("%s in %s counted %d" % [
				hz.global_position, _room_holding(hz).name, Deaths.total])
	_check(doubled.is_empty(),
		"every hazard counts exactly one death  %s" % ("" if doubled.is_empty() else doubled))

	# --- the kill plane, which always counted correctly ---
	Deaths.reset()
	player.global_position = Vector2(player.global_position.x, 900.0)
	await _frames(120)
	_check(Deaths.total == 1, "falling out of the world counts one death (%d)" % Deaths.total)

	# --- the corpse stays put, which is what makes leaving collision on safe ---
	Deaths.reset()
	var resting := player.global_position
	player.die()
	await _frames(5)
	_check(player.global_position == resting,
		"a dead player does not move, so it cannot enter anything new")
	await _frames(120)

	# --- and two real deaths really are two ---
	Deaths.reset()
	player.die()
	await _frames(120)
	player.die()
	await _frames(120)
	_check(Deaths.total == 2, "two separate deaths count two (%d)" % Deaths.total)

	if failures.is_empty():
		print("DEATH TEST: ALL PASS")
	else:
		print("DEATH TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _collect(n: Node, out: Array[Node]) -> void:
	if n is Hazard:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _room_holding(n: Node) -> Node2D:
	var p := n.get_parent()
	while p != null:
		if world.rooms.has(p):
			return p
		p = p.get_parent()
	return world.current_room


func _check(ok: bool, msg: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
