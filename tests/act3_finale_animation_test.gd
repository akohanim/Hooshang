extends Node
## Native artwork, independently moving limbs/jaws, and the actual mouse prefab.

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	SaveGame.unbind()
	var tiger := ChaseTiger.sprite_frames()
	for clip in [&"walk", &"run", &"idle", &"roar", &"look_down", &"look_up", &"crouch"]:
		check(tiger.has_animation(clip), "tiger has " + str(clip))
		check_art(tiger, clip, Vector2i(44, 22))
	check(tiger.get_frame_count(&"walk") == 12 and tiger.get_frame_count(&"run") == 12, "twelve-pose walk and gallop")
	var walk_anchor := tiger.get_frame_texture(&"walk", 0).get_image()
	var legs := {}
	for i in tiger.get_frame_count(&"walk"):
		var frame := tiger.get_frame_texture(&"walk", i).get_image()
		check(frame.get_region(Rect2i(20, 1, 24, 11)).get_data() == walk_anchor.get_region(Rect2i(20, 1, 24, 11)).get_data(), "walk head/stripes stay anchored as limbs move")
		legs[hash(frame.get_region(Rect2i(0, 15, 44, 7)).get_data())] = true
		check(frame.get_used_rect().end.y == 22, "walking paws stay on the floor")
	check(legs.size() >= 6, "walk articulates legs instead of sliding one still")
	var roar_jaws := {}
	for i in tiger.get_frame_count(&"roar"):
		var frame := tiger.get_frame_texture(&"roar", i).get_image()
		roar_jaws[hash(frame.get_region(Rect2i(37, 7, 7, 6)).get_data())] = true
	check(roar_jaws.size() >= 3, "roar moves the jaw independently")
	var scene := load("res://scenes/props/sea/VineMouse.tscn") as PackedScene
	var mice: Array[VineMouse] = []
	for white in [false, true]:
		var mouse := scene.instantiate() as VineMouse
		mouse.white = white
		add_child(mouse)
		mice.append(mouse)
		var prefix := "white_" if white else "black_"
		check(mouse.flip_h == white and mouse.animation == StringName(prefix + "walk"), "mouse walks toward root in its own colour/facing")
		check_art(mouse.sprite_frames, StringName(prefix + "walk"), Vector2i(14, 8))
		check_art(mouse.sprite_frames, StringName(prefix + "gnaw"), Vector2i(14, 8))
		mouse.gnaw()
		check(mouse.animation == StringName(prefix + "gnaw"), "arrival switches to gnawing")
		check(mouse.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "mouse uses nearest filtering")
	await get_tree().create_timer(0.36).timeout
	for mouse in mice:
		check(mouse.frame > 0 and mouse.is_playing(), "gnaw loop actually advances in Godot")
	var dark := mice[0].sprite_frames.get_frame_texture(&"black_gnaw", 0).get_image()
	var light := mice[1].sprite_frames.get_frame_texture(&"white_gnaw", 0).get_image()
	check(mean_light(light) > mean_light(dark) + 0.15, "black and white mice stay visibly distinct")
	print("ACT3 FINALE ANIMATION: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func check_art(frames: SpriteFrames, clip: StringName, size: Vector2i) -> void:
	var poses := {}
	for i in frames.get_frame_count(clip):
		var image := frames.get_frame_texture(clip, i).get_image()
		check(image.get_size() == size, str(clip) + " native frame dimensions")
		check(image.get_used_rect().has_area(), str(clip) + " nonempty artwork")
		check(connected(image), str(clip) + " silhouette has no detached body parts")
		poses[hash(image.get_data())] = true
		for y in image.get_height():
			for x in image.get_width():
				var alpha := image.get_pixel(x, y).a
				check(alpha == 0.0 or alpha == 1.0, str(clip) + " crisp opaque pixels")
	check(poses.size() >= 3, str(clip) + " contains distinct authored poses")


func connected(image: Image) -> bool:
	var opaque := {}
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				opaque[Vector2i(x, y)] = true
	if opaque.is_empty():
		return false
	var todo: Array[Vector2i] = [opaque.keys()[0]]
	opaque.erase(todo[0])
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var next := at + Vector2i(dx, dy)
				if opaque.has(next):
					opaque.erase(next)
					todo.append(next)
	return opaque.is_empty()


func mean_light(image: Image) -> float:
	var total := 0.0
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0:
				total += color.get_luminance()
				count += 1
	return total / maxf(count, 1)
