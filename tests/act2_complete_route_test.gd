extends "res://tests/garden_connected_test.gd"
## One world from its first room to the completion card. Scripted real inputs,
## not a human playtest. Never injects positions, keys or story completion flags.
const COMPLETE_OUT := "res://output/act2_polish/complete_route"
var capture_dir := COMPLETE_OUT
var fruit_inventory: Array[Dictionary] = []
var visited: Array[String] = []
var stage := "opening"

func _ready() -> void:
	SaveGame.unbind()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): capture_dir = argument.trim_prefix("--output=")
	Game.completed = false
	LdtkWorld.debug_start_room = "Act_2_Level_0"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(30)
	world = Screen.current
	player = world.player
	room = world.current_room
	offset = room.global_position
	player.died.connect(func(): deaths += 1)
	world.room_changed.connect(record_room)
	visited.append(str(world.current_room.name))
	for candidate in world.rooms:
		for node in get_tree().get_nodes_in_group("lemon"):
			if node is Lemon and candidate.is_ancestor_of(node):
				fruit_inventory.append({"room":str(candidate.name), "id":node.collect_id(),
					"position":[node.global_position.x-candidate.global_position.x,
						node.global_position.y-candidate.global_position.y]})
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await connected_capture("start")
	var opening: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/opening_observed_route.json"))
	await commands(opening.commands)
	check(str(world.current_room.name) == "Level_2", "opening and real pond exit reach carpet lesson")
	check(world.story_flags.get("pond_dawn", false), "opening dialogue completion is earned")
	check(Collectibles.total == 1, "opening underwater reward banks through room changes")
	if failures:
		await finish_run()
		return
	stage = "carpet_lesson"
	# The fade runs on process time; a physics-frame recipe must start only
	# after controls return and the entrance landing has settled.
	for i in 240:
		if not world._transitioning and not player.input_locked and player.is_on_floor(): break
		await frames(1)
	print("LESSON ENTRY transition=",world._transitioning," locked=",player.input_locked," floor=",player.is_on_floor()," velocity=",player.velocity)
	var lesson: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/carpet_lesson_routes.json"))
	await commands([{"label":"flight", "steps":lesson.flight}])
	check(str(world.current_room.name) == "Act_2_Level_3", "lesson real exit reaches gardens")
	if failures:
		await finish_run()
		return
	stage = "gardens"
	continuous = true
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_expansion.json"))
	for recipe: Dictionary in recipes:
		room = world.current_room
		offset = room.global_position
		check(str(room.name) == recipe.name, "continuous arrival " + str(recipe.name))
		if failures: break
		used_climb = false
		player._ledge_cooldown = 3600.0
		expected_next = "Act_2_Level_%d" % (int(str(recipe.name).get_slice("_",3)) + 1)
		for i in recipe.routes.size():
			final_transfer = i == recipe.routes.size() - 1
			await run_step(recipe.routes[i])
			if failures: break
		if failures: break
		for i in 180:
			if _route_exit_started(): break
			Input.action_press("move_right")
			await frames(1)
		release()
		for i in 180:
			if str(world.current_room.name) == expected_next and not world._transitioning: break
			await frames(1)
		check(str(world.current_room.name) == expected_next, "actual garden exit to " + expected_next)
		check(not used_climb, "garden route requires no climb or land mantle")
		await connected_capture("arrival")
		if failures: break
	if failures:
		await finish_run()
		return
	stage = "castle"
	await walk_castle()
	if failures:
		await finish_run()
		return
	stage = "prison"
	await prison_mission()
	if failures:
		await finish_run()
		return
	stage = "chase"
	used_climb = false
	player._ledge_cooldown = 3600.0
	var chase: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/chase_continuous_route.json"))
	var forward: Array = []
	for command: Dictionary in chase.commands:
		if command.label == "wall_backtrack": break
		forward.append(command)
	await commands(forward)
	check(world.story_flags.get("wall_reunion", false), "friendly chase reaches its story endpoint")
	check(not used_climb, "chase route requires no climb or land mantle")
	if failures:
		await finish_run()
		return
	stage = "ending"
	# Each scene must see a released skip before a new deliberate hold. Ordinary
	# movement takes the adult from the waking pond to the final painted wall.
	for i in 12000:
		if Game.completed: break
		if Dialogue._conversation_owner != null:
			Input.action_release("move_right")
			Input.action_press("skip_dialogue")
		else:
			Input.action_release("skip_dialogue")
			if not player.input_locked: Input.action_press("move_right")
		# A following scene can open immediately after the previous scene closes.
		if i % 180 == 0: Input.action_release("skip_dialogue")
		await frames(1)
		if i % 180 == 1: Input.action_press("skip_dialogue")
		if i % 600 == 0: await connected_capture("ending_%d" % i)
	check(Game.completed and world.story_flags.get("act2_complete", false), "final poem and home complete Act 2")
	await finish_run()

func commands(sequence: Array) -> void:
	var alley_done := false
	for command: Dictionary in sequence:
		if stage == "chase" and command.label == "alley_low_path":
			var driver = load("res://tests/chase_alley_driver.gd").new()
			driver.world = world
			add_child(driver)
			check(await driver.traverse(), "supported alley jumps and actual pond exit")
			driver.queue_free()
			await connected_capture("alley_supported_jumps")
			if failures: return
			alley_done = true
			continue
		if alley_done and command.label in ["alley_rise","alley_variation","pond_entry"]: continue
		room = world.current_room
		offset = room.global_position
		print("COMPLETE INPUT ", stage, " ", JSON.stringify(command))
		for step: Dictionary in command.steps:
			for action: String in step.get("press", []): Input.action_press(action)
			for action: String in step.get("release", []): Input.action_release(action)
			await frames(int(step.frames))
			if stage == "carpet_lesson":
				print("LESSON STEP ",step," at=",player.global_position-offset," state=",player.state_name()," velocity=",player.velocity," transition=",world._transitioning)
		release()
		await connected_capture(str(command.label))
		if deaths > 0:
			check(false, "unplanned death during " + stage)
			return

func prison_mission() -> void:
	var navigator = load("res://tests/prison_navigation_test.gd").new()
	navigator.run_on_ready = false
	navigator.world = world
	add_child(navigator)
	player._ledge_cooldown = 3600.0
	var challenge=load("res://tests/prison_challenge_driver.gd").new()
	challenge.world=world
	challenge.capture_root=capture_dir+"/prison"
	add_child(challenge)
	check(await challenge.traverse(["Green","Red","Blue","Gold"]),"earned prison challenge loops: "+challenge.failure)
	check(not challenge.forbidden and challenge.deaths==0,"challenge traversal needs no climb/mantle and has no deaths")
	challenge.queue_free()
	if not failures:
		check(await navigator.navigate(Vector2(292,346)), "return to cage with earned keys")
		await frames(240)
		Input.action_press("skip_dialogue")
		await frames(150)
		Input.action_release("skip_dialogue")
		await frames(30)
		check(world.rescued and world.collected.size() == 4 and world.inserted.size() == 4,
			"four pickups unlock four cage locks")
		check(world.story_flags.get("cell_reunion",false), "cell scene reaches the courtyard invitation")
		check(await navigator.navigate(Vector2(64,346)), "walk to courtyard exit")
		Input.action_press("move_up")
		await frames(3)
		Input.action_release("move_up")
		await frames(90)
		check(str(world.current_room.name) == "Act_2_Level_16", "rescue courtyard leads to playable chase")
	check(not navigator.forbidden, "prison uses no climb or land mantle")
	navigator.queue_free()

func connected_capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	var stem := "%s_%s_%s" % [stage,world.current_room.name,label]
	Screen.viewport.get_texture().get_image().save_png(capture_dir + "/" + stem + ".png")
	get_tree().root.get_texture().get_image().save_png(capture_dir + "/" + stem + "_ui.png")
	print("COMPLETE CAPTURE ", stem, " at=",player.global_position-world.current_room.global_position," deaths=",deaths)

func finish_run() -> void:
	release()
	Input.action_release("skip_dialogue")
	check(deaths == 0, "one continuous forward run has zero unplanned deaths")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/hooshang_act2.ldtk"))
	for definition: Dictionary in source.levels:
		check(visited.has(str(definition.identifier)), "visited authored room " + str(definition.identifier))
	await connected_capture("final")
	var report := {"failures":failures,"stage":stage,"deaths":deaths,"visited":visited,
		"keys":world.collected,"locks":world.inserted,"story":world.story_flags,
		"lemons":Collectibles.total,"completed":Game.completed,
		"collected_fruit_ids":Collectibles.save_state().taken,"fruit_inventory":fruit_inventory}
	FileAccess.open(capture_dir + "/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COMPLETE ACT 2 ", JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func record_room(next: Node2D) -> void:
	visited.append(str(next.name))
	if stage in ["gardens", "castle", "prison", "chase"]:
		player._ledge_cooldown = 3600.0
