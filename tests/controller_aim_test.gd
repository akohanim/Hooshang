extends Node

var failures := 0

func _ready() -> void:
	var player = load("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for tilt in [Vector2(0.2, 0.2), Vector2(0.3, 0.3), Vector2(0.9, 0.4), Vector2(0.4, 0.9)]:
				_stick(tilt * Vector2(sx, sy))
				var aim: Vector2 = player._movement_input()
				_check(aim.normalized().is_equal_approx(Vector2(sx, sy).normalized()), "off-centre diagonal aim")
				player.state = player.State.FALL
				player.dash_available = true
				player.dash_cooldown_timer = 0.0
				_check(player._try_dash(), "dash accepted")
				_check(player.dash_dir.is_equal_approx(Vector2(sx, sy).normalized()), "actual dash direction")
				_check(is_equal_approx(player.velocity.length(), player.dash_speed), "diagonal dash speed")
	_stick(Vector2(0.12, -0.12))
	_check(player._movement_input() == Vector2.ZERO, "drift ignored")
	_stick(Vector2(0.95, 0.1))
	_check(player._movement_input().y == 0.0, "cardinal aim tolerates wobble")
	_stick(Vector2(0.707107, -0.707107))
	_check(is_equal_approx(player._movement_input().x, 1.0), "full diagonal gives full horizontal movement")
	_stick(Vector2.ZERO)
	player.state = player.State.FALL
	player.dash_available = true
	player.dash_cooldown_timer = 0.0
	player.facing = -1
	_check(player._try_dash() and player.dash_dir == Vector2.LEFT, "neutral dash follows facing")
	Input.action_press("move_left")
	Input.action_press("move_up")
	_check(player._movement_input() == Vector2(-1, -1), "digital diagonal unchanged")
	Input.action_release("move_left")
	Input.action_release("move_up")
	Engine.time_scale = 1.0
	print("Controller aim: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _stick(value: Vector2) -> void:
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis
		event.axis_value = value.x if axis == JOY_AXIS_LEFT_X else value.y
		Input.parse_input_event(event)
	Input.flush_buffered_events()

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
