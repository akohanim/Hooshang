extends Node
## Real imported prison paint, the prison physics override, and a complete
## death/respawn. The immunity control proves the paint caused the death.
var failures := 0
var deaths := 0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Prison_R01"
	var world: LdtkWorld = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	world.set_physics_process(false)
	var player := world.player
	player.set_physics_process(false)
	player.died.connect(func(): deaths += 1)
	var room := world.current_room
	var checkpoint := world._checkpoint
	var layer := world._thought_layer
	check(layer != null and not layer.get_used_cells().is_empty(), "actual prison contains painted thought hazards")
	if layer == null or layer.get_used_cells().is_empty():
		get_tree().quit(1)
		return
	var geo := room.get_node("PrisonGeometry")
	var found := false
	for cell in layer.get_used_cells():
		player.global_position = layer.to_global(layer.map_to_local(cell)) + Vector2(0, -9)
		if world._in_thought_tile() and not geo.hazard_overlaps(player.hitbox_rect()):
			found = true
			break
	check(found, "body edge touches real paint with the center outside and no other hazard")
	if found:
		player._mushroom_power_timer = 2.0
		world._physics_process(1.0 / 60.0)
		check(player.state != Player.State.DEAD and deaths == 0, "thought immunity prevents death at the same contact")
		player._mushroom_power_timer = 0.0
		world._physics_process(1.0 / 60.0)
		check(player.state == Player.State.DEAD and deaths == 1, "paint contact kills through the actual prison physics loop")
		for i in 120:
			await get_tree().physics_frame
			if player.state != Player.State.DEAD: break
		check(player.state != Player.State.DEAD and player.global_position.distance_to(checkpoint) < 0.1,
			"death automatically respawns at the room checkpoint")
		player.invulnerable_timer = 0.0
		for i in 10: world._physics_process(1.0 / 60.0)
		check(deaths == 1 and world.current_room == room, "safe respawn stays in the room without a death loop")
	world.queue_free()
	await get_tree().process_frame
	print("ACT2 PAINTED HAZARD RESPAWN: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
