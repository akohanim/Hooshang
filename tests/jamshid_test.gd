extends Node
## Guard native atlas loading, frame bounds, actor scale and dialogue lookup.

var failures: Array[String] = []


func _ready() -> void:
	var actor = preload("res://scenes/characters/jamshid/Jamshid.tscn").instantiate()
	add_child(actor)
	for pose in ["idle", "walk", "sit", "jump"]:
		actor.play_pose(pose)
		var frames: SpriteFrames = actor.visual.sprite_frames
		var count := 8 if pose in ["walk", "jump"] else 4
		check(frames.get_frame_count(pose) == count, pose + " frame count")
		for i in count:
			var texture := frames.get_frame_texture(pose, i) as Texture2D
			check(texture != null and texture.get_size() == Vector2(800, 900), pose + " common anchor canvas")
		actor.face_left(true)
		check(actor.visual.scale.x < 0, pose + " mirrors around actor origin")
		actor.face_left(false)
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
		print("PASS: Jamshid's 24 avatar frames and five dialogue emotions load and animate.")
	else:
		for failure in failures:
			push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
