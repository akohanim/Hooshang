extends Node
## Default is a save-free playable run. -- --capture records the real game view.
func _ready()->void:
	SaveGame.slot=-1
	var args:=OS.get_cmdline_user_args()
	var capture:bool="--capture" in args
	LdtkWorld.debug_start_room="Level_V10" if args.is_empty() or capture else args[0]
	var world:LdtkWorld=load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 8:await get_tree().process_frame
	world.player.has_dash=true
	if not capture:return
	world.player.set_physics_process(false)
	world.set_physics_process(false)
	world.get_node("Act1Beats").set_process(false)
	for exit in get_tree().get_nodes_in_group("exit"):exit.set_deferred("monitoring",false)
	var camera:=world.player.camera
	camera.position_smoothing_enabled=false
	var configs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	DirAccess.make_dir_recursive_absolute("res://output/darkshang_redesign/views")
	for config:Dictionary in configs:
		for room in world.rooms:
			if room.name!=config.name:continue
			world._enter_room(room,false)
			var chamber:=room.get_node("DarknessRoom")
			chamber.set_physics_process(false)
			chamber.phase=2;chamber.presence=1;chamber.committed=true
			chamber.manifestation.set("presence",1.0)
			world.get_node("CanvasModulate").color=world._ambient_color if chamber.e.mode=="security" else Color(.13,.15,.2)
			var r:Array=config.route[1]
			world.player.global_position=room.global_position+Vector2(r[0]+r[2]/2,r[1]-6)
			if chamber.e.has("attacks"):
				chamber.attack_wait=0
				chamber._attack(world.player.global_position-room.global_position,.01)
				chamber.manifestation.set("warning",true)
			chamber.queue_redraw()
			camera.reset_smoothing()
			for i in 12:await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var frame:=Screen.viewport.get_texture().get_image()
			frame.resize(1280,720,Image.INTERPOLATE_NEAREST)
			frame.save_png("res://output/darkshang_redesign/views/%s.png" % config.name)
	get_tree().quit()
