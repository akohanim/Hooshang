extends Node
## Direct play: -- Level_V10. Contact-sheet captures: -- --capture.
func _ready() -> void:
	SaveGame.slot=-1
	var args:=OS.get_cmdline_user_args()
	var capture:bool="--capture" in args
	LdtkWorld.debug_start_room="Level_V10" if args.is_empty() or capture else args[0]
	var world:LdtkWorld=load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await get_tree().process_frame
	world.player.has_dash=true
	if not capture:return
	world.player.set_physics_process(false)
	world.set_physics_process(false)
	for exit in get_tree().get_nodes_in_group("exit"):exit.set_deferred("monitoring",false)
	var camera:=world.player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled=false
	var shots:Dictionary={
		"Level_V10":Vector2(320,154),"Level_V11":Vector2(256,138),
		"Level_V12":Vector2(144,178),"Level_V13":Vector2(324,146),
		"Level_V14":Vector2(216,122),"Level_14":Vector2(520,162),
		"Level_15":Vector2(400,138),"Level_16":Vector2(328,146),
		"Level_17":Vector2(280,138),"Level_18":Vector2(180,154),
		"Level_19":Vector2(180,138),"Level_20":Vector2(180,138),
		"Level_21":Vector2(180,138),"Level_22":Vector2(180,138),
		"Level_23":Vector2(172,154),"Level_24":Vector2(184,130),
		"Level_0":Vector2(72,90),"Level_25":Vector2(120,90)}
	for name:String in shots:
		for room in world.rooms:
			if str(room.name)!=name:continue
			world._enter_room(room,false)
			world.get_node("Act1Beats").set_process(false)
			world.player.input_locked=true
			world.player.global_position=room.global_position+shots[name]
			if name=="Level_14":
				for shadow in get_tree().get_nodes_in_group("darkshang"):
					if room.is_ancestor_of(shadow):shadow.reveal()
			for i in 12:await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image:=Screen.viewport.get_texture().get_image()
			image.resize(1280,720,Image.INTERPOLATE_NEAREST)
			image.save_png("res://output/act1_expansion/%s.png" % name)
	get_tree().quit()
