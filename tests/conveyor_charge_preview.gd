extends Node
## Save-free playable preview; --capture records both forms at native resolution.
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_19"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--room="):
			LdtkWorld.debug_start_room = argument.trim_prefix("--room=")
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 20: await get_tree().process_frame
	world.player.has_dash = true
	if not "--capture" in OS.get_cmdline_user_args(): return
	var room := world.current_room
	world.player.set_physics_process(false)
	world.player.global_position = room.global_position + Vector2(world.room_rect(room).size.x - 186,170)
	world.player.camera.position_smoothing_enabled = false
	var boss := get_tree().get_first_node_in_group("darkshang") as Darkshang
	boss.reparent(world)
	boss.set_physics_process(false)
	boss.buffer.set_physics_process(false)
	boss._holding_entry = false
	boss.show()
	boss.modulate = Color.WHITE
	boss.global_position = room.global_position + Vector2(world.room_rect(room).size.x - 106,170)
	var visual: Node2D = boss._visual
	DirAccess.make_dir_recursive_absolute("res://output/conveyor19")
	visual.set_process(false)
	world.player.camera.force_update_scroll()
	boss.global_position = boss.charge_hover_position()
	boss._push_visual()
	var cloud = visual.get_node("Body/Cloud")
	cloud.set_process(false)
	cloud.float_amplitude = 0.0
	for label in ["cloud", "storm", "transition", "charge", "reveal"]:
		visual.set_humanoid(label in ["transition", "charge"])
		visual.set_motion(0 if label in ["cloud", "storm"] else 2, Vector2(-190,0))
		cloud.age = 0.0 if label == "cloud" else 1.5
		cloud._process(0.0)
		visual._process(visual.form_transition_time/2 if label == "transition" else visual.form_transition_time)
		if label == "reveal":
			visual.begin_cloud_transition(1.25)
			visual._process(.65)
		for i in 10: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := Screen.viewport.get_texture().get_image()
		img.resize(1280,720,Image.INTERPOLATE_NEAREST)
		img.save_png("res://output/conveyor19/%s.png" % label)
	get_tree().quit()
