extends Node
func _ready() -> void:
	SaveGame.slot = -1
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	var beats := world.get_node("Act1Beats")
	world.remove_child(beats); beats.free()
	Screen.set_scene(world)
	await get_tree().process_frame
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.input_locked = true
	world.player.camera.position_smoothing_enabled = false
	DirAccess.make_dir_recursive_absolute("res://output/window_placement")
	for name in ["Level_0", "Level_13", "Level_14", "Level_26"]:
		var room: Node2D
		for candidate in world.rooms:
			if str(candidate.name) == name: room = candidate
		world._enter_room(room, true)
		world.player.global_position = room.global_position + Vector2(160 if name != "Level_14" else 332, 100)
		world.player.camera.force_update_scroll()
		for i in 8: await get_tree().process_frame
		MoonVisibility.refresh()
		await RenderingServer.frame_post_draw
		var image := Screen.viewport.get_texture().get_image()
		image.resize(1280,720,Image.INTERPOLATE_NEAREST)
		image.save_png("res://output/window_placement/%s.png" % name)
	print("WINDOW PREVIEW: four rooms captured")
	get_tree().quit()
