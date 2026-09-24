extends Node
## Save-free gameplay; --capture also records each complete room at native pixels.
func _ready()->void:
	SaveGame.slot=-1
	var args:=OS.get_cmdline_user_args()
	if "--capture" in args:
		var configs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
		for config:Dictionary in configs:
			if not config.get("precision_escape",false):continue
			var viewport:=SubViewport.new()
			viewport.size=Vector2i(config.width,config.height)
			viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			add_child(viewport)
			var room:Node2D=load("res://ldtk/levels/hooshang_act1/%s.scn" % config.name).instantiate()
			room.position=Vector2.ZERO;viewport.add_child(room)
			var ambient:=CanvasModulate.new();ambient.color=Color(.20,.22,.29);viewport.add_child(ambient)
			var player:Player=load("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
			viewport.add_child(player);player.set_physics_process(false);player.camera.enabled=false
			player.position=Vector2(config.route[0][0]+config.route[0][2]-24,config.route[0][1]-6)
			for f in 12:await get_tree().process_frame
			RenderingServer.force_draw()
			var image:=viewport.get_texture().get_image()
			image.resize(config.width*2,config.height*2,Image.INTERPOLATE_NEAREST)
			image.save_png("res://output/precision_escape/%s.png" % config.name)
			viewport.queue_free();await get_tree().process_frame
		get_tree().quit();return
	LdtkWorld.debug_start_room=args[0] if not args.is_empty() and not args[0].begins_with("--") else "Level_15"
	var world:LdtkWorld=load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for f in 8:await get_tree().process_frame
	world.player.has_dash=true

	if "--game-capture" in args:
		world.player.set_physics_process(false)
		world.player.camera.position_smoothing_enabled=false
		for exit in get_tree().get_nodes_in_group("exit"):exit.set_deferred("monitoring",false)
		var recipes:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
		for recipe:Dictionary in recipes:
			if not recipe.get("precision_escape",false):continue
			for room in world.rooms:
				if room.name!=recipe.name:continue
				world._enter_room(room,false)
				var at:Array=recipe.route[3 if recipe.route.size()>4 else 1]
				world.player.global_position=room.global_position+Vector2(at[0]+at[2]/2,at[1]-6)
				world.player.camera.reset_smoothing()
				for f in 15:await get_tree().process_frame
				RenderingServer.force_draw()
				var image:=Screen.viewport.get_texture().get_image()
				image.resize(1280,720,Image.INTERPOLATE_NEAREST)
				image.save_png("res://output/precision_escape/%s_game.png" % recipe.name)
		get_tree().quit()
