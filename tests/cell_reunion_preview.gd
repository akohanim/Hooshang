extends Node
## Rendered dialogue staging from a debug rescue; not a four-key playthrough.
const OUT := "res://output/act2_polish/rescue/reunion"
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Prison_Hub"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	DirAccess.make_dir_recursive_absolute(OUT)
	for i in 30: await get_tree().physics_frame
	var world := Screen.current
	var story := world.get_node("CellReunion")
	for id in world.IDS:
		world.collected.append(id)
		world.inserted.append(id)
	world.finish_rescue()
	world.player.respawn(world._cage.get_parent().get_node("PrisonJamshid").global_position+Vector2(-40,-6))
	var last := ""
	var count := 0
	for i in 10000:
		await get_tree().process_frame
		if story.finished: break
		if not Dialogue._active: continue
		if Dialogue._page_raw != last:
			last = Dialogue._page_raw
			Dialogue._finish_reveal_instantly()
			await get_tree().process_frame
			RenderingServer.force_draw()
			Screen.viewport.get_texture().get_image().save_png(OUT+"/%02d_native.png"%count)
			get_viewport().get_texture().get_image().save_png(OUT+"/%02d_ui.png"%count)
			print("CAPTURE ", count, " ", last)
			count += 1
		Dialogue.line_finished.emit()
	for i in 30: await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/endpoint_native.png")
	print("REUNION CAPTURE END finished=",story.finished," lines=",count)
	get_tree().quit()
