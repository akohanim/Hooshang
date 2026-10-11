extends Node
## Rendered scene playback from two debug entries; no route traversal claim.
const OUT := "res://output/act2_polish/chase/story_captures"
func _ready() -> void:
	SaveGame.slot=-1
	DirAccess.make_dir_recursive_absolute(OUT)
	for number in [16,19]:
		LdtkWorld.debug_start_room="Act_2_Level_%d"%number
		Screen.load_scene("res://ldtk/Act2World.tscn")
		for i in 30:await get_tree().physics_frame
		var world=Screen.current
		world.get_node("Act2Ending").queue_free()
		world.player.respawn(world.current_room.global_position+Vector2(90 if number==16 else 240,194))
		var flag="chase_banter" if number==16 else "wall_reunion"
		var last=""
		var count=0
		for tick in 10000:
			await get_tree().process_frame
			if world.story_flags.get(flag,false):break
			if not Dialogue._active:continue
			if last!=Dialogue._page_raw:
				last=Dialogue._page_raw
				Dialogue._finish_reveal_instantly()
				await get_tree().process_frame
				RenderingServer.force_draw()
				Screen.viewport.get_texture().get_image().save_png(OUT+"/%d_%02d_native.png"%[number,count])
				get_viewport().get_texture().get_image().save_png(OUT+"/%d_%02d_ui.png"%[number,count])
				print("CAPTURE ",number," ",count," ",last)
				count+=1
			Dialogue.line_finished.emit()
		print("CHASE STORY CAPTURE ",number," endpoint=",world.story_flags.get(flag,false)," lines=",count)
	get_tree().quit()
