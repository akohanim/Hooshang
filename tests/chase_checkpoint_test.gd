extends Node
var failures := 0
var world: LdtkWorld
var shadow: Darkshang
var trigger: DarkshangTrigger
var reveal_count := 0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_14"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(20)
	var room := world.current_room
	var entrance := world.spawn_point_for(room)
	shadow = get_tree().get_first_node_in_group("darkshang") as Darkshang
	for node in get_tree().get_nodes_in_group("darkshang_trigger"):
		if room.is_ancestor_of(node): trigger = node
	trigger.triggered.connect(func(_player: Player) -> void: reveal_count += 1)
	await die_and_wait()
	check(world._checkpoint == entrance, "death before the encounter keeps the entrance checkpoint")
	world.player.global_position = trigger.global_position + Vector2(-12, 0)
	trigger._on_body_entered(world.player)
	check(world._checkpoint == entrance, "starting the dialogue does not bank a chase checkpoint")
	var lines := 0
	for i in 480:
		await frames(1)
		if Dialogue._active:
			Dialogue._finish_reveal_instantly()
			Dialogue.line_finished.emit()
			lines += 1
		if shadow.state == Darkshang.State.FOLLOWING and not world.player.input_locked:
			break
	check(lines >= 6, "completed the actual Hooshang/Rumi encounter dialogue")
	var checkpoint := world._checkpoint
	check(checkpoint.distance_to(entrance) > 300, "finished dialogue banks the encounter instead of the entrance")
	check(checkpoint.distance_to(world.player.global_position) < 2, "checkpoint is the grounded post-dialogue position")
	check(checkpoint.x < shadow.spawn_point.x and shadow.spawn_point.x - checkpoint.x < 160,
		"new checkpoint is safely in front of Darkshang")
	var hatch := world.get_node("EncounterTrapdoor")
	for retry in 2:
		# Travel away, then die through the real world/actor reset callbacks.
		world.player.global_position = checkpoint + Vector2(-80, -12)
		await die_and_wait()
		check(world.player.global_position.distance_to(checkpoint) < 2,
			"retry %d respawns at the encounter" % retry)
		await frames(4)
		check(shadow.state == Darkshang.State.FOLLOWING and shadow._holding_entry,
			"retry %d retains the chase and safe departure hold" % retry)
		check(not hatch.active, "retry keeps the exit hatch closed")
		check(not world.player.input_locked and not Dialogue.visible and trigger.spent and reveal_count == 1,
			"retry does not replay Rumi's dialogue")
		check(world.current_room == room and world._checkpoint == checkpoint, "retry stays in Level 14")
	# Leaving the encounter still gives the next room its own beginning.
	world.player.global_position.x = world.room_rect(room).position.x + 8
	hatch._exit_requested(hatch.target_room)
	for i in 300:
		await frames(1)
		if not hatch.active: break
	check(world.current_room.name == "Level_15" and world._checkpoint == world.spawn_point_for(world.current_room),
		"Level 15 keeps its own checkpoint after the drop")
	print("CHASE CHECKPOINT: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func die_and_wait() -> void:
	world.player.invulnerable_timer = 0.0
	world.player.die()
	for i in 120:
		await frames(1)
		if world.player.state != Player.State.DEAD:
			return
	check(false, "respawn finishes in bounded time")
