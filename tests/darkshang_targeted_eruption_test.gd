extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func _ready() -> void:
	var player: Player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(140,60)
	var boss: Darkshang = preload("res://scenes/props/chase/Darkshang.tscn").instantiate()
	boss.auto_start = false
	add_child(boss)
	boss.set_physics_process(false)
	boss.buffer.set_physics_process(false)
	boss._player = player
	boss.start_chase()
	boss._tick_power_entry(.5)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(100,104)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120,8)
	collider.shape = shape
	floor_body.add_child(collider)
	add_child(floor_body)
	var strip = preload("res://scenes/props/chase/powers/ShadowEruption.tscn").instantiate()
	strip.position = Vector2(100,96)
	strip.size = Vector2(16,8)
	add_child(strip)
	strip.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(strip.activate(.5),"delayed eruption schedules")
	strip._physics_process(.2)
	check(strip.position == Vector2(100,96) and not strip.target_locked,"waiting strip has not selected target")
	player.position.x = 130
	strip._physics_process(.31)
	check(strip.position == Vector2(130,96) and strip.target_locked,"warning targets current position rather than trigger-time position")
	player.position.x = 60
	strip._physics_process(.2)
	check(strip.position == Vector2(130,96) and not strip.is_lethal(),"warning remains fixed and safe after player moves")
	strip.reset()
	check(strip.position == Vector2(100,96),"reset restores authored placement")
	strip.activate()
	strip._physics_process(.01)
	check(strip.position == Vector2(60,96),"different player position changes next attempt")
	strip.reset()
	player.position.x = 220
	strip.activate()
	strip._physics_process(.01)
	check(strip.position.x <= 152 and strip.position.x > 100,"complete strip stays on platform instead of chasing into gap")
	strip.reset()
	var reserved = preload("res://scenes/props/chase/powers/ShadowEruption.tscn").instantiate()
	reserved.position = Vector2(140,96)
	reserved.size = Vector2(16,8)
	add_child(reserved)
	reserved.set_physics_process(false)
	reserved.activate(5)
	strip.activate()
	strip._physics_process(.01)
	check(strip.position.x <= 120,"targeting reserves space for later spikes in the sequence")
	reserved.reset()
	reserved.queue_free()
	strip.reset()
	var checkpoint := Checkpoint.new()
	checkpoint.position = Vector2(132,94)
	add_child(checkpoint)
	strip.activate()
	strip._physics_process(.01)
	check(strip.position.x <= 116,"targeting preserves checkpoint refuge")
	strip.reset()
	check(not strip.target_locked and strip.elapsed < 0,"reset clears target and timing")
	player.position = Vector2(60,94)
	player.invulnerable_timer = 0
	strip.activate()
	strip._physics_process(.01)
	check(strip.position.x == 60 and player.state != Player.State.DEAD,"targeted warning is harmless under player")
	strip._physics_process(strip.warning_time)
	check(player.state == Player.State.DEAD and strip.position == Vector2(100,96),"targeted spikes kill at new position and death restores anchor")
	# A real controller response can escape a warning aimed beneath the player.
	player.respawn(Vector2(100,94))
	player.input_locked = false
	player.set_physics_process(true)
	for i in 4: await get_tree().physics_frame
	boss._holding_entry = false
	boss.visible = true
	boss.state = Darkshang.State.FOLLOWING
	boss._tick_power_entry(.5)
	strip.set_physics_process(true)
	check(strip.activate(),"reactive dodge trial activates")
	for i in 100:
		if i == 30:
			Input.action_press("jump")
			Input.action_press("move_left")
		if i == 45:
			Input.action_release("jump")
			Input.action_release("move_left")
		await get_tree().physics_frame
	Input.action_release("jump")
	Input.action_release("move_left")
	check(player.state != Player.State.DEAD and player.position.x < 88,"jumping away from targeted warning survives eruption")
	print("TARGETED ERUPTIONS: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
