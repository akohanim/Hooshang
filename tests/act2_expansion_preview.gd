extends Node
## Save-free playable entry. -- --capture produces actual game-view frames.
func _ready() -> void:
	SaveGame.slot = -1
	var args := OS.get_cmdline_user_args()
	var capture := "--capture" in args
	LdtkWorld.debug_start_room = "Act_2_Level_3" if args.is_empty() or capture else args[0]
	Screen.load_scene("res://ldtk/Act2World.tscn")
	for i in 12: await get_tree().process_frame
	var world := Screen.current as LdtkWorld
	world.player.has_dash = true
	if not capture:return
	world.player.set_physics_process(false)
	world.set_physics_process(false)
	world.player.camera.position_smoothing_enabled = false
	for node in get_tree().get_nodes_in_group("exit"):node.set_deferred("monitoring",false)
	for room in world.rooms:
		if not str(room.name).begins_with("Act_2_Level_") or int(str(room.name).get_slice("_",3))<3:continue
		world._enter_room(room,false)
		var views: Array[Vector2] = [Vector2(160,230),Vector2(340,164),Vector2(520,100)]
		if room.name=="Act_2_Level_7":views.append(Vector2(680,112))
		for view in views:
			for node in room.get_node("Entities").get_children():
				if node is MagicCarpet:
					node.set_physics_process(false)
					node.position=node._origin
			var layer := room.get_node("Collisions") as TileMapLayer
			var best: Vector2 = view
			var score := INF
			for cell in layer.get_used_cells():
				if layer.get_cell_source_id(cell+Vector2i.UP)!=-1:continue
				var at := Vector2(cell.x*8+4,cell.y*8-6)
				var distance := absf(at.x-view.x)+absf(at.y-view.y)*0.7
				if distance<score:score=distance;best=at
			world.player.global_position = room.global_position+best
			world.player.camera.reset_smoothing()
			for i in 8:await get_tree().process_frame
			RenderingServer.force_draw()
			var frame := Screen.viewport.get_texture().get_image()
			frame.resize(1280,720,Image.INTERPOLATE_NEAREST)
			frame.save_png("res://output/act2_expansion/%s_%d.png" % [room.name,int(view.x)])
	get_tree().quit()
