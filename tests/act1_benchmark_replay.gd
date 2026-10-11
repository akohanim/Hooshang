extends "res://tests/precision_escape_test.gd"
## Rendered, normal-speed replay of existing input recipes. This is scripted
## gameplay evidence, not a human playtest. Act 1 content is never modified.
var capture_tick := 0
var capturing := false
const OUT := "res://output/act2_polish/act1_benchmark"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_23"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(12)
	player = world.player
	player.has_dash = true
	player.died.connect(func(): died = true)
	solutions = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/precision_escape_inputs.json"))
	var configs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	var selected := OS.get_cmdline_user_args()
	if selected.is_empty(): selected = PackedStringArray(["Level_23", "Level_24"])
	for candidate: Dictionary in configs:
		if candidate.name not in selected or not candidate.get("precision_escape", false): continue
		config = candidate
		solutions = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/precision_escape_inputs.json"))
		# The archived input fixture predates insertion of conveyor room 19.
		# Adapt this read-only benchmark locally; never rewrite Act 1's data.
		var number := int(str(config.name).trim_prefix("Level_"))
		var fixture_name := "Level_%d" % (number - 1) if number >= 20 else str(config.name)
		if not solutions.has(fixture_name) or solutions[fixture_name].size() != config.route.size() - 1:
			check(false, "no matching input fixture for " + str(config.name))
			continue
		var fixture: Array = solutions[fixture_name].duplicate(true)
		solutions[config.name] = fixture
		for r in world.rooms:
			if r.name == config.name: room = r
		world._enter_room(room, true)
		await frames(8)
		player.has_dash = true
		capturing = true
		await replay()
		capturing = false
		release()
	print("ACT1 BENCHMARK REPLAY: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		if not capturing: continue
		capture_tick += 1
		if capture_tick % 45 == 0:
			RenderingServer.force_draw()
			Screen.viewport.get_texture().get_image().save_png(OUT + "/%s_%05d.png" % [config.name, capture_tick])
