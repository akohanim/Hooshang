extends Node
## Exercises the expanded nine-room world, finite panorama coverage, camera
## continuity, backtracking, and a single sun fixed within the painting.
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures.append(label)

func _ready() -> void:
	SaveGame.slot = -1
	var world = load("res://ldtk/Act2World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 120:
		await get_tree().process_frame
		if world.player != null and not world.rooms.is_empty():
			break
	var bd = world.get_node("Backdrop/SkyBackdrop")
	for i in 120:
		if bd._bounds.size != Vector2.ZERO:
			break
		await get_tree().process_frame
	world.player.set_physics_process(false)
	world.get_node("Act2Beats").set_process(false)
	_check(world.rooms.size() == 9, "all nine authored rooms loaded")
	var size := Vector2(320, 180)
	var offsets: Array[float] = []
	var authored = JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/hooshang_act2.ldtk"))
	for room in world.rooms:
		var rect: Rect2 = world.room_rect(room)
		for level in authored.levels:
			if level.identifier == str(room.name):
				_check(rect == Rect2(level.worldX, level.worldY, level.pxWid, level.pxHei),
					"%s uses Act 2 geometry, not a same-named Act 1 import" % room.name)
		var old_image = room.get_node_or_null("BG Image")
		_check(old_image == null or not old_image.visible, "%s legacy painting cannot cover the panorama" % room.name)
		for corner in [rect.position, rect.end - size]:
			bd._frame_view(Rect2(corner, size), size)
			var art_rect := Rect2(bd.landscape.position, bd.landscape.texture.get_size() * bd.landscape.scale)
			_check(art_rect.encloses(Rect2(Vector2.ZERO, size)), "%s panorama covers camera at %s" % [room.name, corner])
			var expected: Vector2 = bd.landscape.texture.get_size() * bd.landscape.scale * bd.sun_anchor
			_check((bd.sun.position - bd.landscape.position).is_equal_approx(expected),
				"%s sun stays anchored to the painting at %s" % [room.name, corner])
		bd._frame_view(Rect2(rect.get_center() - size * 0.5, size), size)
		offsets.append(bd.landscape.position.x)
	_check(offsets[0] > offsets[1] and offsets[1] > offsets[2], "each successive room reveals a new stretch of painting")
	_check(bd.get_child_count() == 3 and bd.has_node("Landmarks") and bd.sun.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED,
		"one panorama, one landmark gallery and exactly one non-repeating sun sprite")
	bd._frame_view(Rect2(bd._bounds.position + Vector2(100, 100), size), size)
	var sun_before: Vector2 = bd.sun.position
	var art_before: Vector2 = bd.landscape.position
	bd._frame_view(Rect2(bd._bounds.position + Vector2(400, 300), size), size)
	var art_motion: Vector2 = bd.landscape.position - art_before
	_check(absf(art_motion.x) > 10.0 and absf(art_motion.y) > 1.0,
		"camera sweep produces meaningful horizontal and vertical scenery travel")
	_check((bd.sun.position - sun_before).is_equal_approx(art_motion),
		"sun moves exactly with the background, never following the player")
	var seam: float = world.room_rect(world.rooms[1]).position.x
	bd._frame_view(Rect2(Vector2(seam - 0.5, 600), size), size)
	var before: Vector2 = bd.landscape.position
	bd._frame_view(Rect2(Vector2(seam + 0.5, 600), size), size)
	_check(bd.landscape.position.distance_to(before) < 1.0, "camera crosses room boundary without resetting the painting")
	bd._frame_view(Rect2(Vector2(seam - 0.5, 600), size), size)
	_check(bd.landscape.position == before, "backtracking returns to exactly the same artwork")
	# Drive actual transitions: room signals must not snap the painting.
	world._enter_room(world.rooms[0], true)
	bd._process(0.0)
	before = bd.landscape.position
	world._slide_to_room(world.rooms[1])
	_check(bd.landscape.position == before, "transition start does not re-anchor the landscape")
	await get_tree().create_timer(0.6).timeout
	if DisplayServer.get_name() != "headless":
		await _capture(world)
	print("ACT 2 PANORAMA: %s" % ("ALL PASS" if failures.is_empty() else str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture(world) -> void:
	DirAccess.make_dir_recursive_absolute("res://output/act2_panorama")
	var camera: Camera2D = world.player.camera
	camera.position_smoothing_enabled = false
	for room in world.rooms:
		world._enter_room(room, true)
		var rect: Rect2 = world.room_rect(room)
		world.player.global_position = Vector2(rect.get_center().x, rect.end.y - 90)
		camera.reset_smoothing()
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot := Screen.viewport.get_texture().get_image()
		shot.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		shot.save_png("res://output/act2_panorama/%s.png" % room.name)
		if str(room.name) == "Act_2_Level_1":
			var backdrop = world.get_node("Backdrop/SkyBackdrop")
			for phase in [0.6, 0.8, 1.0, 0.0]:
				backdrop.set_sun_descent(phase)
				for i in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var phase_shot := Screen.viewport.get_texture().get_image()
				phase_shot.resize(1280, 720, Image.INTERPOLATE_NEAREST)
				phase_shot.save_png("res://output/act2_panorama/sun_phase_%s.png" % str(phase))
