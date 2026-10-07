extends Node

var failures := 0

func _ready() -> void:
	SaveGame.slot = -1
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	# Geometry probes must not be frozen by the opening story sequence.
	world.get_node("Act1Beats").free()
	add_child(world)
	for i in 10:
		await get_tree().physics_frame
	world.player.input_locked = true
	for room in world.rooms:
		if world._exit_in(room) == null:
			continue
		var at := world._re_entry_point(room)
		var transform := world.player.global_transform
		transform.origin = at
		var body := Rect2(at - Vector2(Player.HALF_WIDTH, Player.HALF_HEIGHT),
			Vector2(Player.HALF_WIDTH, Player.HALF_HEIGHT) * 2.0)
		_check(world.room_rect(room).encloses(body), "%s contains the whole returning body" % room.name)
		var exit := world._exit_in(room)
		var cs := exit.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs != null and cs.shape is RectangleShape2D:
			var size := (cs.shape as RectangleShape2D).size
			_check(not body.intersects(Rect2(cs.global_position - size * 0.5, size)),
				"%s return clears the actual exit box" % room.name)
		var blocked := world.player.test_move(transform, Vector2.ZERO, null, 0.01, true)
		if blocked:
			failures += 1
			print("FAIL return embedded in solids: ", room.name, " local=", at - room.global_position)
	# Exercise the actual return Area, then prove movement and death recovery.
	var five: Node2D
	var six: Node2D
	for room in world.rooms:
		if room.name == "Level_5": five = room
		if room.name == "Level_6": six = room
	world.slide_time = 0.01
	world._enter_room(six, true)
	world.player.global_position = six.global_position + Vector2(60, 30)
	await world._arm_return(five)
	world.player.global_position = Vector2(world._return_zone.global_position.x, six.global_position.y + 30)
	for i in 120:
		await get_tree().physics_frame
		if world.current_room == five and not world._transitioning:
			break
	_check(world.current_room == five, "Level_6 return strip reaches Level_5")
	_check(not world.player.input_locked, "return releases controls")
	var start := world.player.global_position
	Input.action_press("move_left")
	for i in 12:
		await get_tree().physics_frame
	Input.action_release("move_left")
	_check(world.player.global_position.x < start.x - 4.0, "can walk away after returning")
	world.player.die()
	for i in 180:
		await get_tree().physics_frame
		if world.player.state != Player.State.DEAD:
			break
	_check(world.player.state != Player.State.DEAD, "death finishes respawning")
	_check(world.current_room == five, "death retains the return room")
	var transform := world.player.global_transform
	_check(not world.player.test_move(transform, Vector2.ZERO, null, 0.01, true), "respawn is not embedded")
	# A prop can move onto the cached landing after the door was armed.
	world._enter_room(six, true)
	world.player.global_position = six.global_position + Vector2(60, 30)
	world.player.input_locked = true
	await world._arm_return(five)
	var cached := world._return_pos
	var blocker := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(12, 12)
	collider.shape = box
	blocker.add_child(collider)
	add_child(blocker)
	blocker.global_position = cached
	for i in 3:
		await get_tree().physics_frame
	world.player.global_position = Vector2(world._return_zone.global_position.x, six.global_position.y + 30)
	for i in 120:
		await get_tree().physics_frame
		if world.current_room == five and not world._transitioning:
			break
	_check(world.current_room == five, "return still works after geometry changes")
	_check(world._checkpoint.distance_to(cached) > 1.0, "landing is rechecked when the return is used")
	transform.origin = world._checkpoint
	_check(not world.player.test_move(transform, Vector2.ZERO, null, 0.01, true),
		"new landing clears the moved prop")
	blocker.queue_free()
	print("BACKTRACK CLEARANCE: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
