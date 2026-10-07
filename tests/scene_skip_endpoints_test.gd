extends Node
var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	SaveGame.slot = -1
	for marker in ["Cousin joon!", "Does my mother", "That can’t be school", "That’s how you get"]:
		await _check_act2_skip(marker)
	await _check_finale_skip()
	print("SCENE SKIP ENDPOINTS: %s" % ("ALL PASS" if failures.is_empty() else str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_act2_skip(marker: String) -> void:
	LdtkWorld.debug_start_room = "Act_2_Level_1"
	var world: LdtkWorld = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await frames(15)
	var beats: Act2Beats = world.get_node("Act2Beats")
	var npc := beats._speaker
	var origin := npc.global_position
	world.player.global_position = origin + Vector2(-30, -8)
	Engine.time_scale = 8.0
	var reached := false
	for i in 7000:
		await frames(1)
		if Dialogue._active:
			if marker in Dialogue._page_raw:
				reached = true
				break
			Dialogue._finish_reveal_instantly()
			Dialogue.line_finished.emit()
	_check(reached, "reached skip point: " + marker)
	Engine.time_scale = 1.0
	Input.action_press("skip_dialogue")
	Dialogue._process(Dialogue.skip_hold_time + 0.1)
	Input.action_release("skip_dialogue")
	for i in 40:
		await frames(1)
		if not world.player.input_locked:
			break
	_check(not world.player.input_locked and not world.player._frozen, "skip releases controls promptly: " + marker)
	_check(not npc.visible, "Jamshid has departed")
	var sound_playing := false
	for child in beats.get_children():
		if child is AudioStreamPlayer and child.playing:
			sound_playing = true
	_check(not sound_playing, "scene sounds stop on skip")
	_check(world.player.global_position.distance_to(origin + Vector2(48, -6)) < 2.0, "player arrives at campfire endpoint")
	_check(beats._canvas_mod.color.is_equal_approx(Act2Beats.DAWN), "skip applies morning lighting")
	_check(beats._stars.amount == 0.0 and beats._sun_descent == 0.0, "stars and sunset are cleared")
	_check(is_instance_valid(beats._encounter_fire) and not beats._encounter_fire.is_lit(), "cold campfire remains")
	_check(not beats._pond_fish.visible, "the caught fish is gone")
	_check(not is_instance_valid(beats._rod) and not is_instance_valid(beats._departure_carpet), "temporary rod and carpet are removed")
	await frames(100)
	_check(not Dialogue.visible and beats._sun_descent == 0.0 and not npc.visible, "no delayed dialogue or visual tween resumes")
	world.queue_free()
	await frames(3)

func _check_finale_skip() -> void:
	LdtkWorld.debug_start_room = "Level_26"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(15)
	var beats: Act1Beats = world.get_node("Act1Beats")
	beats.act_two_scene = "res://ldtk/Act2World.tscn"
	var destination := beats.act_two_scene
	beats._play_chase_end()
	for i in 900:
		await frames(1)
		if Dialogue._active:
			break
	_check(Dialogue._active, "finale opens its first line")
	LdtkWorld.debug_start_room = ""
	Input.action_press("skip_dialogue")
	Dialogue._process(Dialogue.skip_hold_time + 0.1)
	Input.action_release("skip_dialogue")
	var results: Node
	for i in 40:
		await frames(1)
		results = get_tree().root.get_node_or_null("ActResults")
		if results != null:
			break
	_check(results != null, "finale skip bypasses staging and opens results")
	_check(world.player._frozen, "finale stays frozen through results")
	if results != null:
		var confirm := InputEventAction.new()
		confirm.action = "ui_accept"
		confirm.pressed = true
		results._input(confirm)
		results._input(confirm)
		await frames(2)
	_check(Screen.current_path() == destination, "results continue loads the existing Act II destination")
	Screen.clear()
	await frames(3)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures.append(message)
