extends Node
## Measurement harness for CHILD Hooshang's reach — Act 2's movement profile
## (`Act2Beats._apply_child_movement`). NOT a pass/fail test: it prints the
## numbers Act 2's room geometry is authored against, the same job
## `feel_measure.tscn` does for the adult. Re-run it before touching the
## childhood profile or any Act 2 room (`tools/redesign_act2_rooms.py` quotes
## these figures).
##
## Run:  godot --headless --path . res://tests/act2_feel_measure.tscn

const FLOOR_Y := 400.0
var player: Player
var start_x := 200.0


func _ready() -> void:
	SaveGame.slot = -1
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(6000, 16)
	floor_body.position = Vector2(2800, FLOOR_Y + 8)
	floor_body.add_child(shape)
	add_child(floor_body)
	player = load("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	var world := LdtkWorld.new()
	world.player = player
	var profile := Act2Beats.new()
	profile._world = world
	profile._apply_child_movement()
	player.has_dash = true
	player._ledge_cooldown = 3600.0
	await _frames(20)

	print("\n=== CHILD JUMP ===")
	await _jump("standing, tapped", false, 2)
	await _jump("standing, held", false, 60)
	await _jump("running, held", true, 60)
	print("\n=== CHILD DASH ===")
	await _ground_dash()
	for frame in [6, 12, 18, 24]:
		await _jump_dash("running jump + forward dash @%df" % frame, frame, Vector2(1, 0))
	for frame in [6, 12, 18]:
		await _jump_dash("running jump + up-forward dash @%df" % frame, frame, Vector2(1, -1))
	for frame in [6, 12, 18]:
		await _jump_dash("standing jump + UP dash @%df" % frame, frame, Vector2(0, -1), false)
	print("\n=== SPRINGS (up) ===")
	await _spring("spring, no steer", 0, -1)
	await _spring("spring, steer right", 1, -1)
	for frame in [12, 18, 24, 30]:
		await _spring("spring + up dash @%df" % frame, 0, frame, Vector2(0, -1))
	for frame in [18, 30]:
		await _spring("spring + up-fwd dash @%df" % frame, 1, frame, Vector2(1, -1))
	print("\n=== SIDE SPRING (Right) ===")
	await _side_spring("side spring, hold right", -1)
	await _side_spring("side spring + fwd dash @12f", 12)
	print("")
	get_tree().quit(0)


func _reset(x := start_x) -> void:
	_release()
	player.respawn(Vector2(x, FLOOR_Y - 6))
	player.input_locked = false
	player.velocity = Vector2.ZERO
	await _frames(12)


## Run up to full speed before `x0`, then press jump on reaching it.
func _run_up(x0: float) -> void:
	await _reset(x0 - 160)
	Input.action_press("move_right")
	while player.global_position.x < x0:
		await _frames(1)


func _jump(label: String, running: bool, hold: int) -> void:
	if running:
		await _run_up(start_x)
	else:
		await _reset()
	var x0 := player.global_position.x
	var y0 := player.global_position.y
	Input.action_press("jump")
	var apex := y0
	var frames := 0
	for i in 400:
		await _frames(1)
		if i == hold:
			Input.action_release("jump")
		apex = minf(apex, player.global_position.y)
		frames += 1
		if i > 3 and player.is_on_floor():
			break
	_release()
	print("  %-34s apex %6.1f px  reach %6.1f px  air %3d f"
		% [label, y0 - apex, player.global_position.x - x0, frames])


func _ground_dash() -> void:
	await _reset()
	var x0 := player.global_position.x
	Input.action_press("move_right")
	Input.action_press("dash")
	await _frames(4)
	Input.action_release("dash")
	Input.action_release("move_right")
	await _frames(60)
	print("  %-34s travel %6.1f px (released, to rest)" % ["ground dash", player.global_position.x - x0])


func _jump_dash(label: String, frame: int, dir: Vector2, running := true) -> void:
	if running:
		await _run_up(start_x)
	else:
		await _reset()
	var x0 := player.global_position.x
	var y0 := player.global_position.y
	Input.action_press("jump")
	var apex := y0
	var frames := 0
	for i in 400:
		await _frames(1)
		if i == frame:
			_press_dir(dir)
			Input.action_press("dash")
		if i == frame + 4:
			Input.action_release("dash")
			Input.action_release("move_up")
			if not running:
				Input.action_release("move_right")
		apex = minf(apex, player.global_position.y)
		frames += 1
		if i > 3 and player.is_on_floor():
			break
	_release()
	print("  %-34s apex %6.1f px  reach %6.1f px  air %3d f"
		% [label, y0 - apex, player.global_position.x - x0, frames])


func _spawn_spring(x: float, facing := 0) -> SpringPlatform:
	var spring: SpringPlatform = load("res://scenes/props/platforms/SpringPlatform.tscn").instantiate()
	spring.refill_dash = true
	spring.rotation_degrees = 90.0 * facing
	spring.position = Vector2(x, FLOOR_Y - 4) if facing == 0 else Vector2(x, FLOOR_Y - 8)
	add_child(spring)
	await _frames(2)
	return spring


func _spring(label: String, steer: int, dash_frame: int, dir := Vector2.ZERO) -> void:
	var spring := await _spawn_spring(start_x + 40)
	await _reset(start_x + 22)
	var x0 := spring.position.x
	var y0 := FLOOR_Y - 6
	Input.action_press("move_right")
	var launched := -1
	var apex := y0
	for i in 600:
		await _frames(1)
		if launched < 0 and player.velocity.y < -200:
			launched = i
			if steer == 0:
				Input.action_release("move_right")
		if launched >= 0:
			var t := i - launched
			if t == dash_frame:
				_press_dir(dir)
				Input.action_press("dash")
			if t == dash_frame + 4:
				Input.action_release("dash")
				Input.action_release("move_up")
			apex = minf(apex, player.global_position.y)
			if t > 5 and player.is_on_floor():
				break
	_release()
	spring.queue_free()
	print("  %-34s apex %6.1f px  drift %6.1f px" % [label, y0 - apex, player.global_position.x - x0])


func _side_spring(label: String, dash_frame: int) -> void:
	var spring := await _spawn_spring(start_x + 40, 1)
	await _reset(start_x + 24)
	# The right-facing face is on the spring's right; approach it from there.
	player.global_position = Vector2(spring.position.x + 12, FLOOR_Y - 6)
	await _frames(2)
	var x0 := player.global_position.x
	Input.action_press("move_left")
	var launched := -1
	var apex := FLOOR_Y - 6.0
	for i in 400:
		await _frames(1)
		if launched < 0 and player.velocity.x > 150:
			launched = i
			Input.action_release("move_left")
			Input.action_press("move_right")
			Input.action_press("jump")
		if launched >= 0:
			var t := i - launched
			if t == 3:
				Input.action_release("jump")
			if t == dash_frame:
				Input.action_press("dash")
			if t == dash_frame + 4:
				Input.action_release("dash")
			apex = minf(apex, player.global_position.y)
			if t > 5 and player.is_on_floor():
				break
		elif i > 120:
			break
	_release()
	spring.queue_free()
	print("  %-34s launched %s  reach %6.1f px  apex %5.1f" % [label, launched >= 0, player.global_position.x - x0, FLOOR_Y - 6 - apex])


func _press_dir(dir: Vector2) -> void:
	if dir.x > 0:
		Input.action_press("move_right")
	if dir.y < 0:
		Input.action_press("move_up")


func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "dash"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
