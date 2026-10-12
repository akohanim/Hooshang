extends Node
var failures := 0
func check(ok: bool, text: String) -> void:
	print(('PASS ' if ok else 'FAIL ')+text)
	if not ok: failures += 1
func _ready() -> void:
	SaveGame.dir = "user://_test_chapter_browser"
	var menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu._rows[0].text == "EXPLORE CHAPTERS","browser available without a save")
	menu.choose()
	check(menu.page == MainMenu.Page.CHAPTERS,"three-chapter entry")
	check(menu._rows.size()==3,"all three acts available")
	for act in 3:
		menu._show_explore(act)
		var holder = load("res://ldtk/Act%dWorld.tscn" % (act+1)).instantiate()
		var packed = holder.world_scene.instantiate()
		var rooms = LdtkWorld.rooms_in(packed)
		check(menu._rows.size()==rooms.size(),"catalog matches imported act %d" % (act+1))
		for room in rooms:
			check(menu._catalog[act].any(func(r): return r.id==str(room.name)),"room available: "+str(room.name))
		packed.free()
		holder.free()
		menu._move(menu._rows.size()-1)
		check(menu.selected==menu._rows.size()-1,"last room scrolls into view")
		menu.back()
		check(menu.page==MainMenu.Page.CHAPTERS,"back returns to chapters")
	menu._show_explore(1)
	menu._move(2)
	var remembered: int = menu.selected
	menu._show_explore(0)
	menu._show_explore(1)
	check(menu.selected == remembered,"switching chapters remembers room selection")
	if "--capture" in OS.get_cmdline_user_args():
		menu.show_root()
		await shot("title")
		menu._show_chapters()
		await shot("chapters")
		menu._show_explore(1)
		menu._move(25-menu.selected)
		await shot("rooms")
	menu.queue_free()
	print("CHAPTER BROWSER: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
func shot(label: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://output/menu")
	get_viewport().get_texture().get_image().save_png("res://output/menu/%s.png" % label)
