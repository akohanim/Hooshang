extends Node
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func _ready() -> void:
	SaveGame.slot = -1
	var lab = load("res://scenes/levels/material_lab/MaterialLab.tscn").instantiate()
	Screen.set_scene(lab)
	for i in 90:
		await get_tree().physics_frame
	var solids: TileMapLayer = lab.room.get_node("Solids-values")
	check(solids.get_used_cells().size() > 80, "Solid IntGrid missing")
	check(lab.player.is_on_floor(), "Player does not stand on imported geometry")
	check(Screen.viewport.size == Vector2i(320,180), "Wrong world viewport")
	check(Screen.viewport.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "Filtering not nearest")
	for child in lab.room.get_children():
		if child is TileMapLayer and child != solids:
			check(not child.collision_enabled, "Decorative layer collides")
	check(lab.room.get_node("BrickArt").get_used_cells().size() > 20, "Missing brick art")
	check(lab.room.get_node("ConcreteArt").get_used_cells().size() > 10, "Missing concrete art")
	check(lab.room.get_node("Props").get_child_count() == 8, "Props missing or placeholders remain")
	var bg: TileMapLayer = lab.room.get_node("BackgroundArt")
	check(bg.get_cell_source_id(Vector2i(11,4)) == -1, "Background window filled")
	lab.set_graybox(true)
	check(solids.visible and not lab.room.get_node("BrickArt").visible, "Graybox failed")
	var before: Vector2 = lab.player.position
	Input.action_press("jump")
	for i in 8:
		await get_tree().physics_frame
	Input.action_release("jump")
	check(lab.player.position.y < before.y - 4, "Cannot jump in graybox")
	lab.set_graybox(false)
	if "--capture" in OS.get_cmdline_user_args():
		for i in 80:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img = Screen.viewport.get_texture().get_image()
		img.save_png("res://ldtk/material_lab/preview.png")
	print("MATERIAL LAB: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
