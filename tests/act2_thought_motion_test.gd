extends Node
## Run windowed: verifies real Godot shader pixels, irregular eyes, and fixed cells.
const OUT := "res://output/act2_thought_motion"
var failures := 0


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var view := SubViewport.new()
	view.size = Vector2i(320, 180)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	var layer := ThoughtHazardLayer.new()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://ldtk/art/act2_thought_tiles.png")
	atlas.texture_region_size = Vector2i(8, 8)
	for y in 6:
		for x in 4:
			atlas.create_tile(Vector2i(x, y))
	layer.tile_set = TileSet.new()
	layer.tile_set.tile_size = Vector2i(8, 8)
	layer.tile_set.add_source(atlas, 207)
	layer.collision_enabled = false
	for x in range(3, 37):
		layer.set_cell(Vector2i(x, 17), 207, Vector2i(1, 0))
	for y in range(5, 12):
		layer.set_cell(Vector2i(5, y), 207, Vector2i(2, 0))
	for x in range(13, 21):
		for y in range(7, 10):
			layer.set_cell(Vector2i(x, y), 207, Vector2i.ZERO)
	for x in [26, 30, 34]:
		layer.set_cell(Vector2i(x, 8), 207, Vector2i(3, 0))
	var cells := layer.get_used_cells()
	view.add_child(layer)
	check(is_instance_valid(layer._procedural_dust), "Act 2's real atlas selects Godot dust renderer")
	if not is_instance_valid(layer._procedural_dust):
		get_tree().quit(1)
		return
	var dust = layer._procedural_dust
	dust.set_process(false)
	check(dust.motion_variation == 1.0, "varied per-cell motion enabled")
	var first: Image
	var animated := false
	var moving_edge := false
	var different_cells := false
	var blinking := false
	var glancing := false
	var red_pixels := 0
	var initial_eyes: Array[Vector2] = []
	for eye in dust.eyes:
		initial_eyes.append(eye.direction)
	for tick in 36:
		dust._process(0.2 if tick > 0 else 0.0)
		await RenderingServer.frame_post_draw
		var shot := view.get_texture().get_image()
		shot.save_png("%s/frame_%02d.png" % [OUT, tick])
		if tick == 0:
			first = shot
			for y in shot.get_height():
				for x in shot.get_width():
					var color := shot.get_pixel(x, y)
					if color.a > 0.9 and color.r > 0.3 and color.r > color.g * 2.0:
						red_pixels += 1
		elif shot.get_data() != first.get_data():
			animated = true
			var pixels := shot.get_data()
			var original := first.get_data()
			for i in range(3, pixels.size(), 4):
				if pixels[i] != original[i]:
					moving_edge = true
		# Compare only alpha: two isolated cells must have different silhouettes,
		# not merely different eye colors or body dither.
		for y in 12:
			for x in 12:
				if shot.get_pixel(26 * 8 - 2 + x, 8 * 8 - 2 + y).a != shot.get_pixel(30 * 8 - 2 + x, 8 * 8 - 2 + y).a:
					different_cells = true
		for i in dust.eyes.size():
			blinking = blinking or dust.eye_visibility(dust.eyes[i]) != Vector2i.ONE
			glancing = glancing or Vector2(dust.eyes[i].direction).distance_to(initial_eyes[i]) > 0.2
	check(animated and moving_edge, "rendered bodies and silhouettes animate")
	check(different_cells, "neighboring thoughts have independent silhouettes")
	check(red_pixels > 100, "moving mass retains a visible red hazard outline")
	check(blinking and glancing, "eyes blink and glance during the rendered sequence")
	check(layer.get_used_cells() == cells and not layer.collision_enabled,
		"animation leaves the painted hazard cells fixed and pass-through")
	# Renderer responds to paint removal without leaving a visible phantom hazard.
	layer.clear()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(layer._procedural_dust), "erasing the brush removes its procedural art")
	# Check the current imported game, not just the standalone rendering fixture.
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Prison_R01"
	var world: LdtkWorld = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.current_room != null and world.current_room.name == "Prison_R01",
		"actual Act 2 world enters the prison test room")
	var imported := world.current_room.get_node_or_null("ThoughtHazards") as ThoughtHazardLayer
	check(imported != null and imported.get_used_cells().size() == 21
		and is_instance_valid(imported._procedural_dust),
		"imported prison hazard cells activate the new renderer")
	world.queue_free()
	await get_tree().process_frame
	print("ACT2 THOUGHT MOTION: %d failures; rendered frames in %s" % [failures, OUT])
	get_tree().quit(1 if failures else 0)
