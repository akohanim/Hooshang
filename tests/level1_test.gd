extends Node
## Headless test for Level 1: The Office.
## Verifies: dash locked at start -> Rumi scene grants dash -> checkpoint
## respawn on pit death -> exit trigger completes the level.
## Run with:  godot --headless res://tests/level1_test.tscn

var failures: Array[String] = []
var level: Node2D
var player: Player


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/levels/act1_office/Level1Office.tscn")
	level = packed.instantiate()
	add_child(level)
	player = level.get_node("Player")
	_run()


func _run() -> void:
	# --- Start: Hooshang has control and stands in his left cubicle. ---
	await _frames(20)
	_check(not player.input_locked, "player has control at start")
	_check(player.is_on_floor(), "stands in the left cubicle")
	_check(not player.has_dash, "dash is LOCKED at level start")
	_check(get_tree().get_nodes_in_group("lights").size() == 4,
		"4 LampFixture prefabs registered in the 'lights' group")

	# --- Beat 1: walk to the door; reaching it triggers Rumi's intro. ---
	player.global_position = Vector2(120, 150)  # into the IntroTrigger at the door
	await _frames(20)
	_check(player.input_locked, "reaching the door starts Rumi's intro")
	_check(level.get_node("Rumi").modulate.a > 0.1, "Rumi appears at the door")
	_check(not level.get_node("Door").is_open, "door stays shut until Rumi has spoken")

	# Advance the single intro line (reveal-skip + dismiss); wait for unlock.
	for i in 40:
		if not player.input_locked:
			break
		_press_confirm()
		await _frames(10)
	_check(not player.input_locked, "gameplay resumes after the intro")
	_check(not player.has_dash, "intro does NOT grant dash")
	# The door opened (outward = flattened) after Rumi's line.
	_check(level.get_node("Door").is_open, "the door opens after Rumi's line")
	await _frames(35)  # let the flatten tween run
	_check(level.get_node("Door/Hinge").scale.x < 0.5,
		"door leaf flattened open (swings outward)")

	# Dash button must still do nothing before the second Rumi beat.
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	var dashed := false
	for i in 10:
		await _frames(1)
		if player.state == Player.State.DASH:
			dashed = true
	_check(not dashed, "dash stays locked until the pillar")

	# --- Beat 2: reach the tall pillar; Rumi reappears and grants dash. ---
	player.global_position = Vector2(520, 150)  # into the DashTrigger zone
	await _frames(30)
	_check(player.input_locked, "pillar scene locks input")
	_check(level.get_node("Rumi").modulate.a > 0.1, "Rumi reappears at the pillar")

	# Confirm through the line + the tutorial hint; wait for the grant + unlock.
	for i in 60:
		if player.has_dash and not player.input_locked:
			break
		_press_confirm()
		await _frames(12)
	_check(player.has_dash, "Rumi grants dash at the pillar")
	_check(not player.input_locked, "gameplay unfreezes after the grant")
	_check(level.get_node("Rumi").modulate.a < 0.1, "Rumi fades back out")

	# Dash works now.
	await _frames(20)  # settle on floor, refresh dash
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	dashed = false
	for i in 10:
		await _frames(1)
		if player.state == Player.State.DASH:
			dashed = true
	_check(dashed, "dash works after the unlock")
	await _frames(30)

	# Death respawns at the level spawn (this room has no checkpoints).
	player.die()
	_check(player.state == Player.State.DEAD, "die() enters DEAD state")
	await _frames(30)
	_check(player.state != Player.State.DEAD, "respawns quickly")
	_check(player.global_position.distance_to(Vector2(48, 154)) < 24.0,
		"respawns at the spawn point (pos=%s)" % player.global_position)

	# Exit trigger in the alcove on the far-right wall.
	player.global_position = Vector2(784, 150)
	var done := false
	for i in 60:
		await _frames(1)
		if level.get_node("EndScreen").visible:
			done = true
			break
	_check(done, "exit trigger shows LEVEL COMPLETE")

	if failures.is_empty():
		print("LEVEL1 TEST: ALL PASS")
	else:
		print("LEVEL1 TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Dialogue listens for input *events*, so action_press isn't enough — send a
## real event through the pipeline.
func _press_confirm() -> void:
	var down := InputEventAction.new()
	down.action = "jump"
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = "jump"
	up.pressed = false
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
