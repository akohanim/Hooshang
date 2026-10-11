extends "res://tests/garden_connected_test.gd"
## Debug entrance to real onward exit. Detours alter only input recipes, never
## geometry, player position/velocity, collectible state or carpet speed.
var out_dir := ""
var inventory: Array[Dictionary] = []

func _ready() -> void:
	SaveGame.unbind()
	var args := OS.get_cmdline_user_args()
	var number := int(args[0]) if not args.is_empty() else 4
	var name_wanted := "Act_2_Level_%d" % number
	out_dir = "res://output/act2_polish/milestone3/detours/" + name_wanted
	DirAccess.make_dir_recursive_absolute(out_dir)
	LdtkWorld.debug_start_room = name_wanted
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(30)
	world = Screen.current
	player = world.player
	room = world.current_room
	offset = room.global_position
	continuous = true
	player._ledge_cooldown = 3600.0
	player.died.connect(func(): deaths += 1)
	for node in get_tree().get_nodes_in_group("lemon"):
		if node is Lemon and room.is_ancestor_of(node):
			inventory.append({"id":node.collect_id(),"position":str(node.global_position-offset)})
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_expansion.json"))
	var recipe: Dictionary
	for entry: Dictionary in recipes:
		if entry.name == name_wanted: recipe = entry.duplicate(true)
	match number:
		4: recipe.routes[4].merge({"dash_up":true,"dash_frame":8},true)
		6: recipe.routes[3].waypoints = [[480,98],[520,112]]
		7:
			recipe.routes[4].waypoints = [[552,122],[584,136]]
			recipe.routes[4].jump_x = 608
		8: recipe.routes[1].waypoints = [[304,138],[336,184]]
		12: recipe.routes[7].merge({"dash_up":true,"dash_frame":8},true)
		10: recipe.routes[1].reward_lanes = [[330,392,190],[536,616,190]]
		13:
			recipe.routes[1].merge({"dash_up":true,"dash_frame":8},true)
			recipe.routes[3].reward_lanes = [[552,624,174]]
	expected_next = "Act_2_Level_%d" % (number+1)
	await connected_capture("entrance")
	for i in recipe.routes.size():
		final_transfer = i == recipe.routes.size()-1
		if (number == 8 and i == 2) or (number == 7 and i == 5): await frames(180) # Let the abandoned rug clear the next landing.
		await run_step(recipe.routes[i])
		await connected_capture("step_%02d" % i)
		if failures: break
	if failures == 0:
		for i in 180:
			if _route_exit_started(): break
			Input.action_press("move_right")
			await frames(1)
		release()
		for i in 180:
			if str(world.current_room.name) == expected_next and not world._transitioning: break
			await frames(1)
	check(str(world.current_room.name) == expected_next and not world._transitioning,"detour uses real onward exit")
	check(deaths == 0 and not used_climb,"no deaths, climb or land mantle")
	var banked: Array[String] = []
	for fruit in inventory:
		if Collectibles.save_state().taken.has(fruit.id): banked.append(fruit.id)
	check(banked.size() == inventory.size(),"all room fruit banked and retained: %d/%d" % [banked.size(),inventory.size()])
	await connected_capture("final")
	var report := {"room":name_wanted,"failures":failures,"deaths":deaths,"used_climb":used_climb,
		"inventory":inventory,"banked":banked,"recipe":recipe.routes}
	FileAccess.open(out_dir+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GARDEN REWARD DETOUR ",JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func connected_capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	get_tree().root.get_texture().get_image().save_png(out_dir+"/"+label+"_ui.png")
	print("REWARD CAPTURE ",label," at=",player.global_position-world.current_room.global_position," lemons=",Collectibles.total)
