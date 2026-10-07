extends Node
func _ready() -> void:
	SaveGame.unbind()
	var world: Node = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_Hub"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("Prison_"): world.debug_start_room = arg
	Screen.set_scene(world)
	await get_tree().create_timer(1).timeout
	if "--capture-all" in OS.get_cmdline_user_args():
		for room in world.rooms:
			if not world.is_prison(room): continue
			world._enter_room(room,true)
			world.player.respawn(world.spawn_point_for(room))
			await get_tree().create_timer(0.1).timeout
			await capture(world)
		get_tree().quit()
	elif "--capture" in OS.get_cmdline_user_args():
		await capture(world)
		get_tree().quit()
func capture(world: Node) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var folder := "res://output/prison_build/previews"
	DirAccess.make_dir_recursive_absolute(folder)
	image.save_png(folder+"/"+str(world.current_room.name)+".png")
