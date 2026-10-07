extends Node
var player: Player
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func arc(spring := false, running := true, hold := 60) -> Vector3:
	Input.action_release("jump")
	Input.action_release("move_right")
	player.respawn(Vector2(80, 140))
	await frames(30)
	if running: Input.action_press("move_right")
	await frames(30)
	var start := player.position
	var peak := start.y
	var ticks := 0
	if spring: player.bounce(415, 0.77)
	else: Input.action_press("jump")
	for i in 180:
		await frames(1)
		ticks += 1
		peak = minf(peak, player.position.y)
		if i + 1 == hold: Input.action_release("jump")
		if i > 2 and player.is_on_floor(): break
	Input.action_release("jump")
	Input.action_release("move_right")
	return Vector3(start.y - peak, player.position.x - start.x, ticks)
func _ready() -> void:
	SaveGame.slot = -1
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(2000, 16)
	floor_body.position = Vector2(800, 168)
	floor_body.add_child(shape)
	add_child(floor_body)
	player = load("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	var normal := await arc()
	var normal_spring := await arc(true)
	var world := LdtkWorld.new()
	world.player = player
	var profile := Act2Beats.new()
	profile._world = world
	profile._apply_child_movement()
	profile._apply_child_movement()
	check(is_equal_approx(player.max_run_speed, 67.5), "World 2 uses the measured normal-run cap; profile is idempotent")
	var child := await arc()
	var child_spring := await arc(true)
	print("Jump before/after (height, reach, frames): ", normal, " / ", child)
	print("Spring before/after (height, reach, frames): ", normal_spring, " / ", child_spring)
	check(child.z > normal.z, "child jump has a gentler, longer arc")
	check(absf(child.x - 40.5) < 2 and absf(child.z - 61) <= 3, "running jump follows the half-scale ROM arc")
	check(child_spring.z > normal_spring.z, "spring flight has the same slower cadence")
	check(absf(child_spring.x - normal_spring.x) < 3 and absf(child_spring.y - normal_spring.y) < 5, "spring retains its authored height and reach")
	check(player.jump_buffer_time == 0.1 and player.coyote_time == 0.1, "rejected input-forgiveness changes remain removed")
	for sample in [[1, 16.5, 28], [4, 20.0, 31], [8, 24.0, 35], [60, 32.0, 54]]:
		var measured := await arc(false, false, sample[0])
		print("Standing hold %df: %s" % [sample[0], measured])
		check(absf(measured.x - sample[1]) < 2 and absf(measured.z - sample[2]) <= 3, "hold %df follows measured ROM height/airtime" % sample[0])
	player.respawn(Vector2(80, 140))
	await frames(30)
	Input.action_press("move_right")
	await frames(6)
	check(player.velocity.x > 10 and player.velocity.x < 25, "run builds gradually instead of reaching cap in six frames")
	await frames(30)
	Input.action_press("jump")
	await frames(5)
	Input.action_release("move_right")
	var air_speed := player.velocity.x
	await frames(8)
	check(is_equal_approx(player.velocity.x, air_speed), "letting go in the air retains momentum")
	Input.action_release("jump")
	await frames(80)
	Input.action_press("move_right")
	await frames(30)
	Input.action_press("move_left")
	Input.action_release("move_right")
	await frames(3)
	check(player.velocity.x > 0, "reversal has a visible braking phase")
	await frames(15)
	check(player.velocity.x < 0, "holding reverse completes the turn")
	Input.action_release("move_left")
	profile.free()
	world.free()
	print("CHILDHOOD TEMPO: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
