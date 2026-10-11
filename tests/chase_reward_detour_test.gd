extends "res://tests/act2_complete_route_test.gd"
## Continuous roof/alley/pond detours from a debug entrance, with real inputs.
## Ordinary scene skip is used; no story/fruit/position state is injected.
func _ready() -> void:
	SaveGame.unbind()
	capture_dir = "res://output/act2_polish/milestone3/chase_rewards"
	DirAccess.make_dir_recursive_absolute(capture_dir)
	LdtkWorld.debug_start_room = "Act_2_Level_16"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(30)
	world = Screen.current
	player = world.player
	room = world.current_room
	offset = room.global_position
	continuous = true
	player._ledge_cooldown = 3600.0
	player.died.connect(func(): deaths += 1)
	stage = "reward"
	var targets: Array[String] = []
	for candidate in world.rooms:
		if str(candidate.name) not in ["Act_2_Level_16","Act_2_Level_17","Act_2_Level_18"]: continue
		for fruit in get_tree().get_nodes_in_group("lemon"):
			if fruit is Lemon and candidate.is_ancestor_of(fruit) and not (str(candidate.name)=="Act_2_Level_18" and fruit.position.y>200):
				targets.append(fruit.collect_id())
	var chase: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/chase_continuous_route.json"))
	for command: Dictionary in chase.commands:
		if command.label == "alley_low_path": break
		await commands([command])
		if command.label == "second_roof_jump": await vertical_reward(448)
		if failures: break
	if failures == 0:
		room = world.current_room; offset = room.global_position
		var driver = load("res://tests/chase_alley_driver.gd").new()
		driver.world = world
		driver.before_exit = func(): await vertical_reward(528)
		add_child(driver)
		check(await driver.traverse(),"alley reward and real pond exit")
		driver.queue_free()
	if failures == 0:
		room = world.current_room; offset = room.global_position
		await jump_transfer({"kind":"dash","start":[96,184],"target":[176,160],"dash_up":true,"dash_frame":8})
		await connected_capture("pond_first_stone")
		if failures == 0: await jump_transfer({"kind":"jump","start":[192,160],"target":[248,144]})
		await connected_capture("pond_reward")
		if failures == 0: await vertical_reward(256)
		if failures == 0:
			Input.action_press("move_right")
			for i in 650:
				if str(world.current_room.name)=="Act_2_Level_19": break
				await frames(1)
			release()
			await frames(120)
	check(str(world.current_room.name)=="Act_2_Level_19","all three detours reach painted-wall room")
	check(deaths==0 and not used_climb,"no deaths, climb or land mantle")
	for id in targets: check(Collectibles.save_state().taken.has(id),"reward banked and retained " + id)
	await connected_capture("final")
	var result := {"failures":failures,"deaths":deaths,"used_climb":used_climb,
		"targets":targets,"banked":Collectibles.save_state().taken}
	FileAccess.open(capture_dir+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CHASE REWARDS ",JSON.stringify(result))
	get_tree().quit(0 if failures==0 else 1)

func vertical_reward(x: float) -> void:
	room = world.current_room; offset = room.global_position
	await prepare(Vector2(x,0))
	Input.action_press("jump")
	for i in 100:
		steer(x)
		await frames(1)
		if i==24: Input.action_release("jump")
		if i>8 and player.is_on_floor(): break
	release()
	await frames(40)
	await connected_capture("reward_jump")
