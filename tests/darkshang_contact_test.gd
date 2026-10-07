extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_14"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	var beats := world.get_node("Act1Beats")
	world.remove_child(beats); beats.free()
	Screen.set_scene(world)
	await get_tree().process_frame
	await get_tree().process_frame
	world.set_physics_process(false)
	var player := world.player
	var boss := get_tree().get_first_node_in_group("darkshang") as Darkshang
	boss.set_physics_process(false)
	boss.buffer.set_physics_process(false)
	player.set_physics_process(false)
	check(boss.catch_size == Vector2(40,64) and boss.catch_offset == Vector2(0,-28), "Level 14 absorption covers the enlarged torso")
	var origin := world.current_room.global_position + Vector2(300, 80)
	for direction: float in [-1.0, 1.0]:
		boss.stop_chase()
		player.respawn(origin + Vector2(-70 * direction, -28))
		player.input_locked = false
		boss.global_position = origin
		boss.visible = true
		boss._grace_timer = 0
		boss._holding_entry = false
		boss._contact_ready = false
		boss._physics_process(1.0/60.0)
		check(boss.state == Darkshang.State.DORMANT, "separation does not absorb")
		# A whole dash-sized crossing between samples, with neither endpoint overlapping.
		player.state = Player.State.DASH
		player.global_position = origin + Vector2(70 * direction, -28)
		boss._physics_process(1.0/60.0)
		check(boss.state == Darkshang.State.CAUGHT and player.input_locked and boss._owed_death == player, "dash crossing in either direction starts ingestion immediately")
		boss.stop_chase()
	# Real dash updates, starting above the former feet-only box.
	player.respawn(origin + Vector2(-35,-38))
	player.input_locked = false
	player.has_dash = true
	boss.global_position = origin
	boss.visible = true
	boss._grace_timer = 0
	boss._holding_entry = false
	boss._contact_ready = false
	boss._physics_process(1.0/60.0)
	player._try_dash(Vector2.RIGHT, true)
	for i in 12:
		player._physics_process(1.0/60.0)
		boss._physics_process(1.0/60.0)
		if boss.state == Darkshang.State.CAUGHT: break
	check(boss.state == Darkshang.State.CAUGHT, "real dash into torso is absorbed")
	boss.stop_chase()
	player.respawn(origin + Vector2(100,0))
	boss._grace_timer = 0
	boss._holding_entry = false
	boss._contact_ready = false
	boss.global_position = origin
	boss._physics_process(1.0/60.0)
	player.global_position = origin + Vector2(-100,0)
	boss._contact_ready = false # the reset/teleport path must discard the old segment
	boss._physics_process(1.0/60.0)
	check(boss.state != Darkshang.State.CAUGHT, "teleports do not create phantom crossings")
	check(not Darkshang._segment_hits_catch(Vector2(-40,0),Vector2(0,-40),Rect2(-10,-10,20,20)), "diagonal near miss stays safe")
	world.get_node("ChasePacing")._arrive(world.rooms[0])
	check(boss.catch_size == Vector2(12,16) and boss.catch_offset == Vector2.ZERO and not boss.absorb_on_reveal, "other rooms restore ordinary pursuit size")
	print("DARKSHANG CONTACT: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
