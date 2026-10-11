extends Node
## Full rendered finale from a debug wall entry; not an act playthrough.
const OUT := "res://output/act2_polish/ending/captures"
func _ready() -> void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Act_2_Level_21" if OS.get_cmdline_user_args().has("--paint-only") else "Act_2_Level_19"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	DirAccess.make_dir_recursive_absolute(OUT)
	for i in 30:await get_tree().physics_frame
	var world=Screen.current
	world.player.respawn(world.current_room.global_position+Vector2(240,194))
	world.story_flags["wall_reunion"]=true
	var ending=world.get_node("Act2Ending")
	var last=""
	var count=0
	var release_captured := false
	var salute_captured := false
	var memories_captured := {}
	Engine.time_scale=3
	for tick in 30000:
		await get_tree().process_frame
		if ending._shown:break
		var memory = ending.get_node("Cinema/Stage/Memory")
		if memory.is_visible_in_tree() and not memories_captured.has(memory.current):
			memories_captured[memory.current] = true
			await get_tree().process_frame
			RenderingServer.force_draw()
			Screen.viewport.get_texture().get_image().save_png(OUT+"/memory_"+memory.current+"_native.png")
			get_viewport().get_texture().get_image().save_png(OUT+"/memory_"+memory.current+"_ui.png")
		if ending.jamshid_saluting and not salute_captured:
			salute_captured = true
			RenderingServer.force_draw()
			Screen.viewport.get_texture().get_image().save_png(OUT+"/jamshid_salute_native.png")
			get_viewport().get_texture().get_image().save_png(OUT+"/jamshid_salute_ui.png")
		if ending.releasing_hand and ending.get_node("Cinema/Stage/Flight/Child").frame >= 3 and not release_captured:
			release_captured = true
			await get_tree().process_frame
			RenderingServer.force_draw()
			Screen.viewport.get_texture().get_image().save_png(OUT+"/hand_release_native.png")
			get_viewport().get_texture().get_image().save_png(OUT+"/hand_release_ui.png")
		if world.story_flags.get("pond_return",false) and not ending.playing:Input.action_press("move_right")
		else:Input.action_release("move_right")
		if not Dialogue._active:continue
		if last!=str(Dialogue._generation)+":"+Dialogue._page_raw:
			last=str(Dialogue._generation)+":"+Dialogue._page_raw
			Dialogue._finish_reveal_instantly()
			await get_tree().process_frame
			RenderingServer.force_draw()
			if ending.line_index in {"carpet":[0,3,19,22,28,33,50,51,56],"second_line":[0,3,16,31,37],"paint":[38,39,40]}.get(ending.chapter,[]):
				var stem=OUT+"/%s_%02d"%[ending.chapter,ending.line_index]
				Screen.viewport.get_texture().get_image().save_png(stem+"_native.png")
				get_viewport().get_texture().get_image().save_png(stem+"_ui.png")
			print("ENDING LINE ",count," ",ending.chapter," ",ending.line_index," ",Dialogue._page_raw)
			count+=1
		Dialogue.line_finished.emit()
	Input.action_release("move_right")
	Engine.time_scale=1
	await get_tree().process_frame
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(OUT+"/complete_ui.png")
	print("ENDING PREVIEW completed=",ending._shown," lines=",count)
	get_tree().quit(0 if ending._shown else 1)
