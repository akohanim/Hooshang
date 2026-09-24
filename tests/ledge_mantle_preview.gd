extends Node
## Windowed visual review. Captures untouched 320x180 game pixels and a
## per-frame motion/pose trace. Run after importing the character sheet.
const OUT := "res://output/ledge_mantle_review"
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")
var records: Array = []

func _ready() -> void:
	Engine.max_fps = 60
	OS.low_processor_usage_mode = false
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	SaveGame.slot = -1
	DirAccess.make_dir_recursive_absolute(OUT)
	for scenario in ["jump_right", "jump_left", "dash_right", "narrow_platform", "swim_bank", "child_jump"]:
		if not OS.get_cmdline_user_args().is_empty() and scenario not in OS.get_cmdline_user_args():
			continue
		await _capture(scenario)
	var file := FileAccess.open(OUT + "/measurements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("LEDGE REVIEW saved " + ProjectSettings.globalize_path(OUT))
	get_tree().quit()

func _capture(scenario: String) -> void:
	var world := Node2D.new()
	Screen.set_scene(world)
	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([Vector2.ZERO, Vector2(320,0), Vector2(320,180), Vector2(0,180)])
	bg.color = Color("252934")
	world.add_child(bg)
	var left := scenario == "jump_left"
	var face := 220.0 if left else 100.0
	var width := 8.0 if scenario == "narrow_platform" else 80.0
	var depth := 64.0 if scenario == "swim_bank" else 8.0
	_platform(world, Rect2(face - width if left else face, 80, width, depth))
	_platform(world, Rect2(0, 160, 320, 20))
	var label := Label.new()
	label.position = Vector2(8,8)
	label.add_theme_font_size_override("font_size", 10)
	label.text = scenario.replace("_", " ")
	world.add_child(label)
	var player: Player = PLAYER.instantiate()
	player.position = Vector2(face + 9 if left else face - 9, 80)
	world.add_child(player)
	player.camera.enabled = false
	if scenario == "child_jump":
		player.visual.sprite_frames = load("res://assets/characters/hooshang_child/act2_frames.tres")
	player.set_physics_process(false)
	player.has_dash = true
	player.dash_available = true
	var pond: Area2D
	if scenario == "swim_bank":
		pond = load("res://scenes/props/zones/Pond.tscn").instantiate()
		pond.size = Vector2(96,64)
		pond.fish_count = 0
		pond.position = Vector2(52,112)
		world.add_child(pond)
	for warmup in 4:
		await get_tree().physics_frame
	player.state = Player.State.JUMP
	player.velocity = Vector2(-60 if left else 60, -15)
	player.jump_hold_timer = 0.0
	var action := "move_left" if left else "move_right"
	Input.action_press(action)
	if scenario == "dash_right":
		player._try_dash()
	if pond:
		# Overlap warmup may already have registered this pond before the
		# explicit near-bank placement; don't leave its idempotence guard
		# paired with the JUMP state seeded for the other scenarios.
		player.exit_swim(pond)
		player.position.y = 80 + player.swim_float_depth
		player.enter_swim(pond)
	# Step the controller once per captured frame. PNG readback can take
	# several real physics ticks on a busy desktop; automatic stepping would
	# skip the entire 240ms action and make a contact strip misleading.
	player.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(OUT + "/" + scenario)
	for frame in (34 if scenario == "swim_bank" else 26):
		await get_tree().physics_frame
		Input.action_press(action)
		player._physics_process(1.0 / 60.0)
		RenderingServer.force_draw()
		var image := Screen.viewport.get_texture().get_image()
		image.save_png(OUT + "/" + scenario + "/frame_%03d.png" % frame)
		records.append({"scenario":scenario,"frame":frame,
			"x":player.position.x,"y":player.position.y,
			"vx":player.velocity.x,"vy":player.velocity.y,
			"state":player.state_name(),"animation":player.visual.animation,
			"pose":player.visual.frame,"progress":player.visual.frame_progress,
			"floor":player.is_on_floor()})
	Input.action_release(action)
	player.set_physics_process(false)
	var trace := FileAccess.open(OUT + "/" + scenario + "/measurements.json", FileAccess.WRITE)
	trace.store_string(JSON.stringify(records.filter(func(record): return record.scenario == scenario), "\t"))

func _platform(world: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	var art := Polygon2D.new()
	art.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	art.color = Color("67778c")
	world.add_child(art)
	var edge := Line2D.new()
	edge.add_point(rect.position)
	edge.add_point(Vector2(rect.end.x, rect.position.y))
	edge.width = 1
	edge.default_color = Color("c0d6cf")
	world.add_child(edge)
