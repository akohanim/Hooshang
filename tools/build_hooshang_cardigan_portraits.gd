extends SceneTree
## Package imagegen-authored eye/mouth art into stable 15-frame dialogue strips.
## No drawn or warped replacement features: only registration, crop and feather.
## Run: Godot --headless --path . --script res://tools/build_hooshang_cardigan_portraits.gd
const SOURCE := "res://assets/characters/hooshang/portraits/source/cardigan_v1/"
const PORTRAITS := "res://assets/characters/hooshang/portraits/"
const LOOPS := "res://assets/portraits/loops/"
const SIZE := 512
const STATES := ["neutral", "happy", "angry", "sad", "surprised", "dazed", "hesitant", "skeptical", "annoyed", "vulnerable", "shocked", "confused", "wary", "unconvinced", "deflecting", "flat"]
const VOICES := {"neutral": "hesitant", "happy": "vulnerable", "angry": "annoyed", "sad": "vulnerable", "surprised": "shocked", "confused": "hesitant", "wary": "skeptical", "unconvinced": "skeptical", "deflecting": "hesitant", "flat": "skeptical"}
const EYES := Rect2i(103, 135, 316, 136)
const MOUTH := Rect2i(143, 280, 235, 119)

func _initialize() -> void:
	var base := Image.load_from_file(SOURCE + "approved_base.png")
	base.convert(Image.FORMAT_RGBA8)
	base.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOOPS + "manifest.json"))
	var only := OS.get_cmdline_user_args()
	for state: String in STATES:
		if not only.is_empty() and not only.has(state):
			continue
		if not FileAccess.file_exists(SOURCE + state + "_source.png"):
			push_warning("Missing generated sheet: " + state)
			continue
		var source := Image.load_from_file(SOURCE + state + "_source.png")
		source.convert(Image.FORMAT_RGBA8)
		var cells: Array[Image] = []
		for i in 15:
			var x0 := roundi((i % 5) * source.get_width() / 5.0)
			var x1 := roundi((i % 5 + 1) * source.get_width() / 5.0)
			var y0 := roundi((i / 5) * source.get_height() / 3.0)
			var y1 := roundi((i / 5 + 1) * source.get_height() / 3.0)
			# Discard the two-pixel sheet seam; no neighboring row can bleed in.
			var cell := source.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0).grow(-2))
			cell.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
			cells.append(cell)
		# An emotion's rest drawing is its registration master. In particular,
		# a raised-brow startle changes facial proportions; patching it onto the
		# neutral head leaves ghost brows/hair. Neutral alone uses the exact
		# approved painting. All other masters were generated from that painting.
		var master: Image = base if state == "neutral" else cells[0]
		# Find translation from the nose, which doesn't change with eyes/lips.
		var aligned: Array[Image] = []
		for cell in cells:
			var shift := _register(master, cell)
			var registered := master.duplicate() as Image
			registered.blit_rect(cell, Rect2i(0, 0, SIZE, SIZE), shift)
			aligned.append(registered)
		var sheet := Image.create(SIZE * 15, SIZE, false, Image.FORMAT_RGBA8)
		var dir := PORTRAITS + "cardigan_v1/" + state
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		for eye in 3:
			for mouth in 5:
				var frame := master.duplicate() as Image
				# Each mouth shape is shared across all eye states, and vice versa.
				# This makes simultaneous speech/blinks possible without shimmer.
				if state != "neutral" or eye != 0:
					_patch(frame, aligned[eye * 5], EYES, 8.0)
				if state != "neutral" or mouth != 0:
					_patch(frame, aligned[mouth], MOUTH, 8.0)
				var index := eye * 5 + mouth
				frame.save_png(dir + "/frame_%02d.png" % index)
				sheet.blit_rect(frame, Rect2i(0, 0, SIZE, SIZE), Vector2i(index * SIZE, 0))
				if index == 0:
					frame.save_png(PORTRAITS + "hooshang_" + state + ".png")
		sheet.save_png(LOOPS + "hooshang_" + state + "_sheet.png")
		manifest["hooshang_" + state] = {
			"sheet": "hooshang_" + state + "_sheet.png", "frames": 15,
			"frame_size": [SIZE, SIZE], "fps": 9, "rest": 0, "talk": [1, 2, 1, 3, 1, 4, 2, 1],
			"blink": 10, "eye_rows": 3, "mouth_columns": 5, "blink_duration": 0.20,
			"authored_roles": true, "loop": true,
			"voice_key": "hooshang_" + str(VOICES.get(state, state)),
			"mouth_poses": ["closed", "parted", "ah", "oh", "ee"],
			"eye_poses": ["open", "half", "closed"], "source": "cardigan_v1"
		}
		print("PACKED %s: 15 frames, %dx%d" % [state, sheet.get_width(), sheet.get_height()])
	var file := FileAccess.open(LOOPS + "manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	quit()

func _register(target: Image, source: Image) -> Vector2i:
	var best := INF
	var result := Vector2i.ZERO
	# Nose bridge/tip: avoids eyebrows, irises, mustache and mouth.
	for dy in range(-18, 19, 2):
		for dx in range(-18, 19, 2):
			var score := 0.0
			for y in range(240, 292, 4):
				for x in range(233, 289, 4):
					var a := target.get_pixel(x, y)
					var b := source.get_pixel(x - dx, y - dy)
					score += pow(a.r - b.r, 2) + pow(a.g - b.g, 2) + pow(a.b - b.b, 2)
			if score < best:
				best = score
				result = Vector2i(dx, dy)
	return result

func _patch(target: Image, source: Image, rect: Rect2i, feather: float) -> void:
	var center := Vector2(rect.get_center())
	var radii := Vector2(rect.size) * 0.5
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var local := (Vector2(x, y) - center) / radii
			var edge := (1.0 - local.length()) * minf(radii.x, radii.y)
			var alpha := smoothstep(0.0, feather, edge)
			target.set_pixel(x, y, target.get_pixel(x, y).lerp(source.get_pixel(x, y), alpha))
