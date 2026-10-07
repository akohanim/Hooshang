extends Node

func _ready() -> void:
	SaveGame.slot = -1
	var world = load("res://ldtk/Act1World.tscn").instantiate()
	var beats = world.get_node("Act1Beats")
	world.remove_child(beats)
	beats.free()
	Screen.set_scene(world)
	await get_tree().process_frame
	world.player.set_physics_process(false)
	world.player.camera.position_smoothing_enabled = false
	var failures := 0
	var samples := 0
	for room in world.rooms:
		world._enter_room(room, true)
		var r: Rect2 = world.room_rect(room)
		var room_selection: Node = null
		var has_source := false
		for moon in get_tree().get_nodes_in_group("moon_candidates"):
			if moon.is_visible_in_tree() and not world._room_has_music_puzzle(room) and r.has_point(world.to_local(moon.global_position)):
				has_source = true
		for x in range(int(r.position.x + 16), int(r.end.x), 48):
			for y in range(int(r.position.y + 16), int(r.end.y), 64):
				world.player.global_position = Vector2(x, y)
				world.player.camera.reset_smoothing()
				world.player.camera.force_update_scroll()
				MoonVisibility.refresh()
				var selected := 0
				var active: Node = null
				for moon in get_tree().get_nodes_in_group("moon_candidates"):
					if moon.get_node("Core" if moon.has_node("Core") else "Moon").visible:
						selected += 1
						active = moon
				if selected != (1 if has_source else 0):
					failures += 1
				if room_selection != null and active != room_selection:
					failures += 1
				room_selection = active
				samples += 1
	# Future prefabs automatically participate, including a mixed old/new pair.
	var future = load("res://scenes/props/backdrop/MoonWindow.tscn").instantiate()
	world.add_child(future)
	future.global_position = world.player.global_position
	MoonVisibility.refresh()
	var count := 0
	for moon in get_tree().get_nodes_in_group("moon_candidates"):
		if moon.get_node("Core" if moon.has_node("Core") else "Moon").visible:
			count += 1
	if count != 1:
		failures += 1
	print("SINGLE MOON: %d camera positions, future prefab registration; %d failures" % [samples, failures])
	get_tree().quit(0 if failures == 0 else 1)
