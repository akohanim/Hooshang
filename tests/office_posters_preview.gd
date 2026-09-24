extends Node
## Capture each of the first ten rooms at native resolution, including wide rooms.
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_0"
	var world = load("res://ldtk/Act1World.tscn").instantiate()
	var beats = world.get_node("Act1Beats")
	world.remove_child(beats)
	beats.free()
	Screen.set_scene(world)
	await get_tree().process_frame
	Screen.viewport.get_parent().stretch = false
	world.player.set_physics_process(false)
	world.player.input_locked = true
	world.player.camera.position_smoothing_enabled = false
	var suffix := "before" if "before" in OS.get_cmdline_user_args() else "after"
	var out := "res://output/office_posters/" + suffix
	DirAccess.make_dir_recursive_absolute(out)
	var manifest := {}
	for room in world.rooms.slice(0, 10):
		var notices: Array = []
		var dressing = room.get_node_or_null("OfficePosters")
		if dressing != null:
			for poster in dressing.get_children():
				notices.append({"slogan": poster.SLOGANS[poster.design],
					"paper_style": poster.paper_style,
					"position": [poster.position.x, poster.position.y],
					"size": [poster.paper_size.x, poster.paper_size.y]})
		manifest[str(room.name)] = notices
		world._enter_room(room, true)
		var rect: Rect2 = world.room_rect(room)
		Screen.viewport.size = Vector2i(rect.size)
		world.player.global_position = rect.get_center()
		world.player.camera.reset_smoothing()
		for frame in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = Screen.viewport.get_texture().get_image()
		image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
		image.save_png(out + "/" + str(room.name) + ".png")
		print("captured ", room.name)
	var file := FileAccess.open(out + "/placements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	get_tree().quit()
