extends Node
## Render the actual dialogue banner over Act 1, plus a labeled art contact sheet.
## This dev-only harness never writes a save. --capture closes after screenshots.
const OUT := "res://output/hooshang_cardigan/"
var world: LdtkWorld

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_0"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	# Remove automatic story staging before _ready; this harness drives dialogue.
	for child in world.get_children():
		if child is Act1Beats:
			world.remove_child(child)
			child.free()
	Screen.set_scene(world)
	for i in 60:
		await get_tree().process_frame
	world.player.input_locked = true
	world.player.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _contact_sheet()
	var samples := {
		"dazed": "Where am I?",
		"confused": "This doesn't feel like my cubicle...",
		"skeptical": "A journey? I just wanted to make it to my car.",
		"shocked": "It's... gone?",
		"deflecting": "Look this really isn't a good time. I just lost my job.[p] I'll get to all that[p] ...Later."
	}
	for state: String in samples:
		Dialogue.say("Hooshang", samples[state], Color.WHITE, Act1Beats.FACES[state], DialogueBox.Side.LEFT, DialogueBox.VSide.TOP)
		await get_tree().create_timer(0.7).timeout
		Dialogue.set_process(false)
		Dialogue._finish_reveal_instantly()
		for f in [0, 2, 7, 12]:
			Dialogue._show_frame(Dialogue.portrait_loop, f)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OUT + "%s_%02d.png" % [state, f])
		Dialogue.set_process(true)
		while Dialogue._active:
			Dialogue.line_finished.emit()
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
	if OS.get_cmdline_user_args().has("--capture"):
		print("CARDIGAN PREVIEW: captures saved")
		get_tree().quit()
	else:
		for state: String in Act1Beats.FACES:
			await Dialogue.say("Hooshang", samples.get(state, "A moment to speak, [p] and a moment to listen."), Color.WHITE, Act1Beats.FACES[state])
		get_tree().quit()

func _contact_sheet() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 120
	overlay.scale = Vector2(0.25, 0.25)
	add_child(overlay)
	var bg := ColorRect.new()
	bg.color = Color("24221f")
	bg.size = Vector2(1280, 720)
	overlay.add_child(bg)
	var states := Act1Beats.FACES.keys()
	for i in states.size():
		var x := 42.0 + (i % 8) * 155.0
		var y := 65.0 + (i / 8) * 324.0
		var tex := TextureRect.new()
		tex.texture = Act1Beats.FACES[states[i]]
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.position = Vector2(x, y)
		tex.size = Vector2(140, 140)
		overlay.add_child(tex)
		var label := Label.new()
		label.text = str(states[i]).capitalize()
		label.position = Vector2(x, y + 148)
		label.add_theme_font_size_override("font_size", 18)
		overlay.add_child(label)
		var pose := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/portraits/loops/hooshang_%s_sheet.png" % states[i])
		atlas.region = Rect2(12 * 512, 0, 512, 512)
		pose.texture = atlas
		pose.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pose.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pose.position = Vector2(x, y + 182)
		pose.size = Vector2(106, 106)
		overlay.add_child(pose)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "all_expressions.png")
	overlay.queue_free()
	await get_tree().process_frame
