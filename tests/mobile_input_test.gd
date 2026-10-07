extends Node
## Dispatch real multitouch events through the root viewport and run real physics.
var failures: Array[String] = []
var player: Player
var world: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveGame.slot = -1
	world = Node2D.new()
	Screen.set_scene(world)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(2000, 16)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(500, 148)
	world.add_child(floor_body)
	player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	world.add_child(player)
	TouchControls.enabled = true
	await _reset_player()
	for finger in [-1, -2147483648, 2147483647]:
		_touch(finger, Vector2(222, 548), true)
		await _frames(6)
		_check(player.velocity.x > 30, "pressing the visible arrow moves immediately, ID %d" % finger)
		_drag(finger, Vector2(98, 548))
		await _frames(10)
		_check(player.velocity.x < -30, "opaque finger ID keeps ownership across direction change")
		_touch(finger, Vector2(98, 548), false)
		_check(TouchControls.move_finger == -1 and TouchControls.movement == Vector2.ZERO,
			"opaque finger releases without leaving movement stuck")
		await _reset_player()

	_touch(4, Vector2(160, 548), true)
	# The Web export emits a device-0 companion mouse motion BEFORE the drag.
	# Test beyond the grace interval too: a resting thumb still owns its stick.
	InputDevice._last_touch_ms = Time.get_ticks_msec() - 1000
	_browser_mouse_motion()
	_check(InputDevice.is_touch() and TouchControls.move_finger == 4,
		"browser companion mouse motion preserves a held movement finger")
	_drag(4, Vector2(244, 550))
	await _frames(6)
	_check(player.velocity.x > 30, "left thumb moves the player")
	_check(player.movement_input().y == 0, "horizontal thumb jitter cannot accidentally grab a ladder")
	_touch(8, Vector2(1000, 440), true)
	_touch(8, Vector2(1000, 440), false)
	await _frames(2)
	_check(player.state == Player.State.JUMP and player.velocity.y < 0, "second-finger tap jumps")
	_check(TouchControls.move_finger == 4 and player.velocity.x > 0, "jump finger release preserves movement")
	_touch(99, Vector2(1020, 440), false)
	_check(TouchControls.move_finger == 4, "an unowned finger cannot release movement")
	_touch(4, Vector2(244, 550), false)
	_check(TouchControls.movement == Vector2.ZERO, "movement stops on its own finger release")

	await _reset_player()
	_touch(4, Vector2(160, 548), true)
	_drag(4, Vector2(76, 548))
	_touch(8, Vector2(1000, 440), true)
	await _frames(1)
	_check(player.state != Player.State.JUMP, "swipe contact does not preemptively jump")
	_browser_mouse_motion()
	_check(TouchControls.action_finger == 8, "browser companion mouse motion preserves the dash finger")
	_drag(8, Vector2(1080, 360))
	await _frames(2)
	_check(player.state == Player.State.DASH and player.dash_dir.is_equal_approx(Vector2(1, -1).normalized()),
		"up-right swipe dashes up-right despite left thumb steering left")
	_drag(8, Vector2(900, 520))
	_touch(8, Vector2(900, 520), false)
	_check(TouchControls.consume_dash() == Vector2.ZERO and not TouchControls.consume_jump(),
		"one swipe fires once and never jumps on release")

	for sector in 8:
		await _reset_player()
		var direction := Vector2.RIGHT.rotated(sector * PI / 4.0)
		_touch(8, Vector2(1000, 440), true)
		_drag(8, Vector2(1000, 440) + direction * 80)
		await _frames(2)
		_check(player.dash_dir.is_equal_approx(direction), "swipe sector %d is exact" % sector)
		_touch(8, Vector2(1000, 440) + direction * 80, false)

	await _reset_player()
	_touch(8, Vector2(1000, 440), true)
	_touch(8, Vector2(1000, 440), false, true)
	await _frames(2)
	_check(player.is_on_floor(), "touchcancel never produces a tap jump")
	_touch(8, Vector2(1000, 440), true)
	await _frames(12)
	_check(player.velocity.y < 0 and TouchControls.jump_held(), "holding sustains a higher jump")
	_touch(8, Vector2(1000, 440), false)
	_check(not TouchControls.jump_held(), "lifting the held finger ends jump sustain")

	await _reset_player()
	Input.action_press("move_left")
	_touch(4, Vector2(160, 548), true)
	_drag(4, Vector2(244, 548))
	_touch(4, Vector2(244, 548), false)
	_check(Input.is_action_pressed("move_left") and player.movement_input().x < 0,
		"touch release never releases a physical input")
	Input.action_release("move_left")
	_touch(4, Vector2(160, 548), true)
	_drag(4, Vector2(244, 548))
	_touch(8, TouchControls.PAUSE_RECT.get_center(), true)
	_check(Pause.open and TouchControls.movement == Vector2.ZERO, "pause button pauses and releases fingers")
	# Touch the menu through its own transformed coordinates.
	var resume_row := Pause.rows.get_child(0) as Control
	var resume_point := resume_row.get_global_transform_with_canvas() * (resume_row.size * 0.5)
	_raw_touch(11, resume_point, true)
	_raw_touch(11, resume_point, false)
	await _frames(2)
	_check(not Pause.open and not get_tree().paused, "pause menu resumes on a tap")
	_check(player.state != Player.State.JUMP, "resume tap never leaks into gameplay")

	player.input_locked = true
	_touch(8, Vector2(1000, 440), true)
	_touch(8, Vector2(1000, 440), false)
	player.input_locked = false
	await _frames(2)
	_check(not TouchControls.consume_jump(), "locked controls discard gestures")
	_touch(4, Vector2(160, 548), true)
	_drag(4, Vector2(244, 548))
	player.invulnerable_timer = 1.0
	player.die()
	_check(TouchControls.move_finger == 4, "ignored damage never releases a held thumb")
	player.invulnerable_timer = 0.0
	player.respawn(Vector2(120, 134))
	_check(TouchControls.move_finger == -1, "respawn requires fresh touches")
	_touch(4, Vector2(160, 548), true)
	_drag(4, Vector2(244, 548))
	TouchControls.suspend()
	_check(Pause.open and TouchControls.move_finger == -1, "backgrounding pauses and releases all fingers")
	Pause.resume_game()
	TouchControls.reset()
	await _reset_player()
	var ladder := preload("res://scenes/props/zones/Ladder.tscn").instantiate()
	ladder.height = 64
	ladder.position = Vector2(120, 108)
	world.add_child(ladder)
	await _frames(3)
	_touch(4, Vector2(160, 548), true)
	_drag(4, Vector2(160, 464))
	await _frames(90)
	_check(player.climbing() and player.at_ladder_top(), "thumb Up climbs to the ladder top")
	_touch(8, Vector2(1000, 440), true)
	_touch(8, Vector2(1000, 440), false)
	await _frames(3)
	_check(player.state == Player.State.JUMP and not player.climbing(),
		"touch jump escapes the ladder while the thumb still holds Up")
	TouchControls.reset()
	_check(Screen.viewport.size == Vector2i(320, 180), "mobile UI never changes world resolution")
	InputDevice.note_touch()
	_browser_mouse_motion()
	_check(InputDevice.is_touch(), "trailing browser mouse motion does not replace touch prompts")
	InputDevice._last_touch_ms = Time.get_ticks_msec() - 1000
	_browser_mouse_motion()
	_check(not InputDevice.is_touch(), "real mouse resumes after touches and their grace interval")
	print("MOBILE INPUT: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _reset_player() -> void:
	TouchControls.reset()
	InputDevice.note_touch()
	player.input_locked = false
	player.has_dash = true
	player.respawn(Vector2(120, 132))
	await _frames(16)

func _touch(index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	_raw_touch(index, TouchControls.overlay.get_global_transform_with_canvas() * point, pressed, canceled)

func _raw_touch(index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	get_viewport().push_input(event, true)

func _drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = TouchControls.overlay.get_global_transform_with_canvas() * point
	get_viewport().push_input(event, true)

func _browser_mouse_motion() -> void:
	var event := InputEventMouseMotion.new()
	event.device = 0
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.relative = Vector2(20, 0)
	get_viewport().push_input(event, true)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _check(ok: bool, message: String) -> void:
	print("  %s %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failures.append(message)
