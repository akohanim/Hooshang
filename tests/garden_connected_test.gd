extends "res://tests/act2_routes_test.gd"
## One real-input run from garden entrance through eleven actual exits into the
## castle approach. No per-room position writes, fixture respawns or exit disable.
const CONNECTED_OUT := "res://output/act2_polish/garden_connected"
var expected_next := ""
var final_transfer := false
var entered: Array[String] = []

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act_2_Level_3"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(30)
	world = Screen.current as LdtkWorld
	player = world.player
	player.died.connect(func(): deaths += 1)
	continuous = true
	DirAccess.make_dir_recursive_absolute(CONNECTED_OUT)
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_expansion.json"))
	check(player.has_dash, "garden entry naturally has the dash ability")
	for recipe: Dictionary in recipes:
		room = world.current_room
		offset = room.global_position
		check(str(room.name) == recipe.name, "real arrival at " + str(recipe.name))
		if failures: break
		entered.append(str(room.name))
		await connected_capture("arrival")
		used_climb = false
		# Acceptance excludes the optional land assist; physics are otherwise live.
		player._ledge_cooldown = 3600.0
		expected_next = "Act_2_Level_%d" % (int(str(recipe.name).get_slice("_",3)) + 1)
		for i in recipe.routes.size():
			final_transfer = i == recipe.routes.size() - 1
			await run_step(recipe.routes[i])
			if failures: break
		if failures: break
		# Some endpoints stand just short of the Area. Walk through it normally.
		for i in 180:
			if _route_exit_started(): break
			Input.action_press("move_right")
			await frames(1)
		release()
		for i in 180:
			if str(world.current_room.name) == expected_next and not world._transitioning: break
			await frames(1)
		check(str(world.current_room.name) == expected_next and not world._transitioning,
			"actual exit " + str(recipe.name) + " -> " + expected_next)
		check(deaths == 0, "connected route has no deaths")
		check(not used_climb, "connected room uses no climb or land mantle")
		if failures: break
	check(entered.size() == 11 and str(world.current_room.name) == "Act_2_Level_14",
		"all eleven garden rooms connect to the castle approach")
	await connected_capture("castle_arrival" if failures == 0 else "failure")
	if failures == 0: await walk_castle()
	if failures == 0: await retry_and_return()
	print("GARDEN CONNECTED: ", failures, " failures; rooms=", entered, "; deaths=", deaths)
	get_tree().quit(0 if failures == 0 else 1)

func _route_exit_started() -> bool:
	if not final_transfer: return false
	return str(world.current_room.name) == expected_next or (world._transitioning
		and world.transition_target != null and str(world.transition_target.name) == expected_next)

func connected_capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	var stem := str(world.current_room.name) + "_" + label
	Screen.viewport.get_texture().get_image().save_png(CONNECTED_OUT + "/" + stem + ".png")
	var record := {"room": str(world.current_room.name), "label": label,
		"local_position": player.global_position - world.current_room.global_position,
		"deaths": deaths, "input_locked": player.input_locked, "checkpoint": world._checkpoint}
	print("CONNECTED CAPTURE ", JSON.stringify(record))

## Follow the forgiving courtyard floor, jumping only when a step stops forward
## movement. Use the ordinary held skip action; no story flags are injected.
func walk_castle() -> void:
	var previous_x := player.global_position.x
	var stopped_frames := 0
	var jump_frames := 0
	var last_room := ""
	for i in 2400:
		var name_now := str(world.current_room.name)
		if name_now != last_room:
			last_room = name_now
			room = world.current_room
			offset = room.global_position
			player._ledge_cooldown = 3600.0
			await connected_capture("castle_walk")
		if name_now == "Prison_Hub" and not world._transitioning: break
		if player.input_locked:
			release()
			if not world._transitioning: Input.action_press("skip_dialogue")
		else:
			Input.action_release("skip_dialogue")
			Input.action_press("move_right")
			if player.is_on_floor() and absf(player.global_position.x - previous_x) < 0.1:
				stopped_frames += 1
			else: stopped_frames = 0
			if stopped_frames >= 8 and jump_frames == 0:
				Input.action_press("jump")
				jump_frames = 40
				stopped_frames = 0
			if jump_frames > 0:
				jump_frames -= 1
				if jump_frames == 0: Input.action_release("jump")
		previous_x = player.global_position.x
		await frames(1)
	release()
	Input.action_release("skip_dialogue")
	check(str(world.current_room.name) == "Prison_Hub", "walked approach and gatehouse into assembly hall")
	check(bool(world.story_flags.get("wall",false)) and bool(world.story_flags.get("palace",false)),
		"both approach encounters complete through real skip input")
	check(not player.input_locked, "assembly hall arrival restores control")
	check(deaths == 0 and not used_climb, "castle approach has no death, climb or land mantle")
	await connected_capture("assembly_hall" if failures == 0 else "castle_failure")

func retry_and_return() -> void:
	var saved_flags: Dictionary = world.story_flags.duplicate(true)
	var checkpoint := world._checkpoint
	await frames(60) # Let the normal doorway arrival immunity expire.
	player.die() # Deliberate retry, separate from the zero-death forward route.
	await frames(100)
	check(str(world.current_room.name) == "Prison_Hub" and deaths == 1
		and player.is_on_floor() and player.global_position.distance_to(checkpoint) < 2,
		"assembly-hall death restores its own supported checkpoint once")
	check(world.story_flags == saved_flags, "approach story progress survives retry")
	room = world.current_room
	offset = room.global_position
	player._ledge_cooldown = 3600.0
	# The redesigned courtyard door is one low jump above the entrance floor.
	for i in 360:
		if i==0:Input.action_press("jump")
		if i==40:Input.action_release("jump")
		steer(64.0)
		await frames(1)
		if absf(player.global_position.x-offset.x-64) < 2 and absf(player.velocity.x) < 8 and player.is_on_floor() and player.global_position.y-offset.y<352: break
	release()
	Input.action_press("move_up")
	await frames(3)
	Input.action_release("move_up")
	await frames(90)
	check(str(world.current_room.name) == "Act_2_Level_15", "walked to courtyard door and used Up")
	if failures: return
	await connected_capture("courtyard_return")
	checkpoint = world._checkpoint
	await frames(60)
	player.die()
	await frames(100)
	# Return placement clears the door trigger above its floor. A normal retry
	# falls to supported ground; checkpoint height is not the settled foot height.
	check(str(world.current_room.name) == "Act_2_Level_15" and deaths == 2
		and player.is_on_floor() and absf(player.global_position.x-checkpoint.x) < 2
		and world._checkpoint == checkpoint and not player.input_locked,
		"gatehouse return checkpoint survives one death without bouncing rooms")
	player._ledge_cooldown = 3600.0
	for i in 900:
		if str(world.current_room.name) == "Act_2_Level_14": break
		Input.action_press("move_left")
		if i % 60 == 0: Input.action_press("jump")
		if i % 60 == 40: Input.action_release("jump")
		await frames(1)
	release()
	await frames(90)
	check(str(world.current_room.name) == "Act_2_Level_14" and not player.input_locked,
		"walked back through the gatehouse's actual return exit")
	check(world.story_flags == saved_flags and deaths == 2, "backtracking does not replay story or add deaths")
	await connected_capture("approach_return")
