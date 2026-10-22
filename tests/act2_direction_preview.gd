extends Node
## Rendered creative review. Debug entries stage scenes; this is not route proof.
const PAINT := preload("res://tests/room14_painting_driver.gd")
var out := "res://output/act2_direction_review"
var mode := "pond"
var world: LdtkWorld
var records: Array[Dictionary] = []

func _ready() -> void:
	SaveGame.unbind()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(out+"/"+mode)
	LdtkWorld.debug_start_room = {"pond":"Act_2_Level_1", "wall":"Act_2_Level_14", "rescue":"Prison_Hub", "keys":"Prison_Hub", "banter":"Act_2_Level_16", "reunion":"Act_2_Level_19", "ending":"Act_2_Level_19", "rooms":"Act_2_Level_0"}.get(mode,"Act_2_Level_0")
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(30)
	world = Screen.current
	if mode == "rooms":
		await rooms()
		finish(true)
		return
	var director: Node
	var palace: Node
	match mode:
		"pond":
			director = world.get_node("Act2Beats")
			world.player.global_position = director._speaker.trigger_region.get_center()
		"wall":
			for node in world.current_room.get_node("Entities").get_children():
				if node.has_method("play_scene"):
					if node.chapter == "wall": director = node
					else: palace = node
			world.player.respawn(director.global_position+Vector2(70,-6))
		"rescue":
			director = world.get_node("CellReunion")
			for id in world.IDS:
				world.collected.append(id)
				world.inserted.append(id)
			world.finish_rescue()
			world.player.respawn(world._cage.get_parent().get_node("PrisonJamshid").global_position+Vector2(-40,-6))
		"keys":
			director = world.get_node("CellReunion")
			world.collected.assign(world.IDS)
		"banter", "reunion":
			director = world.current_room.get_node("ChaseRoom")
			world.get_node("Act2Ending").set_physics_process(false)
			world.player.respawn(world.current_room.global_position+Vector2(90 if mode=="banter" else 240,194))
		"ending":
			director = world.get_node("Act2Ending")
			world.player.respawn(world.current_room.global_position+Vector2(240,194))
			world.story_flags["wall_reunion"] = true
	Engine.time_scale = 3
	var last := ""
	var page := 0
	var milestones := {}
	var success := false
	for tick in 60000:
		await get_tree().process_frame
		if mode=="wall" and director.painting_game.active:
			PAINT.drive(director,true)
			continue
		PAINT.release()
		if mode=="ending":
			if world.story_flags.get("pond_return",false) and not director.playing: Input.action_press("move_right")
			else: Input.action_release("move_right")
			var memory = director.get_node("Cinema/Stage/Memory")
			if memory.is_visible_in_tree() and not milestones.has(memory.current):
				milestones[memory.current]=true
				await capture("memory_"+memory.current)
			if director.releasing_hand and director.get_node("Cinema/Stage/Flight/Child").frame>=3 and not milestones.has("release"):
				milestones.release=true
				await capture("hand_release")
		if Dialogue._active:
			var key := str(Dialogue._generation)+":"+Dialogue._page_raw
			if key != last:
				last=key
				Dialogue._finish_reveal_instantly()
				await frames(3)
				await capture("page_%03d"%page)
				page+=1
			Dialogue.line_finished.emit()
		match mode:
			"pond": success = bool(world.story_flags.get("pond_dawn",false))
			"wall":
				if director.finished and not palace.finished and not palace.playing:
					world.player.respawn(palace.global_position+Vector2(70,-6))
				success=palace.finished
			"rescue": success=director.finished
			"keys": success=bool(world.story_flags.get("keys_found",false))
			"banter": success=bool(world.story_flags.get("chase_banter",false))
			"reunion": success=bool(world.story_flags.get("wall_reunion",false))
			"ending": success=director._shown
		if success: break
	Input.action_release("move_right")
	Engine.time_scale=1
	await frames(5)
	await capture("endpoint")
	finish(success)

func capture(stem: String) -> void:
	await RenderingServer.frame_post_draw
	Screen.viewport.get_texture().get_image().save_png(out+"/"+mode+"/"+stem+"_native.png")
	get_viewport().get_texture().get_image().save_png(out+"/"+mode+"/"+stem+"_ui.png")
	var player := world.player
	var feet := player.hitbox_rect().end.y
	var query := PhysicsRayQueryParameters2D.create(Vector2(player.global_position.x,feet-0.1),Vector2(player.global_position.x,feet+256),1,[player.get_rid()])
	var hit := player.get_world_2d().direct_space_state.intersect_ray(query)
	var ground_gap: float = hit.position.y-feet if not hit.is_empty() else -1.0
	var record := {"capture":stem,"room":str(world.current_room.name),"text":Dialogue._page_raw if Dialogue._active else "", "speaker":Dialogue.name_label.text if Dialogue._active else "", "player":[player.global_position.x-world.current_room.global_position.x,player.global_position.y-world.current_room.global_position.y],"ground_gap":ground_gap,"animation":str(player.visual.animation),"facing":player.facing}
	records.append(record)
	print("STAGING ",JSON.stringify(record))

func rooms() -> void:
	for node in world.find_children("*","Node",true,false):
		if node.has_method("play_scene") or node.name in ["Act2Beats","Act2Ending","CellReunion"] or str(node.name)=="ChaseRoom": node.set_physics_process(false)
	world.player.freeze()
	world.player.camera.enabled=false
	var camera := Camera2D.new()
	world.add_child(camera)
	camera.make_current()
	for room in world.rooms:
		world._enter_room(room,true)
		world.player.freeze()
		world.player.camera.enabled=false
		camera.make_current()
		var rect := world.room_rect(room)
		var centers := [world.spawn_point_for(room), rect.get_center()]
		for i in centers.size():
			camera.global_position=Vector2(clampf(centers[i].x,rect.position.x+160,rect.end.x-160),clampf(centers[i].y,rect.position.y+90,rect.end.y-90))
			camera.reset_smoothing()
			await frames(3)
			await capture(str(room.name)+"_%d"%i)

func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame

func finish(success: bool) -> void:
	FileAccess.open(out+"/"+mode+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":mode,"completed":success,"records":records},"\t"))
	print("DIRECTION PREVIEW ",mode," completed=",success," captures=",records.size())
	get_tree().quit(0 if success else 1)
