extends Node
## Script fidelity, skip endpoints, and persisted encounter completion.
var failures: Array[String] = []
var world: Node
const TEXT := preload("res://resources/dialogue/act2_author_script.tres")
const PAINT := preload("res://tests/room14_painting_driver.gd")

func _ready() -> void:
	SaveGame.slot = -1
	SaveGame._pending = {}
	await run_case("wall", 0)
	await run_case("wall", TEXT.cue("wall", "Hey!"))
	await run_case("wall", -2)
	await run_case("wall", -1)
	await run_case("palace", -1)
	await run_case("palace", 0)
	print("SCHOOL STORY: ", "ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func run_case(chapter: String, skip_at: int) -> void:
	LdtkWorld.debug_start_room = "Act_2_Level_14"
	world = load("res://ldtk/Act2World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(20)
	var story: Node
	for node in world.current_room.get_node("Entities").get_children():
		if node.get_script() == preload("res://scenes/props/school_wall/school_story.gd") and node.chapter == chapter:
			story = node
	check(story != null, "LDtk imported chapter " + chapter)
	if story == null: return
	if chapter == "wall":
		var floor_layer: TileMapLayer = world.current_room.get_node("Collisions")
		check(floor_layer.get_cell_source_id(Vector2i(8,25)) >= 0 and floor_layer.get_cell_source_id(Vector2i(72,25)) >= 0,
			"graffiti courtyard has a continuous floor under both ends")
		check(not story.get_node("Wall").has_node("EarlierGraffiti"), "Marjan wall text is removed")
	world.story_flags["wall"] = chapter == "palace"
	for node in world.current_room.get_node("Entities").get_children():
		if node.has_method("_restore"): node._restore()
	var camera_bottom: int = world.player.camera.limit_bottom
	world.player.global_position = story.global_position + Vector2(70,-6)
	var seen: Array[String] = []
	var last := ""
	var painting_seen := false
	var painting_ticks := 0
	var ready_ticks := 0
	var painting_start := Vector2.ZERO
	var walked_distance := 0.0
	Engine.time_scale = 8.0
	for i in 10000:
		await frames(1)
		if story.finished: break
		if story.painting_game.active:
			if painting_seen:
				walked_distance = maxf(walked_distance, absf(world.player.global_position.x - painting_start.x))
			if not painting_seen:
				painting_seen = true
				painting_start = world.player.global_position
				check(not world.player._frozen and not world.player.input_locked and not Dialogue._active, "painting returns movement and closes dialogue")
				check(story.cousin.visual.animation == &"idle", "Jamshid waits in idle during painting")
				var cousin_at: Vector2 = story.cousin.position
				await frames(30)
				check(story.painting_game.active and story.painting_game.areas.count(true) == 0, "painting waits indefinitely for actual input")
				check(story.cousin.position == cousin_at and story.cousin.visual.animation == &"idle", "stationary Jamshid never runs in place")
				Input.action_press("move_down")
				await frames(2)
				Input.action_release("move_down")
				check(story.painting_game.active, "unfinished painting cannot accidentally resume the arrest")
				if skip_at == -2:
					Input.action_press("glow")
					Dialogue._process(Dialogue.skip_hold_time + 0.1)
					Input.action_release("glow")
			if skip_at != -2:
				painting_ticks += 1
				if story.painting_game.areas.count(true) == 3: ready_ticks += 1
				PAINT.drive(story, ready_ticks > 30)
				if ready_ticks == 30:
					check(story.painting_game.active, "all three areas can be finished without automatically ending free play")
			continue
		PAINT.release()
		if not Dialogue._active: continue
		if Dialogue._page_raw != last:
			last = Dialogue._page_raw
			seen.append(last)
			if chapter == "wall":
				for line: Dictionary in TEXT.scenes.wall:
					if line.speaker == "OFFICER" and line.text == last:
						check(story.OFFICER_FACES.has(line.get("face", "")), "officer line has an authored expression")
						check(Dialogue.portrait.texture == story.OFFICER_FACES.get(line.get("face", "")),
							"officer dialogue displays its matching emotional face")
		if skip_at >= 0 and seen.size()-1 >= skip_at:
			Input.action_press("skip_dialogue")
			Dialogue._process(Dialogue.skip_hold_time+0.1)
			Input.action_release("skip_dialogue")
		else:
			Dialogue._finish_reveal_instantly()
			Dialogue.line_finished.emit()
	Engine.time_scale = 1
	PAINT.release()
	check(world.player.camera.limit_bottom == camera_bottom, "scene restores gameplay camera bounds")
	check(story.finished, "%s reaches its endpoint, skip=%d" % [chapter,skip_at])
	check(not world.player.input_locked and not world.player._frozen, "endpoint restores player control")
	check(not story.get_node("Wall").visible and story.curtain.color.a == 0, "stage clears the arrest and fade")
	check(not story.painting_game.active and not story.painting_game.get_node("HUD/Panel").visible, "completion and skip both close the painting HUD")
	if world.has_node("Act2Audio"):
		check(not world.get_node("Act2Audio/Spray").playing, "spray hiss stops when painting ends")
	check(world.save_state().act2_story.get(chapter,false), "save includes completed story beat")
	if chapter == "wall" and skip_at == -1:
		check(story.get_node("Wall/Graffiti").stage == 3, "both cousins complete the three mural beats")
		check(story.painting_game.completed and painting_ticks > 0, "player returns to Jamshid to finish the painting break")
		var marks: Array = story.get_node("Wall/Graffiti").paint_marks
		check(marks.size() > 5, "aiming the spray leaves persistent paint on the wall")
		var colors := {}
		var heights := {}
		for mark: Dictionary in marks:
			colors[mark.color] = true
			heights[mark.at.y] = true
		check(colors.size() == 3 and heights.size() > 3, "picking up different cans and aiming paints all three colors at different heights")
		check(walked_distance > 50, "real movement carries Hooshang along the wall")
		var player_height: float = world.player.visual.sprite_frames.get_frame_texture("idle",0).get_image().get_used_rect().size.y * absf(world.player.visual.scale.y)
		var officer_height: float = story.officer.sprite_frames.get_frame_texture("idle",0).get_image().get_used_rect().size.y * story.officer.scale.y
		check(absf(officer_height / player_height - 2.0) < 0.05, "officer's visible height is twice Hooshang's")
		check(story.cousin.visual.animation == &"idle", "Jamshid stops running after the escort ends")
	if skip_at == -1:
		var expected: Array[String] = []
		for line: Dictionary in TEXT.scenes[chapter]: expected.append(line.text)
		check(seen == expected, "normal playback speaks the full script in order")
	await frames(40)
	check(not story.playing and not Dialogue.visible, "standing in trigger does not replay")
	SaveGame._pending = {"world_state":world.save_state()}
	Screen.clear()
	await frames(3)
	world = load("res://ldtk/Act2World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(20)
	check(world.story_flags.get(chapter,false), "completion restores on load")
	Screen.clear()
	await frames(3)
	SaveGame._pending = {}

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
