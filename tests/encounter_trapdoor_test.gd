extends Node
var failures := 0
var world: LdtkWorld
var hatch: Node2D
var shadow: Darkshang
var source: Node2D
var destination: Node2D
var capture := false

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func _ready() -> void:
	SaveGame.slot = -1
	capture = OS.get_cmdline_user_args().has("--capture")
	LdtkWorld.debug_start_room = "Level_14"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 20: await get_tree().physics_frame
	hatch = world.get_node("EncounterTrapdoor")
	shadow = get_tree().get_first_node_in_group("darkshang") as Darkshang
	shadow.set_physics_process(false)
	source = hatch.source_room
	destination = hatch.target_room
	check(is_equal_approx(hatch.get_node("Metal").stream.get_length(), 0.1), "opening sound lasts 100 ms")
	check(not hatch.has_node("Creak"), "opening has no sustained creak layer")
	prepare()
	for node in get_tree().get_nodes_in_group("darkshang_trigger"):
		if source.is_ancestor_of(node): node.chase_begun.emit()
	# Tick twenty seconds of live pursuit without moving to the exit.
	# Disable only the pursuer/player so neither a catch nor travel hides a timer.
	for i in 1201:
		await get_tree().physics_frame
	check(not hatch.active and world.current_room == source,
		"twenty seconds of pursuit cannot open the hatch away from the exit")
	world.player.input_locked = true
	hatch._exit_requested(destination)
	check(not hatch.active, "dialogue-owned player cannot begin the drop")
	world.player.input_locked = false
	# Exercise the real return Area2D, which is Level 14's escape exit.
	prepare()
	world.set_way_back(source, "Level_15")
	var previous: Node2D
	for room in world.rooms:
		if room.name == "Level_13": previous = room
	# Let the previous visit's deferred monitoring disable settle first.
	for i in 2: await get_tree().physics_frame
	world._arm_return(previous)
	for i in 4: await get_tree().physics_frame
	world.player.global_position.x = world._return_zone.global_position.x
	for i in 8: await get_tree().physics_frame
	check(hatch.active, "actual exit overlap opens the hatch")
	check(is_equal_approx(hatch.global_position.x, world.room_rect(source).position.x + 16.0),
		"exit hatch opens sixteen pixels inside the level edge")
	hatch.request_drop() # A repeated request must not start a second transition.
	await finish_drop("exit")
	check(world._checkpoint == world.spawn_point_for(destination), "Level 15 beginning is the new checkpoint")
	check(not world.player.input_locked and not world.player._frozen, "get-up gives controls back immediately")
	check(world.player.is_on_floor(), "get-up finishes standing on real floor")
	check(hatch._tiles.is_empty(), "departure floor is restored")
	check(world._return_room == null, "trapdoor arrival cannot return to Level 14")
	world._on_return_entered(world.player)
	check(world.current_room == destination, "stale return overlap cannot reverse the drop")
	check(world.current_room == destination, "exit also lands at Level 15's beginning")
	check(not hatch.active, "one transition completes once despite repeated requests")
	# The player can reach the exit while jumping or dashing.
	prepare()
	world.player.global_position = Vector2(world.room_rect(source).position.x + 8, world.player.global_position.y - 48)
	world.player.state = Player.State.DASH
	world.player.dash_timer = 0.15
	world.player.velocity = Vector2(260, -260)
	hatch.request_drop()
	await finish_drop("airborne")
	check(world.current_room == destination and world.player.dash_timer == 0.0,
		"airborne drop lands safely without resuming the interrupted dash")
	# Fresh boot and old reciprocal save data must not rebuild the return door.
	LdtkWorld.debug_start_room = "Level_15"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 20: await get_tree().physics_frame
	check(world.current_room.name == "Level_15" and world._return_room == null,
		"fresh Level 15 boot has no route back through the hatch")
	var old_source: Node2D
	for room in world.rooms:
		if room.name == "Level_14": old_source = room
	world.set_way_back(old_source, "Level_15")
	world._arm_return(old_source)
	for i in 3: await get_tree().physics_frame
	check(world._return_room == null and not world._return_zone.monitoring,
		"legacy reciprocal route cannot re-arm the one-way hatch")
	print("ENCOUNTER TRAPDOOR: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func prepare() -> void:
	world._clear_return()
	world._enter_room(source, true)
	world.player.input_locked = false
	world.player.invulnerable_timer = 1000
	world.player.set_physics_process(false)
	world.player.state = Player.State.FALL
	shadow.start_chase()
	shadow._holding_entry = false
	shadow.visible = true

func finish_drop(label: String) -> void:
	var deaths := Deaths.total
	var saw_hole := false
	var saw_open := false
	var saw_prone := false
	var saw_standing := false
	var saw_locked := false
	var fall_frames := 0
	var hover_frames := 0
	var hover_position := Vector2.INF
	var hover_poses := {}
	var hover_stayed_still := true
	var hover_open := true
	for i in 360:
		await get_tree().physics_frame
		if not hatch._tiles.is_empty() and not saw_hole:
			saw_hole = true
			if capture: await shot(label + "_hatch")
		if hatch.opening > 0.8 and not saw_open and world.current_room == source:
			saw_open = true
			if capture: await shot(label + "_open")
		if hatch.hovering:
			if hover_position == Vector2.INF: hover_position = world.player.global_position
			hover_frames += 1
			hover_stayed_still = hover_stayed_still and world.player.global_position.is_equal_approx(hover_position)
			hover_open = hover_open and is_equal_approx(hatch.opening, 1.0) and not hatch._tiles.is_empty()
			hover_poses[world.player.visual.frame] = true
			if capture and hover_frames in [3, 12]: await shot(label + "_flail_%d" % hover_frames)
		elif world.current_room == source and hatch.opening >= 1.0:
			fall_frames += 1
		var recovery := world.player.get_node_or_null("FallRecovery")
		if recovery != null:
			saw_locked = world.player.input_locked and world.player._frozen
			var pose := recovery.get_node("Pose") as AnimatedSprite2D
			if pose.animation == &"fall" and not saw_prone:
				saw_prone = true
				if capture: await shot(label + "_prone")
			if pose.animation == &"idle": saw_standing = true
		if not hatch.active: break
	check(not hatch.active, "%s transition completes in bounded time" % label)
	check(absf(float(hover_frames) / Engine.physics_ticks_per_second - 0.6) < 0.04,
		"%s lingers for 0.6 seconds" % label)
	check(hover_stayed_still and hover_open, "%s holds midair above fully open leaves" % label)
	check(hover_poses.size() >= 3, "%s cycles flailing arm poses during the hold" % label)
	check(fall_frames > 8 and fall_frames < 60, "%s releases into a natural fall after hovering" % label)
	check(saw_hole, "%s opens real floor cells" % label)
	check(saw_prone and saw_standing, "%s plays prone then standing poses" % label)
	check(saw_locked, "%s landing owns physics only during its animation" % label)
	check(Deaths.total == deaths, "%s fall adds no death" % label)
	if capture: await shot(label + "_standing")

func shot(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("res://output/trapdoor")
	var image: Image = Screen.viewport.get_texture().get_image()
	image.resize(1280,720,Image.INTERPOLATE_NEAREST)
	image.save_png("res://output/trapdoor/" + label + ".png")
