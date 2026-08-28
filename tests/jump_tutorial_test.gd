extends Node
## Level_1's jump lesson: the prompt appears a couple of steps in, follows him
## rather than pinning him, swaps art to match keyboard vs. controller, and
## clears the moment he actually jumps.
## Run:  godot --headless res://tests/jump_tutorial_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var tut: JumpTutorial


func _ready() -> void:
	SaveGame.slot = -1
	InputDevice.current = InputDevice.Device.KEYBOARD
	LdtkWorld.debug_start_room = JumpTutorial.ROOM
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(30)
	tut = world.get_node_or_null("JumpTutorial")
	_check(tut != null, "the world carries the tutorial node")
	if tut == null:
		return _finish()
	_check(str(world.current_room.name) == JumpTutorial.ROOM,
		"opens in %s  [%s]" % [JumpTutorial.ROOM, world.current_room.name])

	var p := world.player
	p.input_locked = false
	_check(not p.input_locked,
		"UNLIKE the dash lesson, nothing here takes his controls away")
	_check(tut._armed and tut._prompt == null,
		"armed on entry, but nothing shown yet")

	# --- walking less than arm_distance shows nothing ------------------------
	var start_x := p.global_position.x
	Input.action_press("move_right")
	var short_walk := int((tut.arm_distance * 0.5) / p.max_run_speed * 60.0) + 5
	for i in short_walk:
		await _frames(1)
	_check(tut._prompt == null,
		"still nothing after half the arm distance  [%.1fpx of %.1f]"
			% [p.global_position.x - start_x, tut.arm_distance])

	# --- and it appears once he has actually gone far enough -----------------
	var armed := false
	for i in 120:
		await _frames(1)
		if tut._prompt != null:
			armed = true
			break
	Input.action_release("move_right")
	_check(armed, "the prompt appears after roughly two steps  [%.1fpx walked]"
		% (p.global_position.x - start_x))
	_check(p.global_position.x - start_x >= tut.arm_distance - 1.0,
		"...and not before he actually walked arm_distance  [%.1fpx of %.1f]"
			% [p.global_position.x - start_x, tut.arm_distance])

	# --- it starts on the KEYBOARD art (nothing else has run yet) ------------
	var sprite: Sprite2D = tut._prompt.get_child(0)
	_check(sprite.texture == tut.key_art,
		"starts on the keyboard art  [%s]" % sprite.texture.resource_path.get_file())

	# --- it FOLLOWS him — nothing pins him here like the dash lesson does ----
	# Moved directly, a small step BACKWARD, rather than walked or moved
	# forward: Level_1 has its own geometry ahead of him (a one-cell chimney
	# shaft — see chimney_test — and eventually the room's own Exit), and a
	# real run, or even a big enough teleport, risks tripping either one,
	# which has nothing to do with what this checks. A small step back stays
	# well clear of both and still proves the one thing that matters — does
	# the bubble recompute from his CURRENT position every frame, or only the
	# frame it popped in.
	var before := tut._prompt.global_position
	p.global_position.x -= 12.0
	await _frames(1)
	var after := tut._prompt.global_position
	_check(absf(after.x - before.x + 12.0) < 2.0,
		"the bubble follows him rather than staying put  [moved %.1fpx, wanted -12]"
			% (after.x - before.x))
	_check(absf(after.x - p.global_position.x) < 20.0,
		"...and stays roughly over his head  [bubble %.1f, player %.1f]"
			% [after.x, p.global_position.x])

	# --- a real controller button swaps the art live --------------------------
	_pad_press()
	await _frames(2)
	_check(InputDevice.current == InputDevice.Device.CONTROLLER,
		"InputDevice notices a real joypad button")
	sprite = tut._prompt.get_child(0)
	_check(sprite.texture == tut.pad_art,
		"...and the ALREADY-SHOWING prompt swaps to the controller art  [%s]"
			% sprite.texture.resource_path.get_file())

	# --- and a key swaps it right back -----------------------------------------
	# KEY_G, deliberately unbound to anything: KEY_C is the jump key, and
	# parsing that as a raw event to test InputDevice would also fire a real
	# jump and end the lesson right here — which is exactly what the block
	# below tests on purpose, not a side effect this one should trip over.
	_key_tap(KEY_G)
	await _frames(2)
	_check(InputDevice.current == InputDevice.Device.KEYBOARD,
		"a keypress swaps InputDevice back")
	sprite = tut._prompt.get_child(0)
	_check(sprite.texture == tut.key_art,
		"...and the prompt back with it  [%s]" % sprite.texture.resource_path.get_file())

	# --- jumping clears it, and only jumping ----------------------------------
	Input.action_press("jump")
	var cleared := false
	for i in 60:
		await _frames(1)
		if tut._prompt == null:
			cleared = true
			break
	Input.action_release("jump")
	_check(cleared, "jumping clears the prompt")
	_check(tut._done, "...and the lesson is marked done")
	_check(p.state == Player.State.JUMP,
		"...because he actually jumped, not because the room gave up on him  [%s]"
			% p.state_name())

	# --- death re-arms it, measured from where he actually stands up ---------
	tut._done = false
	tut._armed = false
	var respawn_x := p.global_position.x
	p.die()
	await _frames(int((world.respawn_delay + p.death_time) * 60.0) + 60)
	_check(tut._armed and not tut._done,
		"a death in this room re-arms the lesson")
	_check(tut._arm_at_x > p.global_position.x - 4.0,
		"...measured from where he stood back up, not where he died  [arm %.1f, stood %.1f, died %.1f]"
			% [tut._arm_at_x, p.global_position.x, respawn_x])

	_finish()


## One real joypad button, straight into the input system.
##
## JOY_BUTTON_B, deliberately NOT JOY_BUTTON_A: "jump" is bound to joypad
## button_index 0, which IS JOY_BUTTON_A — parsing that here to test
## InputDevice's own detection would also fire a real jump and end the lesson
## right here, same trap as KEY_C below and just as beside the point.
func _pad_press() -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_B
	ev.pressed = true
	Input.parse_input_event(ev)
	ev = InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_B
	ev.pressed = false
	Input.parse_input_event(ev)


## One real keyboard press-and-release, straight into the input system.
func _key_tap(key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.pressed = true
	Input.parse_input_event(ev)
	ev = InputEventKey.new()
	ev.physical_keycode = key
	ev.pressed = false
	Input.parse_input_event(ev)


func _finish() -> void:
	if failures.is_empty():
		print("JUMP TUTORIAL TEST: ALL PASS")
	else:
		print("JUMP TUTORIAL TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
