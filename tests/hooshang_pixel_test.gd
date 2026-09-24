extends Node
## Full-art coverage, stable non-facial pixels, and concurrent blink/speech.
var failures: Array[String] = []

func _ready() -> void:
	var box: DialogueBox = Dialogue
	box.set_process(false)
	var states := Act1Beats.FACES.keys()
	_check(states.size() == 16, "all sixteen Act 1 acting states are covered")
	for state: String in states:
		var tex: Texture2D = Act1Beats.FACES[state]
		var key := "hooshang_" + state
		_check(tex.resource_path.get_file() == key + ".png", state + " has its own artwork")
		box._set_rig(tex)
		if box._loop.is_empty():
			_check(false, state + " arms an animation")
			continue
		_check(int(box._loop.get("frames", 0)) == 15, state + " has fifteen frames")
		_check(VoiceBlips._manifest.has(str(box._loop.get("voice_key", key))), state + " keeps a voice pool")
		_check(box.portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and box.portrait_loop.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, state + " uses crisp pixel filtering")
		var atlas: AtlasTexture = box.portrait_loop.texture
		var img := atlas.atlas.get_image()
		if img.is_compressed():
			img.decompress()
		var size := int(atlas.region.size.x)
		_check(img.has_mipmaps(), state + " imports mipmaps for smooth UI scaling")
		_check(img.get_width() == size * 15 and img.get_height() == size, state + " sheet bounds fit every frame")
		var hashes := {}
		var rest := img.get_region(Rect2i(0, 0, size, size))
		var steady := true
		for f in 15:
			box._show_frame(box.portrait_loop, f)
			_check(atlas.region.end.x <= img.get_width(), state + " frame %d stays in sheet" % f)
			var frame := img.get_region(Rect2i(f * size, 0, size, size))
			hashes[frame.get_data().hex_encode().sha256_text()] = true
			if f >= 10:
				var eye_white_pixels := 0
				for ey in range(210, 290):
					for ex in range(110, 410):
						var c := frame.get_pixel(ex, ey)
						if c.r > 0.8 and c.g > 0.8 and c.b > 0.75:
							eye_white_pixels += 1
				_check(eye_white_pixels == 0, state + " closed frame %d contains no leftover eye whites (%d)" % [f, eye_white_pixels])
			# Sample the entire fixed region, not just a handful of corners.
			for y in range(0, size, 4):
				for x in range(0, size, 4):
					var point := Vector2i(x, y)
					if Rect2i(95, 155, 330, 150).has_point(point) or Rect2i(125, 300, 260, 145).has_point(point):
						continue
					steady = steady and frame.get_pixelv(point) == rest.get_pixelv(point)
		_check(steady, state + " keeps hair/cardigan/jaw/background stable")
		_check(hashes.size() == 15, state + " has fifteen distinct rendered poses")
		box._revealing = true
		box._pause_left = 0.0
		box._blink_t = -1.0
		box._blink_left = 999.0
		var mouths := {}
		for i in 80:
			box._animate_loop(0.025)
			var f := _frame(box)
			_check(f > 0 and f < 5, state + " speaking uses open-eye mouth art")
			mouths[f] = true
		_check(mouths.size() == 4, state + " cycles all four speech mouth shapes")
		# A blink is half -> shut -> half -> open, including while speaking.
		box._blink_left = 0.0
		var eyes := {}
		for i in 14:
			box._animate_loop(0.02)
			var f := _frame(box)
			eyes[f / 5] = true
			_check(f % 5 != 0, state + " does not close its mouth to blink mid-speech")
		_check(eyes.has(0) and eyes.has(1) and eyes.has(2), state + " traverses both eyelid in-betweens and closes fully")
		# Even a blink in progress must respect a breath and completed line.
		box._pause_left = 0.5
		box._blink_t = 0.08
		box._animate_loop(0.001)
		_check(_frame(box) == 10, state + " pauses on closed mouth with shut eyes")
		box._pause_left = 0.0
		box._revealing = false
		box._blink_t = -1.0
		box._blink_left = 999.0
		box._animate_loop(0.02)
		_check(_frame(box) == 0, state + " ends on silent open-eyed rest")
	box._set_rig(load("res://assets/characters/rumi/portraits/rumi_serene.png"))
	_check(box.portrait.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and box.portrait_loop.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "Rumi retains existing filtering after Hooshang")
	# The approved neutral remains the exact base after the runtime resize.
	var approved := Image.load_from_file("res://assets/characters/hooshang/portraits/source/pixel_v2/approved_base.png")
	approved.convert(Image.FORMAT_RGBA8)
	approved.resize(512, 512, Image.INTERPOLATE_NEAREST)
	var neutral := Image.load_from_file("res://assets/characters/hooshang/portraits/hooshang_neutral.png")
	neutral.convert(Image.FORMAT_RGBA8)
	_check(approved.get_data() == neutral.get_data(), "neutral rest is the approved base, not a regeneration")
	# Exercise say(), not just manifest data: new names must keep actual audio.
	for state: String in ["confused", "wary", "unconvinced", "deflecting", "flat"]:
		box.say("Hooshang", "A short line.", Color.WHITE, Act1Beats.FACES[state])
		await get_tree().create_timer(0.5).timeout
		_check(box._voice_key == str(box._loop["voice_key"]), state + " selects its voice alias in real dialogue")
		box._finish_reveal_instantly()
		while box._active:
			box.line_finished.emit()
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
	print("HOOSHANG PIXEL TEST: %s" % ("ALL PASS" if failures.is_empty() else "%d FAILURE(S)" % failures.size()))
	get_tree().quit(0 if failures.is_empty() else 1)

func _frame(box: DialogueBox) -> int:
	var atlas: AtlasTexture = box.portrait_loop.texture
	return roundi(atlas.region.position.x / atlas.region.size.x)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
