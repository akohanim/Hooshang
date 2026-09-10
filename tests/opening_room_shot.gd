extends Node
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_0"
	var world = load("res://ldtk/Act1World.tscn").instantiate()
	var beats = world.get_node("Act1Beats")
	world.remove_child(beats)
	beats.free()
	Screen.set_scene(world)
	await get_tree().process_frame
	world.player.input_locked = true
	world.player.camera.position_smoothing_enabled = false
	for frame in 90:
		await get_tree().process_frame
	MoonVisibility.refresh()
	print("Room: ", world.current_room.name)
	await RenderingServer.frame_post_draw
	var img = Screen.viewport.get_texture().get_image()
	img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	img.save_png("res://output/opening_room.png")
	print("Opening room captured")
	get_tree().quit()
