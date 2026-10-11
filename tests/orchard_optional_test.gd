extends "res://tests/act2_routes_test.gd"
## Continuous upper branch from the debug entrance, through the real exit.
## No branch teleport, key/fruit grants, or movement parameter changes.
const OUT := "res://output/act2_polish/garden_audit/orchard_optional"
var capture_dir := OUT

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act_2_Level_5"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(30)
	world = Screen.current as LdtkWorld
	player = world.player
	room = world.current_room
	offset = room.global_position
	continuous = true
	player._ledge_cooldown = 3600.0
	player.died.connect(func(): deaths += 1)
	var lower := "--lower" in OS.get_cmdline_user_args()
	if lower: capture_dir = OUT + "/lower"
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var initial_lemons := Collectibles.total
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_expansion.json"))
	var recipe: Dictionary
	for entry: Dictionary in recipes:
		if entry.name == "Act_2_Level_5": recipe = entry
	var steps: Array = [recipe.routes[0]]
	steps.append_array(recipe.optional_routes)
	steps.append_array(recipe.routes.slice(-2))
	if lower: steps = recipe.routes
	await capture("entrance")
	for i in steps.size():
		await run_step(steps[i])
		await capture("step_%02d" % i)
		if failures: break
	check(Collectibles.total == initial_lemons + 1, "branch reward picked up and banked")
	if failures == 0:
		for i in 180:
			if _route_exit_started(): break
			Input.action_press("move_right")
			await frames(1)
		release()
		for i in 180:
			if str(world.current_room.name) == "Act_2_Level_6" and not world._transitioning: break
			await frames(1)
	check(str(world.current_room.name) == "Act_2_Level_6" and not world._transitioning,
		"branch reaches the checkpoint route and uses the actual onward exit")
	check(deaths == 0 and not used_climb, "no deaths, climbing or land mantle")
	check(Collectibles.total == initial_lemons + 1, "banked reward survives room transition")
	await capture("onward_exit" if failures == 0 else "failure")
	print("ORCHARD OPTIONAL: ", failures, " failures; deaths=", deaths, "; lemons=", Collectibles.total)
	get_tree().quit(0 if failures == 0 else 1)

func _route_exit_started() -> bool:
	return str(world.current_room.name) == "Act_2_Level_6" or (world._transitioning
		and world.transition_target != null and str(world.transition_target.name) == "Act_2_Level_6")

func capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(capture_dir + "/" + label + ".png")
	print("ORCHARD CAPTURE ", label, " ", player.global_position - world.current_room.global_position,
		" lemons=", Collectibles.total, " deaths=", deaths)
