extends Node
## Real action presses on different physics ticks reproduce keyboard chord timing.
var player: Player
var failures: Array[String] = []

func _ready() -> void:
	player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	for order in [["move_up", "move_right"], ["move_left", "move_up"]]:
		await _reset()
		Input.action_press("dash")
		await _frames(1)
		_check(player.state != Player.State.DASH, "dash waits for the direction chord")
		Input.action_release("dash")
		Input.action_press(order[0])
		await _frames(1)
		Input.action_press(order[1])
		await _frames(3)
		var expected := Vector2(1 if order[1] == "move_right" else -1, -1).normalized()
		_check(player.state == Player.State.DASH and player.dash_dir.is_equal_approx(expected),
			"staggered arrows complete diagonal: %s" % str(order))
		var committed := player.dash_dir
		Input.action_release(order[0])
		Input.action_release(order[1])
		Input.action_press("move_down")
		await _frames(2)
		_check(player.dash_dir == committed, "direction stays fixed after collection window")
	await _reset()
	player.facing = -1
	Input.action_press("dash")
	await _frames(5)
	_check(player.dash_dir == Vector2.LEFT, "neutral dash uses facing")
	await _reset()
	player.has_dash = false
	Input.action_press("dash")
	await _frames(5)
	_check(player.state != Player.State.DASH, "locked ability cannot queue a dash")
	player.has_dash = true
	await _reset()
	Input.action_press("dash")
	await _frames(1)
	player.input_locked = true
	await _frames(5)
	_check(player.state != Player.State.DASH, "input lock cancels pending command")
	player.input_locked = false
	await _reset()
	Input.action_press("dash")
	await _frames(1)
	player.respawn(Vector2.ZERO)
	Input.action_release("dash")
	await _frames(5)
	_check(player.state != Player.State.DASH, "respawn clears pending command")
	_release()
	print("DASH INPUT: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _reset() -> void:
	_release()
	player.respawn(Vector2.ZERO)
	await _frames(2)

func _release() -> void:
	for action in ["dash", "move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _check(ok: bool, message: String) -> void:
	print("  %s %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failures.append(message)
