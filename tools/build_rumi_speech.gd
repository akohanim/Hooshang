extends SceneTree
## Package authored mouths on the original portraits; preserve all other pixels.
const ROOT := "res://assets/characters/rumi/portraits/"
const LOOPS := "res://assets/portraits/loops/"
const MOUTH := Rect2i(84, 162, 90, 42)

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOOPS + "manifest.json"))
	for state: String in ["sorrowful", "urgent"]:
		var base := Image.load_from_file(ROOT + "rumi_" + state + ".png")
		base.convert(Image.FORMAT_RGBA8)
		var source := Image.load_from_file(ROOT + "source/speech_v2/" + state + "_source.png")
		source.convert(Image.FORMAT_RGBA8)
		var count := 6 if state == "sorrowful" else 5
		var strip := Image.create(256 * count, 256, false, Image.FORMAT_RGBA8)
		strip.blit_rect(base, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
		strip.blit_rect(base, Rect2i(0, 0, 256, 256), Vector2i(256, 0))
		for i in 3:
			var x0 := roundi(i * source.get_width() / 3.0)
			var x1 := roundi((i + 1) * source.get_width() / 3.0)
			var cell := source.get_region(Rect2i(x0, 0, x1 - x0, source.get_height()))
			cell.resize(256, 256, Image.INTERPOLATE_NEAREST)
			var frame := base.duplicate() as Image
			for y in range(MOUTH.position.y, MOUTH.end.y):
				for x in range(MOUTH.position.x, MOUTH.end.x):
					var edge := minf(minf(x - MOUTH.position.x, MOUTH.end.x - 1 - x), minf(y - MOUTH.position.y, MOUTH.end.y - 1 - y))
					frame.set_pixel(x, y, base.get_pixel(x, y).lerp(cell.get_pixel(x, y), smoothstep(0.0, 3.0, edge)))
			strip.blit_rect(frame, Rect2i(0, 0, 256, 256), Vector2i((i + 2) * 256, 0))
			frame.save_png("res://output/rumi_speech/" + state + "_%d.png" % (i + 2))
		if state == "sorrowful":
			var old := Image.load_from_file(ROOT + "source/speech_v2/sorrowful_original_sheet.png")
			old.convert(Image.FORMAT_RGBA8)
			strip.blit_rect(old, Rect2i(512, 0, 256, 256), Vector2i(1280, 0))
		strip.save_png(LOOPS + "rumi_" + state + "_sheet.png")
		var entry: Dictionary = manifest["rumi_" + state]
		entry["frames"] = count
		entry["rest"] = 0
		entry["talk"] = [2, 3, 2, 1, 4, 2, 3, 1]
		entry["fps"] = 8
		entry["authored_roles"] = true
		entry["source"] = "rumi_speech_v2"
		if state == "sorrowful":
			entry["blink"] = 5
		print("PACKED Rumi " + state)
	var file := FileAccess.open(LOOPS + "manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	quit()
