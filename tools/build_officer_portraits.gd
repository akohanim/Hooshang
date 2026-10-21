extends SceneTree
## Pack authored expressions and independent eye/mouth poses into dialogue strips.
const ROOT := "res://assets/characters/officer/"
const STATES := ["alarmed", "angry", "stern"]
const LOOPS := "res://assets/portraits/loops/"
const SIZE := 512
const EYES := Rect2i(133, 201, 248, 103)
const MOUTH := Rect2i(155, 312, 215, 119)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "portraits")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOOPS + "manifest.json"))
	var only := OS.get_cmdline_user_args()
	for i in STATES.size():
		if not only.is_empty() and not only.has(STATES[i]): continue
		var poses := Image.load_from_file(ROOT + "source/animation/" + STATES[i] + "_source.png")
		if poses == null:
			push_error("Missing officer eye/mouth source for " + STATES[i])
			quit(1)
			return
		poses.convert(Image.FORMAT_RGBA8)
		var cells: Array[Image] = []
		for cell_index in 9:
			var x0 := roundi((cell_index % 3) * poses.get_width() / 3.0)
			var x1 := roundi((cell_index % 3 + 1) * poses.get_width() / 3.0)
			var y0 := roundi((cell_index / 3) * poses.get_height() / 3.0)
			var y1 := roundi((cell_index / 3 + 1) * poses.get_height() / 3.0)
			var cell := poses.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
			cell.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
			cells.append(cell)
		# The bearded closed-mouth pose is the stationary master for this emotion.
		var portrait: Image = cells[0]
		var aligned: Array[Image] = []
		for cell: Image in cells:
			var registered := portrait.duplicate() as Image
			registered.blit_rect(cell, Rect2i(0, 0, SIZE, SIZE), _register(portrait, cell))
			aligned.append(registered)
		var sheet := Image.create(SIZE * 9, SIZE, false, Image.FORMAT_RGBA8)
		var preview := Image.create(SIZE * 3, SIZE * 3, false, Image.FORMAT_RGBA8)
		for eye in 3:
			for mouth in 3:
				var frame := portrait.duplicate() as Image
				if eye > 0: _patch(frame, aligned[eye * 3], EYES)
				if mouth > 0: _patch(frame, aligned[mouth], MOUTH)
				sheet.blit_rect(frame, Rect2i(0, 0, SIZE, SIZE), Vector2i((eye * 3 + mouth) * SIZE, 0))
				preview.blit_rect(frame, Rect2i(0, 0, SIZE, SIZE), Vector2i(mouth * SIZE, eye * SIZE))
		var key: String = "officer_" + STATES[i]
		sheet.save_png(LOOPS + key + "_sheet.png")
		DirAccess.make_dir_recursive_absolute("res://output/officer_portraits")
		preview.save_png("res://output/officer_portraits/" + key + "_grid.png")
		manifest[key] = {
			"sheet": key + "_sheet.png", "frames": 9, "frame_size": [SIZE, SIZE],
			"fps": 9, "rest": 0, "talk": [1, 2, 1, 2], "blink": 6,
			"eye_rows": 3, "mouth_columns": 3, "blink_duration": 0.20,
			"authored_roles": true, "loop": true, "pixel_art": true,
			"mouth_poses": ["closed", "parted", "open"],
			"eye_poses": ["open", "half", "closed"], "source": "officer/animation"
		}
		var error := portrait.save_png(ROOT + "portraits/officer_" + STATES[i] + ".png")
		if error != OK:
			push_error("Could not save officer portrait: " + str(error))
			quit(1)
			return
	FileAccess.open(LOOPS + "manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "  ", false) + "\n")
	quit()

func _register(target: Image, pose: Image) -> Vector2i:
	var best := INF
	var shift := Vector2i.ZERO
	# Nose only: eyelids and lips are the moving features, not alignment markers.
	for dy in range(-32, 33, 2):
		for dx in range(-24, 25, 2):
			var score := 0.0
			for y in range(282, 310, 3):
				for x in range(238, 268, 3):
					var a := target.get_pixel(x, y)
					var b := pose.get_pixel(x - dx, y - dy)
					score += pow(a.r - b.r, 2) + pow(a.g - b.g, 2) + pow(a.b - b.b, 2)
			if score < best:
				best = score
				shift = Vector2i(dx, dy)
	return shift

func _patch(target: Image, pose: Image, rect: Rect2i) -> void:
	var center := Vector2(rect.get_center())
	var radii := Vector2(rect.size) * 0.5
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var point := (Vector2(x, y) - center) / radii
			var edge := (1.0 - point.length()) * minf(radii.x, radii.y)
			# A narrow ellipse leaves the outer upper corners of wide startled
			# eyes behind. Replace the entire eye band so closed means fully shut.
			if rect == EYES:
				edge = minf(minf(x - rect.position.x, rect.end.x - 1 - x), minf(y - rect.position.y, rect.end.y - 1 - y))
			target.set_pixel(x, y, target.get_pixel(x, y).lerp(pose.get_pixel(x, y), smoothstep(0.0, 6.0, edge)))
