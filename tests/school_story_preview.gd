extends Node
## Rendered staging inspection from debug entries, not a movement playthrough.
const OUT := "res://output/act2_polish/milestone1/story_captures"
const PAINT := preload("res://tests/room14_painting_driver.gd")
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act_2_Level_14"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	DirAccess.make_dir_recursive_absolute(OUT)
	for i in 30: await get_tree().physics_frame
	var world := Screen.current
	var wall: Node
	var palace: Node
	for node in world.current_room.get_node("Entities").get_children():
		if not node.has_method("play_scene"): continue
		if node.chapter == "wall": wall = node
		else: palace = node
	world.player.global_position = wall.global_position + Vector2(70,-6)
	Engine.time_scale = 4
	var last := ""
	var count := 0
	var moved := false
	var painting_ready_ticks := 0
	var captured_officer := {}
	for i in 10000:
		await get_tree().physics_frame
		if wall.painting_game.active:
			if wall.painting_game.areas.count(true) == 3: painting_ready_ticks += 1
			PAINT.drive(wall, painting_ready_ticks > 20)
			if painting_ready_ticks == 10:
				RenderingServer.force_draw()
				Screen.viewport.get_texture().get_image().save_png(OUT+"/painting_native.png")
				get_viewport().get_texture().get_image().save_png(OUT+"/painting_ui.png")
			continue
		PAINT.release()
		if wall.finished and not moved:
			moved = true
			world.player.global_position = palace.global_position + Vector2(70,-6)
		if palace.finished: break
		if not Dialogue._active: continue
		if Dialogue._page_raw != last:
			last = Dialogue._page_raw
			Dialogue._finish_reveal_instantly()
			await get_tree().process_frame
			RenderingServer.force_draw()
			if count in [0,4,16,20,23,27,28]:
				Screen.viewport.get_texture().get_image().save_png(OUT+"/%02d_native.png"%count)
				get_viewport().get_texture().get_image().save_png(OUT+"/%02d_ui.png"%count)
				print("CAPTURE ",count," ",last)
			var portrait_key: String = Dialogue.portrait.texture.resource_path.get_file().get_basename() if Dialogue.portrait.texture != null else ""
			if portrait_key.begins_with("officer_") and not captured_officer.has(portrait_key):
				for tick in 12: await get_tree().process_frame
				RenderingServer.force_draw()
				get_viewport().get_texture().get_image().save_png(OUT+"/"+portrait_key+"_ui.png")
				captured_officer[portrait_key] = true
			count += 1
		Dialogue.line_finished.emit()
	Engine.time_scale = 1
	print("STORY CAPTURE END wall=",wall.finished," palace=",palace.finished," lines=",count)
	get_tree().quit()
