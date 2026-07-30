extends Node
## Headless smoke test: loads the real level and drives the player with
## simulated input to verify run / jump / dash / death-respawn all work.
## Run with:  godot --headless res://tests/smoke_test.tscn

var failures: Array[String] = []
var level: Node2D
var player: Player


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/levels/TestLevel.tscn")
	level = packed.instantiate()
	add_child(level)
	player = level.get_node("Player")
	_run()


func _run() -> void:
	# Let the player settle onto the floor.
	await _frames(40)
	_check(player.is_on_floor(), "player settles on floor")

	# Run: reaches top speed fast, stops fast.
	Input.action_press("move_right")
	await _frames(20)
	_check(player.velocity.x > player.max_run_speed * 0.9,
		"reaches top run speed (vx=%.1f)" % player.velocity.x)
	_check(player.state == Player.State.RUN, "RUN state while running")
	Input.action_release("move_right")
	await _frames(20)
	_check(absf(player.velocity.x) < 1.0, "decelerates to a stop")

	# Jump: gains height, goes airborne, lands again.
	var y0 := player.global_position.y
	Input.action_press("jump")
	await _frames(8)
	Input.action_release("jump")
	_check(player.global_position.y < y0 - 4.0, "jump gains height")
	_check(player.state == Player.State.JUMP or player.state == Player.State.FALL,
		"airborne state during jump")
	await _frames(60)
	_check(player.is_on_floor(), "lands after jump")

	# Dash: covers distance quickly.
	var x0 := player.global_position.x
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	await _frames(30)
	_check(player.global_position.x - x0 > 25.0,
		"dash covers distance (dx=%.1f)" % (player.global_position.x - x0))
	_check(player.dash_available, "dash refills on the ground")

	# Wall slide + wall jump against the left boundary wall.
	Input.action_press("move_left")
	await _frames(100)  # run all the way back to the boundary wall
	Input.action_press("jump")  # full jump, held — falls back down along the wall
	var slid := false
	for i in 60:
		await _frames(1)
		if player.state == Player.State.WALL_SLIDE:
			slid = true
			break
	Input.action_release("jump")
	_check(slid, "wall slide engages when falling into a wall")
	if slid:
		await _frames(3)
		_check(player.velocity.y <= player.wall_slide_max_speed + 1.0,
			"slide speed is capped (vy=%.1f)" % player.velocity.y)
		Input.action_press("jump")
		await _frames(2)
		Input.action_release("jump")
		_check(player.velocity.x > 0.0 and player.state == Player.State.JUMP,
			"wall jump kicks away from the wall (vx=%.1f)" % player.velocity.x)
	Input.action_release("move_left")
	await _frames(60)

	# Wall jump while still RISING beside a wall (no slide needed) — the thing
	# that makes chained shaft climbs feel good.
	Input.action_press("move_left")
	await _frames(100)  # back against the boundary wall
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(2)  # still rising, pressed against the wall
	var rising := player.velocity.y < 0.0
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(rising and player.velocity.x > 100.0,
		"wall jump works while rising, without a slide (vx=%.1f)" % player.velocity.x)
	Input.action_release("move_left")
	await _frames(60)

	await _check_no_float()

	# Death and respawn at the last checkpoint.
	player.die()

	_check(player.state == Player.State.DEAD, "die() enters DEAD state")
	await _frames(30)
	_check(player.state != Player.State.DEAD, "respawns automatically")
	_check(player.global_position.distance_to(level.current_checkpoint) < 24.0,
		"respawns at the checkpoint")

	if failures.is_empty():
		print("SMOKE TEST: ALL PASS")
	else:
		print("SMOKE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Regression: a GROUND state must never survive being airborne.
##
## _state_ground() applies no gravity, so an airborne IDLE/RUN keeps its vertical
## speed forever. With upward speed that was a permanent float: the player rose
## at a constant rate, hit the ceiling, and hung there for good — nothing moved a
## ground state on, and the coyote-time escape needs velocity.y >= 0, which is
## exactly false in that case. The dash exit could produce it (an upward dash
## ending on the frame the player still touched the floor), so this forces the
## stranded state directly rather than relying on hitting that timing.
func _check_no_float() -> void:
	player.respawn(level.current_checkpoint)
	await _frames(30)
	var floor_y := player.global_position.y
	_check(player.is_on_floor(), "float check: starts grounded")

	player.state = Player.State.IDLE
	player.velocity = Vector2(0.0, -player.dash_end_speed)
	# One frame is all it takes for the invariant to hand him back to gravity.
	await _frames(2)
	_check(player.state != Player.State.IDLE and player.state != Player.State.RUN,
		"airborne ground state is corrected to FALL (got %s)" % player.state_name())

	var highest := player.global_position.y
	var landed := false
	for i in 180:
		await _frames(1)
		highest = minf(highest, player.global_position.y)
		if i > 4 and player.is_on_floor():
			landed = true
			break
	_check(landed, "gravity resumes and he comes back down (peak %.1fpx up)"
		% (floor_y - highest))
	_check(absf(player.global_position.y - floor_y) < 2.0,
		"lands back at floor level (%.1f vs %.1f)" % [player.global_position.y, floor_y])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
