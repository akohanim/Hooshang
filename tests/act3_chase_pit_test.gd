extends Node
## Actual imported chase geometry: fall into each former hiding pocket, jump
## out without a dash, then stand there while a tiger catches up at rim height.

var failures := 0
var world: SeaWorld


func _ready() -> void:
	SaveGame.unbind()
	Sfx.muted = true
	LdtkWorld.debug_start_room = "Act3_Level_29"
	world = load("res://ldtk/Act3World.tscn").instantiate()
	world.set_meta("no_beats", true)
	Screen.set_scene(world)
	await frames(30)
	for spec in [["Act3_Level_29", 20], ["Act3_Level_30", 22]]:
		await pit_check(str(spec[0]), int(spec[1]))
	await gait_check()
	print("ACT3 CHASE PITS: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func pit_check(name: String, first_column: int) -> void:
	var room: Node2D
	for candidate in world.rooms:
		if str(candidate.name) == name:
			room = candidate
	world._enter_room(room, true)
	await frames(8)
	var player := world.player
	var start := room.global_position + Vector2(first_column * 8 + 12, 116)
	player.respawn(start)
	await frames(40)
	check(player.is_on_floor() and absf(player.global_position.y + Player.HALF_HEIGHT - room.global_position.y - 136) < 1.0,
		name + " missed jump lands in a shallow ditch, not the old deep pocket")
	var sea := world.sea_room(room)
	var art := room.get_node("Collisions") as TileMapLayer
	for x in range(first_column, first_column + 3):
		check(sea.value_at(Vector2i(x, 17)) == 1 and art.get_cell_source_id(Vector2i(x, 17)) != -1,
			name + " visible floor matches collision")
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(12)
	Input.action_release("jump")
	await frames(65)
	Input.action_release("move_right")
	check(player.global_position.x > room.global_position.x + (first_column + 3) * 8,
		name + " a normal jump returns to the path without spending a dash")
	player.respawn(start)
	await frames(40)
	var tiger := ChaseTiger.new()
	world.add_child(tiger)
	tiger.chase(player)
	tiger._hold_at = Vector2.INF
	tiger._xs = PackedFloat32Array([player.global_position.x - 48, player.global_position.x + 16])
	tiger._ys = PackedFloat32Array([room.global_position.y + 122, room.global_position.y + 122])
	tiger._x = player.global_position.x - 24
	tiger.global_position = Vector2(tiger._x, room.global_position.y + 128)
	await capture(name)
	var caught := false
	for i in 90:
		await frames(1)
		if player.state == Player.State.DEAD:
			caught = true
			break
	check(caught, name + " waiting in the ditch does not hide below the tiger")
	tiger.queue_free()
	await frames(60)


func gait_check() -> void:
	var tiger := ChaseTiger.new()
	add_child(tiger)
	tiger._update_gait(64.0)
	tiger.visual.set_frame_and_progress(6, 0.5)
	tiger._update_gait(24.0)
	check(tiger.visual.animation == &"run", "pace near threshold does not flicker between gaits")
	tiger._update_gait(18.0)
	check(tiger.visual.animation == &"walk" and tiger.visual.frame == 6,
		"slowing transfers stride phase rather than restarting the feet")
	tiger._update_gait(64.0)
	var normal := tiger.visual.speed_scale
	tiger._update_gait(92.0)
	check(tiger.visual.speed_scale > normal, "catch-up strides track the extra travel")
	tiger._update_gait(0.0)
	check(tiger.visual.animation == &"idle" and tiger.visual.speed_scale == 1.0,
		"waiting plays its own idle rather than moving feet on the spot")
	tiger.visual.play(&"walk")
	tiger._last_visual_position = tiger.global_position
	tiger.global_position.x += 6.0
	tiger._process(0.25)
	var fast := tiger.visual.speed_scale
	tiger.global_position.x += 3.0
	tiger._process(0.25)
	check(tiger.visual.speed_scale < fast, "cinematic pacing also slows its steps with travel")
	tiger._process(0.25)
	check(tiger.visual.speed_scale == 0.0, "a pacing turn pauses the feet")
	tiger.visual.play(&"roar")
	tiger._process(0.25)
	check(tiger.visual.speed_scale == 1.0, "standing after a walk cannot freeze the roar")
	tiger.queue_free()
	# A sharp 8px route lip must take several frames to traverse vertically.
	var follower := ChaseTiger.new()
	world.add_child(follower)
	var player := world.player
	player.freeze()
	follower.chase(player)
	follower._hold_at = Vector2.INF
	follower._xs = PackedFloat32Array([player.global_position.x - 80, player.global_position.x + 8])
	follower._ys = PackedFloat32Array([player.global_position.y - 16, player.global_position.y - 16])
	follower._x = player.global_position.x - 60
	follower.global_position = Vector2(follower._x, player.global_position.y + Player.HALF_HEIGHT)
	var before := follower.global_position.y
	player.input_locked = false
	follower._physics_process(1.0 / 60.0)
	player.freeze()
	var shift := absf(follower.global_position.y - before)
	check(shift > 0.0 and shift <= follower.vertical_follow_speed / 60.0 + 0.01,
		"route height changes ease vertically instead of snapping at a stair")
	follower.queue_free()
	player.unfreeze()


func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var image := Screen.viewport.get_texture().get_image()
	image.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	image.save_png("res://artifacts/act3_finale/%s_recovery.png" % label)


func check(ok: bool, message: String) -> void:
	print(("  PASS " if ok else "  FAIL ") + message)
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
