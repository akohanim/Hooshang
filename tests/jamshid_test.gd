extends Node
## Guard native atlas loading, frame bounds, actor scale and dialogue lookup.

var failures: Array[String] = []


func _ready() -> void:
	var actor = preload("res://scenes/characters/jamshid/Jamshid.tscn").instantiate()
	add_child(actor)
	var reference: SpriteFrames = preload("res://assets/characters/hooshang_child/act2_frames.tres")
	var frames: SpriteFrames = actor.visual.sprite_frames
	for pose in reference.get_animation_names():
		check(frames.has_animation(pose), pose + " exists")
		check(frames.get_frame_count(pose) == reference.get_frame_count(pose), pose + " matching frame count")
		check(frames.get_animation_speed(pose) == reference.get_animation_speed(pose), pose + " matching speed")
		check(frames.get_animation_loop(pose) == reference.get_animation_loop(pose), pose + " matching loop")
		actor.play_pose(pose)
		check(actor.visual.scale == Vector2.ONE * 0.375, pose + " native scale")
		for i in frames.get_frame_count(pose):
			var texture := frames.get_frame_texture(pose, i)
			check(texture.get_size() == Vector2(88, 88), pose + " native canvas")
			check(frames.get_frame_duration(pose, i) == reference.get_frame_duration(pose, i), pose + " timing")
			check(frames.get_meta("sock_pixels")[pose][i] == reference.get_meta("sock_pixels")[pose][i], pose + " ankle marks")
		actor.face_left(true)
		check(actor.visual.scale.x == -0.375, pose + " mirrors around actor origin")
		actor.face_left(false)
	check(actor.visual.offset == Vector2(0, -3) and actor.visual.position.y == -6.0, "feet anchored at actor origin")
	check(frames.get_frame_count("walk") == frames.get_frame_count("run"), "walk compatibility")
	check(frames.has_animation("sit") and frames.get_animation_loop("sit"), "seated story loop")
	actor.play_pose("jump")
	for i in 75:
		await get_tree().physics_frame
	check(actor.visual.animation == &"idle", "jump finishes and returns to idle")
	var box: DialogueBox = Dialogue
	for emotion in Jamshid.FACES:
		var face := Jamshid.portrait(emotion)
		box.portrait.texture = face
		box._set_rig(face)
		check(box.portrait_loop.visible, emotion + " activates dialogue loop")
		var talk: Array = box._loop.get("talk", [])
		check(talk.size() == 2 and int(talk[0]) == 1 and int(talk[1]) == 2,
			emotion + " speech excludes silence and blink")
		check(box._loop.get("blink") == 3, emotion + " independent blink")
		var texture := box.portrait_loop.texture as AtlasTexture
		box._show_frame(box.portrait_loop, 3)
		check(texture.region.end.x <= texture.atlas.get_width(), emotion + " last frame fits sheet")
	box._set_rig(null)
	actor.queue_free()
	if failures.is_empty():
		print("PASS: Jamshid's matching native movement library and five dialogue emotions load and animate.")
	else:
		for failure in failures:
			push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
