extends Node
var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	SaveGame.slot = -1
	for marker in ["Hold that thought!", "You’d better start from the beginning.", "Come over after school."]:
		await _check_act2_skip(marker)
	print("ACT 2 STAGING SKIP: %s" % ("ALL PASS" if failures.is_empty() else str(failures)))
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
	Dialogue._finish_reveal_instantly()
	Dialogue.line_finished.emit()
	for i in 80:
		await frames(1)
		if not Dialogue.visible:
			break
	_check(not Dialogue._active and Dialogue._conversation_owner == beats, "staging retains the whole encounter scope")
	Input.action_press("skip_dialogue")
	Dialogue._process(Dialogue.skip_hold_time + 0.1)
	Input.action_release("skip_dialogue")
	_check(Dialogue.scene_skip_requested(beats), "X commits whole scene skip during staging")
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

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures.append(message)
