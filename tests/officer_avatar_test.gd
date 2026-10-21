extends Node
## The saved Aseprite clips reach gameplay with correct cadence and floor anchor.
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func _ready() -> void:
	SaveGame.unbind()
	var packed: SpriteFrames = load("res://assets/characters/officer/officer_frames.tres")
	check(packed.get_meta("aseprite_source", "") == "res://assets/characters/officer/aseprite/officer_movement.aseprite", "gameplay art identifies its editable Aseprite source")
	var sheet := Image.load_from_file("res://assets/characters/officer/sprites/movement.png")
	check(sheet.get_size() == Vector2i(512, 48), "export contains sixteen native 32x48 poses")
	var specs := {"idle": [4, 0.25], "walk": [8, 0.10], "talk": [4, 0.14]}
	for clip: String in specs:
		check(packed.get_frame_count(clip) == specs[clip][0], clip + " has its own exact Aseprite tag range")
		check(packed.get_animation_loop(clip), clip + " loops")
		var unique := {}
		for i in packed.get_frame_count(clip):
			check(is_equal_approx(packed.get_frame_duration(clip, i) / packed.get_animation_speed(clip), specs[clip][1]), clip + " preserves Aseprite frame timing")
			var atlas: AtlasTexture = packed.get_frame_texture(clip, i)
			var pose := sheet.get_region(Rect2i(atlas.region))
			unique[pose.get_data().hex_encode()] = true
			var floor_pixel := false
			for x in 32:
				if pose.get_pixel(x, 47).a > 0: floor_pixel = true
			check(floor_pixel, clip + " keeps a supporting boot on the pavement")
		check(unique.size() > 1, clip + " has genuinely different animation poses")
	var story: Node2D = load("res://scenes/props/school_wall/SchoolStory.tscn").instantiate()
	add_child(story)
	await frames(2)
	check(story.officer is AnimatedSprite2D, "graffiti scene instances animated officer prefab")
	check(story.officer.position.y == 0 and story.officer.offset.y == -24, "officer's foot origin is the courtyard floor")
	story.playing = true
	story.officer.show()
	story.officer_walking = true
	await frames(2)
	check(story.officer.animation == &"walk", "entrance and escort select the walk clip")
	story.officer_walking = false
	story.officer_speaking = true
	Dialogue._revealing = true
	Dialogue._pause_left = 0
	await frames(2)
	check(story.officer.animation == &"talk", "officer speaks and gestures while words reveal")
	Dialogue._pause_left = 0.5
	await frames(2)
	check(story.officer.animation == &"idle", "officer rests during a spoken pause")
	Dialogue._pause_left = 0
	Dialogue._revealing = false
	await frames(2)
	check(story.officer.animation == &"idle", "officer rests while waiting for dialogue advance")
	story.queue_free()
	await frames(2)
	print("OFFICER AVATAR: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
