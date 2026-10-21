extends Node
var failures: Array[String] = []
const TEXT := preload("res://resources/dialogue/act2_author_script.tres")
func _ready() -> void:
	SaveGame.slot = -1
	SaveGame._pending = {}
	for skip_at in [-1, 0, 8]: await run_case(skip_at)
	print("CELL REUNION: ", "ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func run_case(skip_at: int) -> void:
	LdtkWorld.debug_start_room = "Prison_Hub"
	var world = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await frames(20)
	var story = world.get_node("CellReunion")
	var bottom: int = world.player.camera.limit_bottom
	for id in world.IDS:
		world.collected.append(id)
		world.inserted.append(id)
	world.finish_rescue()
	var seen: Array[String] = []
	var last := ""
	Engine.time_scale = 8
	for tick in 5000:
		await frames(1)
		if story.finished: break
		if not Dialogue._active: continue
		if last != Dialogue._page_raw:
			last = Dialogue._page_raw
			seen.append(last)
		if skip_at >= 0 and seen.size() > skip_at:
			Input.action_press("skip_dialogue")
			Dialogue._process(Dialogue.skip_hold_time + 0.1)
			Input.action_release("skip_dialogue")
		else:
			Dialogue._finish_reveal_instantly()
			Dialogue.line_finished.emit()
	Engine.time_scale = 1
	check(story.finished, "reunion reaches endpoint, skip=%d" % skip_at)
	check(not Game.completed, "rescue keeps the act in progress")
	check(not world.player.input_locked and not world.player._frozen, "controls restored")
	check(world.player.camera.limit_bottom == bottom, "camera bounds restored")
	check(story.actor.position.x == 90, "Jamshid waits at the courtyard passage")
	if skip_at == -1:
		var expected: Array[String] = []
		for line: Dictionary in TEXT.scenes.cell: expected.append(line.text)
		check(seen == expected, "all nine author lines play in order")
	world.player.die()
	await frames(90)
	check(story.finished and not story.playing, "death does not replay the reunion")
	SaveGame._pending = {"world_state":world.save_state()}
	world.queue_free()
	await frames(3)
	world = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await frames(25)
	story = world.get_node("CellReunion")
	check(story.finished and not story.playing, "saved reunion does not replay")
	check(story.actor != null and story.actor.position.x == 90, "saved actor waits at the passage")
	world.queue_free()
	await frames(3)
	SaveGame._pending = {}

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
