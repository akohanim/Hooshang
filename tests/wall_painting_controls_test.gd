extends Node
## Real keyboard/gamepad input through the actual Room 14 painting break.
var failures := 0
var world: Node
var story: Node

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	# Match the OS input pump before physics. At accelerated time, two physics
	# ticks can precede the next render/input flush and falsely outrun a tap.
	Input.flush_buffered_events()

func stick(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func button(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	DirAccess.make_dir_recursive_absolute("res://output/room14_controls")
	await get_tree().process_frame
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://output/room14_controls/" + label + ".png")

func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room = "Act_2_Level_14"
	world = load("res://ldtk/Act2World.tscn").instantiate()
	# Exercise the shipping root-window -> Screen -> SubViewport input route.
	Screen.set_scene(world)
	await frames(20)
	for node in world.current_room.get_node("Entities").get_children():
		if node.get_script() == preload("res://scenes/props/school_wall/school_story.gd") and node.chapter == "wall": story = node
	check(story != null, "actual graffiti encounter is imported")
	if story == null:
		get_tree().quit(1)
		return
	world.player.global_position = story.global_position + Vector2(70, -6)
	Engine.time_scale = 4
	for tick in 3000:
		await frames(1)
		if story.painting_game.active: break
		if Dialogue._active:
			Dialogue._finish_reveal_instantly()
			Dialogue.line_finished.emit()
	var game: Node = story.painting_game
	var player: Player = world.player
	check(game.active, "painting break starts")
	await frames(4)
	var start := player.global_position
	key(KEY_UP, true)
	await frames(10)
	key(KEY_UP, false)
	check(not game.has_can and not game.painting, "up alone neither picks up nor sprays")
	key(KEY_X, true)
	await frames(10)
	Dialogue._process(Dialogue.skip_hold_time + 0.1)
	check(game.active and not game.painting and not story.finished, "X without a can cannot spray or skip the story")
	key(KEY_X, false)
	await frames(2)
	key(KEY_C, true)
	await frames(20)
	check(game.has_can and game.color_index == 1, "C picks up the nearest actual can")
	check(not game._ground_cans[1].visible and story.get_node("Wall/Can").visible, "picked can leaves the floor and appears in hand")
	check(player.global_position.distance_to(start) < 1 and player.state != Player.State.JUMP, "C pickup does not also jump")
	check(game.has_can, "holding C does not repeatedly put down and pick up")
	await capture("picked_up")
	key(KEY_C, false)
	await frames(2)
	key(KEY_X, true)
	await frames(45)
	Dialogue._process(Dialogue.skip_hold_time + 0.1)
	check(game.painting and game.active and not story.finished, "X toggles spray on and a long hold never skips")
	check(player.state != Player.State.DASH and player._dash_input_timer == 0, "spray X does not buffer or perform a dash")
	key(KEY_X, false)
	await frames(2)
	check(game.painting, "releasing X keeps the spray toggle on")
	var cursor: Vector2 = game._spray_point
	key(KEY_UP, true)
	await frames(40)
	key(KEY_UP, false)
	check(game._spray_point.y < cursor.y - 15, "up arrow moves paint upward")
	check(player.global_position.distance_to(start) < 1, "aiming keeps Hooshang planted")
	key(KEY_RIGHT, true)
	await frames(85)
	key(KEY_RIGHT, false)
	check(game._spray_point.x > cursor.x + 30 and player.global_position.distance_to(start) < 1, "horizontal arrows aim instead of walking while spraying")
	await capture("spraying")
	cursor = game._spray_point
	stick(JOY_AXIS_LEFT_X, -0.7)
	stick(JOY_AXIS_LEFT_Y, 0.7)
	await frames(24)
	stick(JOY_AXIS_LEFT_X, 0)
	stick(JOY_AXIS_LEFT_Y, 0)
	check(game._spray_point.x < cursor.x - 5 and game._spray_point.y > cursor.y + 5, "analog joystick aims paint diagonally")
	key(KEY_LEFT, true)
	await frames(130)
	key(KEY_LEFT, false)
	check(game.areas.count(true) == 3, "aiming paints all three wall areas without moving the body")
	var marks: Array = story.get_node("Wall/Graffiti").paint_marks
	check(marks.size() > 12 and marks.all(func(mark: Dictionary) -> bool: return mark.color == 1), "held can retains its own color across the whole wall")
	key(KEY_X, true)
	await frames(2)
	key(KEY_X, false)
	var stopped_count := marks.size()
	await frames(10)
	check(not game.painting and story.get_node("Wall/Graffiti").paint_marks.size() == stopped_count, "second X stops spraying and new marks")
	key(KEY_RIGHT, true)
	await frames(12)
	key(KEY_RIGHT, false)
	await frames(5)
	check(player.global_position.x > start.x + 20, "arrows return to walking when spray is off")
	check(absf(player.global_position.x - story.cousin.global_position.x) < 22, "down-aim check happens beside Jamshid's actual finish point")
	key(KEY_X, true)
	await frames(2)
	key(KEY_X, false)
	key(KEY_DOWN, true)
	await frames(3)
	check(game.active and game.painting, "aiming down beside Jamshid cannot finish the break")
	key(KEY_C, true)
	await frames(15)
	check(not game.has_can and not game.painting, "C puts the held can down and stops spraying")
	check(game._ground_cans[1].visible and not story.get_node("Wall/Can").visible, "put-down restores the actual can at Hooshang's feet")
	check(player.global_position.distance_to(game._ground_cans[1].global_position) < 12, "dropped can stays where the player put it")
	check(game.active, "held down aim does not become an accidental finish after dropping")
	check(not world.get_node("Act2Audio/Spray").playing, "put-down stops the spray hiss immediately")
	await capture("put_down")
	key(KEY_DOWN, false)
	key(KEY_C, false)
	await frames(2)
	key(KEY_C, true)
	await frames(2)
	key(KEY_C, false)
	await frames(2)
	check(game.has_can and game.color_index == 1, "a fresh C picks the dropped can up again")
	key(KEY_C, true)
	key(KEY_C, false)
	await frames(4)
	check(not game.has_can, "short C taps between physics ticks still put the can down")
	button(JOY_BUTTON_A, true)
	await frames(4)
	button(JOY_BUTTON_A, false)
	await frames(4)
	check(game.has_can, "controller A picks up the can")
	button(JOY_BUTTON_X, true)
	await frames(4)
	button(JOY_BUTTON_X, false)
	await frames(4)
	check(game.painting and game.active and player.state != Player.State.DASH, "controller X starts spray without a dash or skip")
	key(KEY_Z, true)
	await frames(6)
	Dialogue._process(Dialogue.skip_hold_time + 0.1)
	key(KEY_Z, false)
	for tick in 90:
		await frames(1)
		if story.finished: break
	check(story.finished and not player._interaction_buttons_reserved and not player._interaction_movement_reserved, "finish or skip restores normal player controls")
	check(Dialogue._scene_skip_action == &"skip_dialogue", "normal X dialogue skipping is restored")
	Engine.time_scale = 1
	for code in [KEY_C, KEY_X, KEY_Z, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]: key(code, false)
	Screen.clear()
	await frames(3)
	print("WALL PAINTING CONTROLS: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
