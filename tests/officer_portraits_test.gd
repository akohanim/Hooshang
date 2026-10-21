extends Node
## Officer eye and mouth poses run independently through the real dialogue UI.
const STORY := preload("res://scenes/props/school_wall/school_story.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func _ready() -> void:
	SaveGame.unbind()
	var box: DialogueBox = Dialogue
	box.chars_per_second = 5
	for emotion: String in STORY.OFFICER_FACES:
		var key := "officer_" + emotion
		var face: Texture2D = STORY.OFFICER_FACES[emotion]
		var sheet := Image.load_from_file("res://assets/portraits/loops/" + key + "_sheet.png")
		check(sheet != null and sheet.get_size() == Vector2i(4608, 512), key + " has all nine eye/mouth combinations")
		if sheet == null: continue
		var master := sheet.get_region(Rect2i(0, 0, 512, 512))
		for eye in 3:
			for mouth in 3:
				var pose := sheet.get_region(Rect2i((eye * 3 + mouth) * 512, 0, 512, 512))
				check(pose.get_region(Rect2i(0, 0, 512, 200)).get_data() == master.get_region(Rect2i(0, 0, 512, 200)).get_data(), key + " holds cap and head still")
				var same_mouth := sheet.get_region(Rect2i(mouth * 512, 0, 512, 512))
				check(pose.get_region(Rect2i(0, 310, 512, 202)).get_data() == same_mouth.get_region(Rect2i(0, 310, 512, 202)).get_data(), key + " blink preserves the mouth pose")
				if eye + mouth > 0:
					check(pose.get_data() != master.get_data(), key + " authored pose changes pixels")
		box.say("Officer", "You're in trouble, boy. You're going away for a long time.", Color.WHITE, face, DialogueBox.Side.RIGHT, DialogueBox.VSide.BOTTOM)
		for tick in 180:
			await frames(1)
			if box._revealing and box.text_label.scale.y > 0.99: break
		check(box.portrait_loop.visible and box._loop.get("eye_rows", 0) == 3, key + " selects independent eye/mouth animation")
		check(box.portrait.texture == face, key + " keeps the emotional portrait identity")
		check(box.portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, key + " stays crisp")
		box._blink_t = -1; box._blink_left = 10; box._loop_left = 0
		box._pause_left = 0
		box._animate_loop(0.12)
		var atlas: AtlasTexture = box.portrait_loop.texture
		check(int(atlas.region.position.x / 512) in [1, 2], key + " mouth opens while speaking")
		box._blink_t = 0.06
		box._animate_loop(0.001)
		check(int(atlas.region.position.x / 512) in [7, 8], key + " speaks with eyes closed during blink")
		box._pause_left = 0.5
		box._animate_loop(0.001)
		check(int(atlas.region.position.x / 512) == 6, key + " closes mouth on a breath while eyes stay closed")
		box._pause_left = 0
		box._finish_reveal_instantly()
		box._blink_t = -1; box._blink_left = 10
		box._animate_loop(0.01)
		check(atlas.region.position.x == 0, key + " rests with closed mouth when line finishes")
		box._blink_left = 0
		box._animate_loop(0.01)
		box._animate_loop(0.06)
		check(int(atlas.region.position.x / 512) == 6, key + " blinks independently while silent")
		while box._active:
			box.line_finished.emit()
			await frames(3)
		await frames(15)
	print("OFFICER PORTRAITS: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
