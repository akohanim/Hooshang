extends Node

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_0"
	var world = load("res://ldtk/Act1World.tscn").instantiate()
	# Review the art after the opening fade, without triggering conversations.
	var beats = world.get_node("Act1Beats")
	world.remove_child(beats)
	beats.free()
	Screen.set_scene(world)
	await get_tree().process_frame
	world.player.set_physics_process(false)
	world.player.input_locked = true
	world.player.camera.position_smoothing_enabled = false
	DirAccess.make_dir_recursive_absolute("res://output/act1_office")
	for i in 10:
		var room = world.rooms.filter(func(r): return str(r.name) == "Level_%d" % i)[0]
		world._enter_room(room, true)
		var rect: Rect2 = world.room_rect(room)
		world.player.global_position = rect.get_center()
		world.player.camera.reset_smoothing()
		for frame in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = Screen.viewport.get_texture().get_image()
		image.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		image.save_png("res://output/act1_office/level_%d.png" % i)
		print("captured Level_", i)
	get_tree().quit()
