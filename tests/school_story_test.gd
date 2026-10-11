extends Node
## Script fidelity, skip endpoints, and persisted encounter completion.
var failures: Array[String] = []
var world: Node
const TEXT := preload("res://resources/dialogue/act2_author_script.tres")

func _ready() -> void:
	SaveGame.slot = -1
	SaveGame._pending = {}
	await run_case("wall", 0)
	await run_case("wall", 20)
	await run_case("wall", -1)
	await run_case("palace", -1)
	await run_case("palace", 0)
	print("SCHOOL STORY: ", "ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func run_case(chapter: String, skip_at: int) -> void:
	LdtkWorld.debug_start_room = "Act_2_Level_14"
	world = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await frames(20)
	var story: Node
	for node in world.current_room.get_node("Entities").get_children():
		if node.get_script() == preload("res://scenes/props/school_wall/school_story.gd") and node.chapter == chapter:
			story = node
	check(story != null, "LDtk imported chapter " + chapter)
	if story == null: return
	world.story_flags["wall"] = chapter == "palace"
	for node in world.current_room.get_node("Entities").get_children():
		if node.has_method("_restore"): node._restore()
	var camera_bottom: int = world.player.camera.limit_bottom
	world.player.global_position = story.global_position + Vector2(70,-6)
	var seen: Array[String] = []
	var last := ""
	Engine.time_scale = 8.0
	for i in 10000:
		await frames(1)
		if story.finished: break
		if not Dialogue._active: continue
		if Dialogue._page_raw != last:
			last = Dialogue._page_raw
			seen.append(last)
		if skip_at >= 0 and seen.size()-1 >= skip_at:
			Input.action_press("skip_dialogue")
			Dialogue._process(Dialogue.skip_hold_time+0.1)
			Input.action_release("skip_dialogue")
		else:
			Dialogue._finish_reveal_instantly()
			Dialogue.line_finished.emit()
	Engine.time_scale = 1
	check(world.player.camera.limit_bottom == camera_bottom, "scene restores gameplay camera bounds")
	check(story.finished, "%s reaches its endpoint, skip=%d" % [chapter,skip_at])
	check(not world.player.input_locked and not world.player._frozen, "endpoint restores player control")
	check(not story.get_node("Wall").visible and story.curtain.color.a == 0, "stage clears the arrest and fade")
	check(world.save_state().act2_story.get(chapter,false), "save includes completed story beat")
	if skip_at == -1:
		var expected: Array[String] = []
		for line: Dictionary in TEXT.scenes[chapter]: expected.append(line.text)
		check(seen == expected, "normal playback speaks the full script in order")
	await frames(40)
	check(not story.playing and not Dialogue.visible, "standing in trigger does not replay")
	SaveGame._pending = {"world_state":world.save_state()}
	world.queue_free()
	await frames(3)
	world = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await frames(20)
	check(world.story_flags.get(chapter,false), "completion restores on load")
	world.queue_free()
	await frames(3)
	SaveGame._pending = {}

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
