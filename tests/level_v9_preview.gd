extends Node
## Launch directly for play, or pass -- --capture for native-resolution views.
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_V9"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await get_tree().process_frame
	world.player.has_dash = true
	if not "--capture" in OS.get_cmdline_user_args():
		return
	world.player.set_physics_process(false)
	var camera := world.player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	var points := [Vector2(152, 278), Vector2(424, 186), Vector2(464, 60)]
	for i in points.size():
		world.player.global_position = world.current_room.global_position + points[i]
		for frame in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := Screen.viewport.get_texture().get_image()
		image.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		image.save_png("res://output/level_v9/view_%d.png" % i)
	get_tree().quit()
