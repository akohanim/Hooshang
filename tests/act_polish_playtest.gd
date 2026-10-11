extends Node
## Save-free, observed gameplay session. Commands contain real input actions and
## frame durations, never positions or velocities. Pauses between observations.
## Run windowed: -- <act> <room>. Write command.json in output/act2_polish/live.
const OUT := "res://output/act2_polish/live"
var world: LdtkWorld
var busy := true
var sequence := 0
var deaths := 0
var states_seen: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(OUT)
	SaveGame.slot = -1
	var args := OS.get_cmdline_user_args()
	var act := int(args[0]) if not args.is_empty() else 1
	LdtkWorld.debug_start_room = args[1] if args.size() > 1 else "Level_1"
	world = load("res://ldtk/Act%dWorld.tscn" % act).instantiate()
	Screen.set_scene(world)
	for i in 30: await get_tree().physics_frame
	world.player.died.connect(func(): deaths += 1)
	get_tree().paused = true
	await capture("arrival")
	busy = false

func _physics_process(_delta: float) -> void:
	if world != null and world.player != null:
		var state: String = world.player.state_name()
		if not states_seen.has(state): states_seen.append(state)

func _process(_delta: float) -> void:
	if busy or not FileAccess.file_exists(OUT + "/command.json"): return
	busy = true
	var command: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT + "/command.json"))
	DirAccess.remove_absolute(OUT + "/command.json")
	if command is Dictionary: execute.call_deferred(command)
	else: busy = false

func execute(command: Dictionary) -> void:
	print("OBSERVED INPUT ",JSON.stringify(command))
	if command.get("quit", false):
		get_tree().paused = false
		get_tree().quit()
		return
	get_tree().paused = false
	for step: Dictionary in command.get("steps", []):
		for action: String in step.get("press", []): Input.action_press(action)
		for action: String in step.get("release", []): Input.action_release(action)
		for i in int(step.get("frames", 1)): await get_tree().physics_frame
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "glow"]:
		Input.action_release(action)
	get_tree().paused = true
	sequence += 1
	await capture(str(command.get("label", "step")))
	busy = false

func capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	var stem := "%03d_%s_%s" % [sequence, world.current_room.name, label]
	Screen.viewport.get_texture().get_image().save_png(OUT + "/" + stem + ".png")
	get_tree().root.get_texture().get_image().save_png(OUT + "/" + stem + "_ui.png")
	var state := {"capture": stem, "room": str(world.current_room.name),
		"position": [world.player.position.x, world.player.position.y],
		"local_position": [world.player.global_position.x-world.current_room.global_position.x,
			world.player.global_position.y-world.current_room.global_position.y],
		"velocity": [world.player.velocity.x, world.player.velocity.y],
		"state": world.player.state_name(), "has_dash": world.player.has_dash,
		"input_locked": world.player.input_locked, "deaths": deaths, "states_seen": states_seen,
		"lemons": Collectibles.total, "checkpoint": [world._checkpoint.x,world._checkpoint.y]}
	var file := FileAccess.open(OUT + "/state.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(state, "\t"))
	print("OBSERVED PLAY ", JSON.stringify(state))
