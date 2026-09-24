extends Node
## Exercise the real waking scene and first Rumi trigger, not a mock conversation.
var failures: Array[String] = []

func _ready() -> void:
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _wait_for_dialogue()
	_check(Dialogue._active, "waking dialogue opens")
	Input.action_press("skip_dialogue")
	Dialogue._process(2.0)
	_check(not Dialogue._active and Dialogue._skip_armed(), "waking scene accepts the same skip hold")
	_check(world.player._frozen, "waking remains frozen until the banner closes")
	Input.action_release("skip_dialogue")
	for i in 40:
		await get_tree().physics_frame
		if not world.player.input_locked:
			break
	_check(not world.player.input_locked and not world.player._frozen, "skipping waking releases controls promptly")
	_check(not world.player.has_dash, "skipping waking preserves dashless start")
	var beats: Act1Beats
	for node in world.get_children():
		if node is Act1Beats:
			beats = node
	_check(beats != null, "world has story director")
	if beats == null:
		get_tree().quit(1)
		return
	var trigger := beats._find_trigger(beats._find_room(beats.room_name))
	_check(trigger != null, "first room has Rumi's actual trigger")
	if trigger == null:
		get_tree().quit(1)
		return
	world.player.global_position = trigger.global_position + Vector2(0, 16)
	await _wait_for_dialogue()
	_check(Dialogue._active and Dialogue._conversation_skippable, "first Rumi meeting permits skipping")
	Input.action_press("skip_dialogue")
	Dialogue._process(Dialogue.skip_hold_time + 0.1)
	_check(Dialogue._skip_armed(), "one hold confirms Rumi conversation skip")
	Input.action_release("skip_dialogue")
	for i in 40:
		await get_tree().physics_frame
		if not world.player.input_locked:
			break
	_check(not world.player.input_locked, "Rumi scene ends within the banner close, without visual holds")
	_check(trigger.get_node("Rumi").modulate.a == 0.0, "skip removes Rumi immediately")
	_check(trigger.get_node("RumiLight").energy == 0.0, "skip removes Rumi lighting")
	_check(not world.player.has_dash, "skipping the introduction grants no tutorial ability")
	_check(not Dialogue._skip_armed(), "scene completion clears the skip request")
	print("DIALOGUE SKIP STORY TEST: %s" % ("ALL PASS" if failures.is_empty() else str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

func _wait_for_dialogue() -> void:
	for i in 900:
		await get_tree().physics_frame
		if Dialogue._active:
			return

func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures.append(message)
