extends Node
## WINDOWED render regression: tiny marks must survive the game's real
## 320x180 surface, fractional positions, mirrors, squash/stretch and swimming.

const LIBRARY := preload("res://assets/characters/hooshang_child/act2_frames.tres")
const SOCKS := preload("res://scenes/characters/hooshang/SockPixels.tscn")
const OUT := "res://output/child_socks_visibility"
var failures := 0
var checked := 0


func _ready() -> void:
	SaveGame.slot = -1
	DirAccess.make_dir_recursive_absolute(OUT)
	var cases: Array[Dictionary] = []
	var variations := [
		[Vector2.ONE, Vector2.ZERO, false, 0.0],
		[Vector2.ONE, Vector2(0.25, 0.75), true, 0.0],
		[Vector2(0.75, 1.25), Vector2(0.6, 0.3), false, 0.0],
		[Vector2(1.3, 0.7), Vector2(0.8, 0.7), true, 0.0],
	]
	for action in LIBRARY.get_animation_names():
		var variants := variations.duplicate()
		if action in [&"swim", &"swim_idle"]:
			variants.append([Vector2.ONE, Vector2(0.35, 0.6), false, PI / 2.0])
			variants.append([Vector2.ONE, Vector2(0.6, 0.3), true, -PI / 4.0])
		for frame in LIBRARY.get_frame_count(action):
			for variant in variants:
				cases.append({"action": action, "frame": frame, "variant": variant})
	for page in range(0, cases.size(), 40):
		var scene := Node2D.new()
		var actors: Array[AnimatedSprite2D] = []
		for i in range(page, mini(page + 40, cases.size())):
			var entry: Dictionary = cases[i]
			var slot := i - page
			var actor := Node2D.new()
			actor.position = Vector2(20 + (slot % 8) * 40, 20 + (slot / 8) * 36) + entry.variant[1]
			scene.add_child(actor)
			var squash := Node2D.new()
			squash.name = "SpriteSquash"
			squash.scale = entry.variant[0]
			actor.add_child(squash)
			var visual := AnimatedSprite2D.new()
			visual.name = "Visual"
			visual.sprite_frames = LIBRARY
			visual.animation = entry.action
			visual.frame = entry.frame
			visual.scale = Vector2.ONE * float(LIBRARY.get_meta("visual_scale"))
			visual.offset = LIBRARY.get_meta("visual_offset")
			visual.flip_h = entry.variant[2]
			visual.rotation = entry.variant[3]
			# Some face highlights are pure white too. Tint the body slightly
			# so counting white tests only the two sock marks, including when
			# the body is tinted after spending a dash in actual play.
			visual.modulate = Color(0.9, 0.9, 0.9)
			squash.add_child(visual)
			actor.add_child(SOCKS.instantiate())
			actors.append(visual)
		Screen.set_scene(scene)
		# A fractional camera pan must not shift or broaden a mark either.
		Screen.viewport.canvas_transform = Transform2D(0.0, Vector2(0.31, -0.27) if page % 80 else Vector2.ZERO)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := Screen.viewport.get_texture().get_image()
		if page == 0:
			image.save_png(OUT + "/render_native.png")
		for j in actors.size():
			var visual := actors[j]
			var points: PackedVector2Array = LIBRARY.get_meta("sock_pixels")[String(visual.animation)][visual.frame]
			var expected := {}
			for point in points:
				var offset := point + Vector2(0.5, 0.5) - Vector2(44, 44)
				if visual.flip_h:
					offset.x = -offset.x
				var at: Vector2i = Vector2i((visual.get_global_transform_with_canvas() * (offset + visual.offset)).floor())
				expected[at] = true
				if not image.get_pixelv(at).is_equal_approx(Color.WHITE):
					failures += 1
					push_error("Missing sock: %s frame %d variation %s at %s" % [visual.animation, visual.frame, cases[page + j].variant, at])
			var whites := 0
			for y in range((j / 8) * 36, (j / 8 + 1) * 36):
				for x in range((j % 8) * 40, (j % 8 + 1) * 40):
					if image.get_pixel(x, y).is_equal_approx(Color.WHITE):
						whites += 1
			if whites != expected.size():
				failures += 1
				push_error("Sock mark grew or duplicated: %s frame %d has %d white pixels, expected %d" % [visual.animation, visual.frame, whites, expected.size()])
			checked += 1
	print("SOCK VISIBILITY: %d render cases, %d failures" % [checked, failures])
	get_tree().quit(1 if failures else 0)
