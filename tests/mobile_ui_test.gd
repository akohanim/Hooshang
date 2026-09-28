extends Node
var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveGame.dir = "user://_mobile_ui_test_unused"
	SaveGame.slot = -1
	TouchControls.enabled = true
	InputDevice.note_touch()
	var menu := preload("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(menu)
	await _frames(3)
	var row: Control = menu.rows.get_child(0)
	_tap(row.get_global_transform_with_canvas() * (row.size * 0.5))
	_check(menu.page == MainMenu.Page.SLOTS, "main menu accepts a touch tap")
	_tap(menu.back_button.get_global_transform_with_canvas() * (menu.back_button.size * 0.5))
	_check(menu.page == MainMenu.Page.ROOT, "Back is tappable")
	var choices: Array[Dictionary] = []
	for i in 20:
		choices.append(menu._row("ROOM %d" % i, "test", func(): pass))
	menu._populate(choices)
	var point := Vector2(160, 135)
	_touch(point, true)
	for i in 8:
		point.y -= 18
		_drag(point)
	_touch(point, false)
	_check(menu._top > 0 and menu.selected > 5, "swiping reaches offscreen menu rows")
	menu.free()
	await _frames(2)

	var prompt := preload("res://scenes/ui/InputPrompt.tscn").instantiate()
	add_child(prompt)
	prompt.show_at(Vector2(100, 100))
	_check(prompt._touch_panel.visible and prompt._sprite.self_modulate.a == 0,
		"touch tutorial replaces keyboard badge with gesture wording")
	InputDevice._note(InputDevice.Device.KEYBOARD)
	_check(not prompt._touch_panel.visible and prompt._sprite.self_modulate.a == 1,
		"hardware input restores tutorial key art")
	prompt.free()
	InputDevice.note_touch()

	Dialogue.say("Hooshang", "A touch should reveal this line, and the next should continue.", Color.WHITE)
	await _frames(45)
	var signals := [0]
	Dialogue.line_finished.connect(func(): signals[0] += 1)
	_tap(Vector2(160, 140))
	_check(not Dialogue._revealing, "dialogue tap reveals the current page")
	var after_reveal: int = signals[0]
	_tap(Vector2(160, 140))
	_check(signals[0] == after_reveal + 1, "next dialogue tap advances exactly once")
	await _frames(25)
	_check(not TouchControls.consume_jump(), "dialogue taps never queue a jump")

	var intro := preload("res://scenes/ui/IntroVideo.tscn").instantiate()
	add_child(intro)
	intro.set_process(false)
	await _frames(2)
	var skip_point: Vector2 = intro.skip_prompt.get_global_transform_with_canvas() * (intro.skip_prompt.size * 0.5)
	_touch(skip_point, true)
	intro._process(0.3)
	_check(not intro._over and intro.skip_fill.anchor_right > 0, "touch hold starts intro skip progress")
	_touch(skip_point, false)
	intro._process(0.01)
	_check(not intro._over and intro.skip_fill.anchor_right == 0, "early release cancels intro skip")
	_touch(skip_point, true)
	intro._process(intro.skip_hold_time + 0.1)
	_check(intro._over, "completed touch hold skips intro")
	_touch(skip_point, false)
	await _frames(45)
	intro.free()
	var results := preload("res://scenes/ui/ActResults.tscn").instantiate()
	results.stats = {"world": "res://ldtk/Act1World.tscn", "seconds": 42.0,
		"lemons": 0, "available": 8, "deaths": 1}
	add_child(results)
	await _frames(2)
	_tap(Vector2(160, 150))
	_check(results.complete and not results._leaving, "first results tap finishes tally")
	_tap(Vector2(160, 150))
	_check(results._leaving and not get_tree().paused, "next results tap continues to next act")
	results.free()
	print("MOBILE UI: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _tap(point: Vector2) -> void:
	_touch(point, true)
	_touch(point, false)

func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.position = point
	event.pressed = pressed
	get_viewport().push_input(event, true)

func _drag(point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 7
	event.position = point
	get_viewport().push_input(event, true)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _check(ok: bool, message: String) -> void:
	print("  %s %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failures.append(message)
