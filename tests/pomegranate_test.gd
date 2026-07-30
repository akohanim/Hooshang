extends Node
## The pomegranate collectible: pickup, the global count, and the two things
## that are easy to get wrong — the total surviving a level change, and a taken
## fruit staying taken if the world is reloaded.
##
## The prefab is placed directly here rather than read from LDtk, because the
## levels deliberately contain none: they are authored by hand in the LDtk app.
## The LDtk -> node path itself lives in ldtk_entities_post_import.gd.
## Run:  godot --headless res://tests/pomegranate_test.tscn

const POM := preload("res://scenes/props/Pomegranate.tscn")

var failures: Array[String] = []
var world: LdtkWorld


func _ready() -> void:
	Collectibles.reset()
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	var p := world.player
	p.input_locked = false

	_check(Collectibles.total == 0, "starts empty")

	var pom: Area2D = POM.instantiate()
	pom.position = p.global_position + Vector2(0, -2)
	world.add_child(pom)
	await _frames(5)
	_check(pom.collision_layer == 8 and pom.collision_mask == 2,
		"sits on layer 4 'triggers' and masks the player only (%d/%d)"
			% [pom.collision_layer, pom.collision_mask])
	_check(pom.get_node("Sprite").sprite_frames.get_frame_count("spin") == 8,
		"spins through all 8 frames")
	var id: String = pom.collect_id()

	# Walk into it.
	p.global_position = pom.global_position
	await _frames(20)
	_check(Collectibles.total == 1, "picking one up banks it (total=%d)" % Collectibles.total)
	_check(Collectibles.is_taken(id), "the fruit is remembered as taken")
	await _frames(40)
	_check(not is_instance_valid(pom), "the node goes away after the pop")

	# The requirement: the count carries from level to level.
	Screen.load_scene("res://scenes/levels/act1_office/Level2.tscn")
	await _frames(40)
	_check(Collectibles.total == 1,
		"the total survives loading another level (total=%d)" % Collectibles.total)

	# Death must not refund or reset it either.
	world = Screen.load_scene("res://ldtk/Act1World.tscn")
	await _frames(60)
	world.player.die()
	await _frames(40)
	_check(Collectibles.total == 1, "dying does not cost you fruit (total=%d)" % Collectibles.total)

	# And the same fruit cannot be farmed by reloading the world it lives in.
	var again: Area2D = POM.instantiate()
	again.position = Vector2(120, 248)
	world.add_child(again)
	await _frames(10)
	var same: Area2D = POM.instantiate()
	same.global_position = Vector2(120, 248)
	world.add_child(same)
	await _frames(10)
	Collectibles.collect(again.collect_id())
	var after: int = Collectibles.total
	Collectibles.collect(again.collect_id())
	_check(Collectibles.total == after,
		"collecting the same fruit twice counts once (total=%d)" % Collectibles.total)

	if failures.is_empty():
		print("POMEGRANATE TEST: ALL PASS")
	else:
		print("POMEGRANATE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
