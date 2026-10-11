extends Node
## Rendered staging inspection from debug entries, not a movement playthrough.
const OUT := "res://output/act2_polish/milestone1/story_captures"
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
	for i in 10000:
		await get_tree().process_frame
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
			count += 1
		Dialogue.line_finished.emit()
	Engine.time_scale = 1
	print("STORY CAPTURE END wall=",wall.finished," palace=",palace.finished," lines=",count)
	get_tree().quit()
