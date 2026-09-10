extends Node
## Art review, preserving authored lights and using the chase's earned glow.
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_0"
	var world = load("res://ldtk/Act1World.tscn").instantiate()
	var beats = world.get_node("Act1Beats")
	var glow_rooms: Array = beats.glow_rooms.duplicate()
	world.remove_child(beats)
	beats.free()
	Screen.set_scene(world)
	await get_tree().process_frame
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.input_locked = true
	world.player.collision_layer = 0
	world.player.camera.position_smoothing_enabled = false
	DirAccess.make_dir_recursive_absolute("res://output/act1_office/all_rooms")
	var selected := OS.get_cmdline_user_args()
	for room in world.rooms:
		if not selected.is_empty() and not selected.has(str(room.name)):
			continue
		await get_tree().process_frame
		print("entering ", room.name)
		world._enter_room(room, true)
		var rect: Rect2 = world.room_rect(room)
		world.player.global_position = rect.get_center()
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		await get_tree().process_frame
		if glow_rooms.has(int(str(room.name).trim_prefix("Level_"))):
			world.player.grant_glow()
		print("settling ", room.name)
		for frame in 12:
			await get_tree().process_frame
		await save(str(room.name))
		if str(room.name) == "Level_14":
			for suffix in ["", "B"]:
				var moon = world.get_node("Backdrop/MoonWindowRoom14" + suffix)
				moon.eclipse(1.5, world.get_node("Lights/MoonGlowRoom14" + suffix))
			await get_tree().create_timer(0.85).timeout
			await save("Level_14_totality")
			await get_tree().create_timer(0.8).timeout
			await save("Level_14_blood")
	get_tree().quit()

func save(label: String) -> void:
	MoonVisibility.refresh()
	RenderingServer.force_draw(false)
	var image: Image = Screen.viewport.get_texture().get_image()
	image.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	image.save_png("res://output/act1_office/all_rooms/%s.png" % label)
	print("captured ", label)
