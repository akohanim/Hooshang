extends Node
var failures: Array[String] = []

func _ready() -> void:
	var box: DialogueBox = Dialogue
	box.set_process(false)
	for state: String in ["serene", "warm_open", "sorrowful", "urgent"]:
		var tex: Texture2D = Act1Beats.RUMI_FACES[state]
		box._set_rig(tex)
		_check(not box._loop.is_empty(), state + " loads loop")
		var atlas: AtlasTexture = box.portrait_loop.texture
		var img := atlas.atlas.get_image()
		if img.is_compressed(): img.decompress()
		var rest := img.get_region(Rect2i(0, 0, 256, 256))
		var seen := {}
		box._revealing = true
		box._pause_left = 0.0
		box._blink_left = 999.0
		box._blink_t = -1.0
		var max_changed := 0
		for tick in 40:
			box._animate_loop(0.13)
			var f := roundi(atlas.region.position.x / 256)
			seen[f] = true
			_check(atlas.region.end.x <= img.get_width(), state + " frame bounds")
			var changed := 0
			for y in range(164, 200):
				for x in range(90, 170):
					if img.get_pixel(f * 256 + x, y) != rest.get_pixel(x, y): changed += 1
			max_changed = maxi(max_changed, changed)
		_check(seen.size() >= 2 and max_changed > 80, state + " visibly changes mouth during speech")
		if state in ["sorrowful", "urgent"]:
			_check(seen.has(1) and seen.has(2) and seen.has(3) and seen.has(4), state + " cycles closed, parted, AH, OH")
			for f in range(1, 5):
				var stable := true
				for y in 256:
					for x in 256:
						if Rect2i(84, 162, 90, 42).has_point(Vector2i(x, y)): continue
						stable = stable and img.get_pixel(f * 256 + x, y) == rest.get_pixel(x, y)
				_check(stable, state + " preserves non-mouth artwork")
		box._pause_left = 0.5
		box._animate_loop(0.13)
		_check(atlas.region.position.x == 0, state + " closes mouth on pause")
		box._pause_left = 0
		box._revealing = false
		box._animate_loop(0.13)
		_check(atlas.region.position.x == 0, state + " closes mouth at page end")
	_check(Act1Beats.RUMI_FACES.wistful == Act1Beats.RUMI_FACES.sorrowful, "wistful uses repaired sorrowful")
	if OS.get_cmdline_user_args().has("--capture"):
		box.set_process(true)
		box.say("Rumi", "The office that swallowed your years. Your childhood.", Color("d9b765"), Act1Beats.RUMI_FACES.sorrowful, DialogueBox.Side.RIGHT)
		await get_tree().create_timer(0.7, true, false, true).timeout
		box.set_process(false)
		box._finish_reveal_instantly()
		for f in [0, 2, 3, 4]:
			box._show_frame(box.portrait_loop, f)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://output/rumi_speech/dialogue_%d.png" % f)
	print("RUMI SPEECH TEST: " + ("ALL PASS" if failures.is_empty() else str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
