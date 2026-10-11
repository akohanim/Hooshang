extends Node
## Swim into the real NPC trigger. Floor-settled test fixtures missed a fatal
## dialogue landing fall through this pond, which has no bottom under the boy.
var failures: Array[String] = []
var deaths := 0

func _ready() -> void:
	SaveGame.slot = -1
	for skip_from_water in [true, false]:
		await run_encounter(skip_from_water)
	print("POND ENCOUNTER ENTRY: ", "ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func run_encounter(skip_from_water: bool) -> void:
	deaths = 0
	LdtkWorld.debug_start_room = "Act_2_Level_1"
	var world: LdtkWorld = load("res://ldtk/Act2World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(30)
	var beats: Act2Beats = world.get_node("Act2Beats")
	world.player.died.connect(func(): deaths += 1)
	await swim_to_encounter()
	await wait_for_line("Cousin joon!")
	check(beats._played and Dialogue._active, "swimming approach triggers the encounter")
	check(world.player.swimming(), "opening exchange holds a swimmer")
	check(world.player.visual.animation == &"swim_idle", "opening exchange uses the child float pose")
	var held_at := world.player.global_position
	await frames(600)
	check(deaths == 0, "waiting ten seconds on the first line causes no death")
	check(world.player.global_position.distance_to(held_at) < 0.01, "dialogue does not drag the swimmer to a floor")
	check(Dialogue._active and Dialogue._page_raw == "Cousin joon!", "first author line remains open until advanced")
	if not skip_from_water:
		for line in ["Jamshid! It's so good to see you!", "You saw me yesterday.",
			"It feels like so much longer.", "Well, get out of the water. You're frightening dinner.",
			"Are the fish biting today?"]:
			Dialogue._finish_reveal_instantly()
			Dialogue.line_finished.emit()
			await wait_for_line(line)
		check(world.player.global_position.distance_to(beats._speaker.global_position + Vector2(-12, -6)) < 0.5,
			"full opening exchange stages the bank exit before the fishing question")
		check(not world.player.swimming(), "bank exit clears the water state")
	Input.action_press("skip_dialogue")
	await frames(150)
	Input.action_release("skip_dialogue")
	await frames(30)
	check(not world.player.input_locked and not world.player._frozen, "skip returns player control")
	check(not Dialogue.visible and not beats._speaker.visible, "skip reaches Jamshid's departure")
	check(world.player.is_on_floor() and deaths == 0, "morning endpoint is supported and alive")
	world.queue_free()
	await frames(4)

func swim_to_encounter() -> void:
	# Real child movement from the authored entrance; no position/velocity writes.
	Input.action_press("move_right")
	await frames(275)
	Input.action_press("jump")
	await frames(60)
	Input.action_release("jump")
	await frames(15)
	Input.action_press("jump")
	await frames(60)
	Input.action_release("jump")
	await frames(200)
	Input.action_press("jump")
	await frames(60)
	Input.action_release("jump")
	await frames(165)
	Input.action_release("move_right")

func wait_for_line(text: String) -> void:
	for i in 240:
		await frames(1)
		if Dialogue._active and Dialogue._page_raw == text:
			return
	check(false, "author line opens: " + text)

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)
