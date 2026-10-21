extends Node
## Actual imported Act 2 platforms: no timed/lever/water reset, then re-entry
## and the normal death/respawn lifecycle both restore collision and artwork.
var failures := 0
var world: LdtkWorld

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func room_named(label: String) -> Node2D:
	for room in world.rooms:
		if str(room.name) == label: return room
	return null

func first_platform(room: Node) -> CrumblingPlatform:
	for node in get_tree().get_nodes_in_group("crumbling"):
		if node is CrumblingPlatform and room.is_ancestor_of(node): return node
	return null

func collapse(platform: CrumblingPlatform) -> void:
	platform.give_way()
	platform._process(0.01)
	check(platform._falling and not platform.get_collision_layer_value(1), "platform really collapsed")

func restored(platform: CrumblingPlatform) -> bool:
	if platform._spent or platform._falling or not platform.get_collision_layer_value(1): return false
	for block in platform._visual.get_children():
		if block.modulate.a != 1.0 or block.position != block.get_meta("rest"): return false
	return true

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Prison_R01"
	world = load("res://ldtk/Act2World.tscn").instantiate()
	var beats := world.get_node("Act2Beats")
	world.remove_child(beats)
	beats.free()
	add_child(world)
	await get_tree().process_frame
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var all_timers_off := true
	for node in get_tree().get_nodes_in_group("crumbling"):
		if world.is_ancestor_of(node): all_timers_off = all_timers_off and node.respawn_time == 0.0
	check(all_timers_off, "all imported World 2 platforms have automatic rebuilding disabled")
	var other := room_named("Prison_Hub")
	for label in ["Prison_R01", "Prison_R02", "Prison_B03", "Act_2_Level_5"]:
		var room := room_named(label)
		var platform := first_platform(room)
		check(platform != null, "%s contains an imported crumbling platform" % label)
		if platform == null: continue
		world._enter_room(room, true)
		platform.set_process(false)
		world.player.global_position = room.global_position + Vector2(40, -40)
		collapse(platform)
		platform._process(60.0)
		check(platform._falling and not platform.get_collision_layer_value(1), "%s stays gone after a minute" % label)
		if label == "Prison_R02":
			var gate = world.timed_reference(platform.fields.get("Gate", ""))
			check(gate != null, "shelf has a real linked puzzle")
			if gate != null:
				world.timers.start(str(gate.fields.get("PuzzleId", "")))
			check(platform._falling, "using the linked lever does not restore the shelf")
		if label == "Prison_B03":
			world.player.enter_swim(world)
			check(world.player.swimming(), "water-return control really enters swimming")
			for i in 5: await get_tree().physics_frame
			check(platform._falling, "returning to water does not restore the swim platform")
			world.player.exit_swim(world)
		world._enter_room(room, false)
		check(platform._falling, "refreshing the same room does not restore %s" % label)
		world._enter_room(other, true)
		check(platform._falling, "leaving %s keeps its platform gone until re-entry" % label)
		world._enter_room(room, true)
		check(restored(platform), "re-entering %s restores collision and artwork" % label)
		world.player.global_position = room.global_position + Vector2(40, -40)
		collapse(platform)
		# Movement is paused in this fixture, so explicitly finish the previous
		# respawn's 0.1-second immunity before testing the next death.
		world.player.invulnerable_timer = 0.0
		world.player.die()
		for i in 120:
			await get_tree().physics_frame
			if world.player.state != Player.State.DEAD and restored(platform): break
		check(world.player.state != Player.State.DEAD and restored(platform), "real death/respawn restores %s" % label)
	world.queue_free()
	await get_tree().process_frame
	print("ACT2 CRUMBLE LIFECYCLE: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
