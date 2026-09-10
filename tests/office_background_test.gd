extends Node

func _ready() -> void:
	SaveGame.slot = -1
	var world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await get_tree().process_frame
	var failures := 0
	var expected_moons := [1, 1, 1, 1, 1, 1, 1, 0, 0, 0]
	for i in 10:
		var room = world.rooms.filter(func(r): return str(r.name) == "Level_%d" % i)[0]
		var panel = room.get_node("RoomBackdrop")
		var checks := [panel is TextureRect, panel.texture.get_size() == world.room_rect(room).size,
			panel.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, panel.material is ShaderMaterial if i < 7 else panel.material == null]
		var old = room.get_node_or_null("BG Image")
		checks.append(old == null or not old.visible)
		world._enter_room(room, true)
		checks.append(world.get_node("CanvasModulate").color == (Color.BLACK if i >= 7 else world._ambient_color))
		checks.append(panel.get_child_count() == expected_moons[i])
		for moon in panel.get_children():
			checks.append(moon.get_node("Pool").enabled == (moon.get_node("Core").visible and moon._pool_active))
			checks.append((moon.get_node("Core").texture.get_size() * moon.get_node("Core").scale).is_equal_approx(Vector2(16, 16)))
			checks.append(moon.get_node("Halo").material is ShaderMaterial)
		for other in world.rooms:
			if other != room:
				for moon in other.get_node("RoomBackdrop").get_children():
					checks.append(not moon.get_node("Pool").enabled)
		for ok in checks:
			if not ok:
				failures += 1
		print("office background Level_%d: %s" % [i, checks])
	print("office background failures: ", failures)
	get_tree().quit(1 if failures else 0)
