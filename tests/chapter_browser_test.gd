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
			# The map lays rooms out from the catalog, so a room moved in LDtk
			# without re-running tools/build_menu_catalog.py lands in the wrong place.
			var entry = menu._catalog[act].filter(func(r): return r.id==str(room.name))
			if not entry.is_empty():
				check(Vector2(entry[0].pos[0],entry[0].pos[1]).is_equal_approx(room.position),"map position matches world: "+str(room.name))
		packed.free()
		holder.free()
		menu._move(menu._rows.size()-1)
		check(menu.selected==menu._rows.size()-1,"last room scrolls into view")
		menu.back()
		check(menu.page==MainMenu.Page.CHAPTERS,"back returns to chapters")
	await check_map(menu)
	menu._show_explore(1)
	menu._move(2)
	var remembered: int = menu.selected
	menu._show_explore(0)
	menu._show_explore(1)
	check(menu.selected == remembered,"switching chapters remembers room selection")
	if "--capture" in OS.get_cmdline_user_args():
		# Deaf to the real pointer: wherever it rests over the window, a hover on
		# the map would select that room and the shot would show the wrong one.
		menu.set_process_input(false)
		menu.show_root()
		await shot("title")
		menu._show_chapters()
		await shot("chapters")
		menu._show_explore(1)
		menu._move(25-menu.selected)
		menu._map.snap()
		await shot("rooms")
		menu._show_explore(0)
		menu._move(9-menu.selected)
		menu._map.snap()
		await shot("map_act1")
	menu.queue_free()
	print("CHAPTER BROWSER: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
## The world map: it opens on the selected room, a hover selects in place, a tap
## on another room selects and follows, a drag pans without choosing, the wheel
## zooms, and the overview inset jumps across the Act.
func check_map(menu) -> void:
	menu._show_explore(0)
	menu._move(4-menu.selected)
	menu._map.snap()
	var map = menu._map
	check(map.visible and not menu._hero.visible,"explore shows the world map")
	check(map.selected==4,"map selection follows the list")
	check(map.room_rect(4).get_center().distance_to(map.size*0.5) < 1.0,"camera centres the selected room")
	check(map.room_at(map.room_rect(4).get_center())==4,"room under the cursor is found")
	var neighbour := 5 if map.room_rect(5).intersects(Rect2(Vector2.ZERO,map.size)) else 3
	var target: Vector2 = map._target_center
	map.mouse(motion(map.room_rect(neighbour).get_center()),map.room_rect(neighbour).get_center())
	check(menu.selected==neighbour,"hovering a room on the map selects it")
	check(map._target_center==target,"a hover does not pan the map")
	var far := 20
	menu._move(4-menu.selected)
	map.snap()
	var at: Vector2 = map.room_rect(4).get_center()
	map.mouse(button(MOUSE_BUTTON_LEFT,true),at)
	map.mouse(motion(at+Vector2(40,0)),at+Vector2(40,0))
	map.mouse(button(MOUSE_BUTTON_LEFT,false),at+Vector2(40,0))
	check(menu.selected==4 and map._pan.x < -30.0,"dragging pans without choosing")
	var zoom: float = map._target_zoom
	map.mouse(button(MOUSE_BUTTON_WHEEL_UP,true),at)
	check(map._target_zoom > zoom,"wheel zooms the map")
	menu._move(far-menu.selected)
	map.snap()
	var inset: Rect2 = map._inset_rect()
	var other := -1
	var spot := Vector2.ZERO
	for i in map._rects.size():
		var shown: Rect2 = map.room_rect(i).intersection(Rect2(Vector2.ZERO,map.size).grow(-8))
		if i != menu.selected and shown.get_area() > 64.0 and not inset.has_point(shown.get_center()):
			other = i
			spot = shown.get_center()
			break
	check(other >= 0,"neighbouring rooms show around the selected one")
	if other >= 0:
		map.mouse(button(MOUSE_BUTTON_LEFT,true),spot)
		map.mouse(button(MOUSE_BUTTON_LEFT,false),spot)
		check(menu.selected==other and map._target_center.is_equal_approx(map._rects[other].get_center()),"a tap selects a room and follows it")
	var corner := inset.position+Vector2(7,7)
	map.mouse(button(MOUSE_BUTTON_LEFT,true),corner)
	map.mouse(button(MOUSE_BUTTON_LEFT,false),corner)
	check(menu.selected==map._inset_pick(corner) and map._target_center.is_equal_approx(map._rects[menu.selected].get_center()),"the overview inset jumps to a room")
	menu._show_explore(1)
	check(map.selected==menu.selected and map._rects.size()==menu._catalog[1].size(),"switching chapter loads that Act's map")
	await get_tree().process_frame

func motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event

func button(index: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	return event

func shot(label: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://output/menu")
	get_viewport().get_texture().get_image().save_png("res://output/menu/%s.png" % label)
