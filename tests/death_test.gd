extends Node
## One death per respawn, whatever killed him.
##
## Guards a bug that was invisible until the counter existed: hazard deaths were
## counted TWICE. Death disabled Hooshang's collision shape and respawn
## re-enabled it, and re-adding a shape to an Area2D's broadphase made the
## hazard fire `body_entered` again about 25 frames after the respawn, with him
## standing 20px clear of it. He was alive again by then, so die()'s "already
## DEAD" guard couldn't catch it — nothing short of the phantom not happening
## would have.
##
## The kill plane never doubled, which is why this needs both paths: whatever
## replaces the fix has to keep them agreeing.
## Run:  godot --headless res://tests/death_test.tscn

var failures: Array[String] = []
var world: LdtkWorld


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	await _frames(20)
	var player := world.player
	player.input_locked = true  # no stray input walking him back in

	# --- a hazard, the path that used to count twice ---
	var hazard := Hazard.new()
	hazard.size = Vector2(16, 16)
	hazard.global_position = player.global_position + Vector2(20, 0)
	world.add_child(hazard)
	await _frames(5)

	Deaths.reset()
	player.global_position = hazard.global_position
	await _frames(10)
	_check(Deaths.total == 1, "touching a hazard counts one death (%d)" % Deaths.total)
	_check(player.collision_layer == 0,
		"the corpse is off the detection layer, so nothing can kill it again (%d)"
			% player.collision_layer)

	# Long enough to cover the respawn AND the window the phantom used to land in.
	await _frames(90)
	_check(player.state != Player.State.DEAD, "he respawns")
	_check(player.collision_layer != 0, "and is detectable again (%d)" % player.collision_layer)
	_check(Deaths.total == 1,
		"still one death a full second after respawning — no phantom re-entry (%d)"
			% Deaths.total)
	_check(player.global_position.distance_to(hazard.global_position) > 8.0,
		"he is clear of the hazard, so a second death here would be bogus")

	# --- the kill plane, which always counted correctly ---
	Deaths.reset()
	player.global_position = Vector2(player.global_position.x, 900.0)
	await _frames(100)
	_check(Deaths.total == 1, "falling out of the world counts one death (%d)" % Deaths.total)

	# --- and dying twice really is two ---
	Deaths.reset()
	player.die()
	await _frames(90)
	player.die()
	await _frames(90)
	_check(Deaths.total == 2, "two separate deaths count two (%d)" % Deaths.total)

	if failures.is_empty():
		print("DEATH TEST: ALL PASS")
	else:
		print("DEATH TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(ok: bool, msg: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
