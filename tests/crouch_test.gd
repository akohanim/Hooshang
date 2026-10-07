extends Node

var failures := 0

func _ready() -> void:
	var level: Node2D = load("res://scenes/levels/TestLevel.tscn").instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	await _frames(40)
	_check(player.is_on_floor(), "starts grounded")
	_check(player.visual.sprite_frames.has_animation("crouch"), "adult library has the authored crouch sprite")
	var shape_size: Vector2 = player.get_node("CollisionShape2D").shape.size
	_down(true)
	await _frames(4)
	_check(player.crouching() and player.visual.animation == "crouch", "Down arrow activates the crouch sprite")
	var at := player.position
	Input.action_press("move_right")
	await _frames(20)
	_check(player.position.distance_to(at) < 1.0, "holding Down prevents walking")
	_check(player.get_node("CollisionShape2D").shape.size == shape_size, "pose preserves the existing collision box")
	_down(false)
	await _frames(15)
	_check(player.visual.animation == "run" and player.position.x > at.x + 5, "release restores running")
	Input.action_release("move_right")
	await _frames(20)
	_down(true)
	await _frames(3)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	_check(not player.crouching() and player.visual.animation in ["takeoff", "rise"], "jump leaves crouch even while Down stays held")
	await _frames(65)
	_check(player.crouching(), "landing with Down held restores crouch")
	# The same controller drives the child: Down must keep its prior behavior.
	var adult := player.visual.sprite_frames
	player.visual.sprite_frames = load("res://assets/characters/hooshang_child/act2_frames.tres")
	await _frames(2)
	_check(not player.crouching() and player.visual.animation == "idle", "child Hooshang does not use the adult crouch")
	player.visual.sprite_frames = adult
	player.input_locked = true
	await _frames(2)
	_check(not player.crouching() and player.visual.animation == "idle", "locked controls ignore crouch input")
	player.input_locked = false
	await _frames(2)
	player.has_dash = true
	player.dash_available = true
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	# Dash starts after the configured direction-collection window, even on a tap.
	await _frames(ceili(player.dash_input_time * Engine.physics_ticks_per_second) + 1)
	_check(player.state == Player.State.DASH and not player.crouching(), "dash can start from crouch")
	_down(false)
	await _frames(30)
	level.queue_free()
	await get_tree().process_frame
	print("CROUCH TEST: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func _down(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_DOWN
	event.pressed = pressed
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
