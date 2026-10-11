extends "res://tests/act2_complete_route_test.gd"
## Entrance, spring stair reward and onward exit using movement inputs only.
func _ready() -> void:
	SaveGame.unbind()
	capture_dir = "res://output/act2_polish/milestone3/meadow_reward"
	DirAccess.make_dir_recursive_absolute(capture_dir)
	LdtkWorld.debug_start_room = "Act_2_Level_0"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(30)
	world = Screen.current; player = world.player; room = world.current_room; offset = room.global_position
	continuous = true
	player._ledge_cooldown = 3600.0
	player.died.connect(func(): deaths += 1)
	stage = "meadow_reward"
	var target_id := ""
	for fruit in get_tree().get_nodes_in_group("lemon"):
		if fruit is Lemon and room.is_ancestor_of(fruit) and fruit.position.y<100: target_id = fruit.collect_id()
	var opening: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/opening_observed_route.json"))
	await commands(opening.commands.slice(0,2))
	var targets := [228.0,276.0,308.0,308.0,340.0,388.0,420.0]
	var index := 0
	var previous_vy := player.velocity.y
	for i in 1800:
		steer(targets[mini(index,targets.size()-1)])
		await frames(1)
		if player.velocity.y < -250 and previous_vy >= 0:
			print("SPRING CHAIN ",index," at=",player.global_position-offset)
			index += 1
			await connected_capture("spring_%d" % index)
		previous_vy = player.velocity.y
		if index >= targets.size() and Collectibles.save_state().taken.has(target_id): break
		if deaths: break
	release()
	check(index >= targets.size(),"all seven spring contacts reached")
	await connected_capture("high_reward")
	if failures == 0:
		Input.action_press("move_right")
		for i in 900:
			if str(world.current_room.name)=="Act_2_Level_1": break
			await frames(1)
		release()
		await frames(150)
	check(str(world.current_room.name)=="Act_2_Level_1","spring detour uses actual pond exit")
	check(Collectibles.save_state().taken.has(target_id),"high reward banked and retained")
	check(deaths==0 and not used_climb,"no deaths, climb or land mantle")
	await connected_capture("final")
	var result := {"failures":failures,"deaths":deaths,"used_climb":used_climb,"target":target_id,"banked":Collectibles.save_state().taken}
	FileAccess.open(capture_dir+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("MEADOW REWARD ",JSON.stringify(result))
	get_tree().quit(0 if failures==0 else 1)
