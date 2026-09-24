extends Node
var failures: Array[String] = []

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_V1"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	for i in 30:
		await get_tree().physics_frame
	var beats: Act1Beats
	for node in world.get_children():
		if node is Act1Beats:
			beats = node
	var trigger := beats._find_trigger(world.current_room)
	_check(trigger != null and trigger.defer_to_cutscene, "V1 trigger is wired to the story scene")
	if trigger == null:
		get_tree().quit(1)
		return
	var player := world.player
	player.has_dash = true
	player.velocity = Vector2(80.0, -100.0)
	# Use the placed trigger's real body-entered handler and director connection.
	trigger._on_body_entered(player)
	var frozen_at := player.global_position
	_check(player._frozen and player.input_locked, "entering the V1 scene immediately freezes the player")
	_check(player.velocity == Vector2.ZERO, "arrival momentum is cancelled")
	var largest_motion := 0.0
	var saw_dialogue := false
	var saw_close := false
	for i in 1200:
		Input.action_press("move_right")
		if i % 2 == 0:
			Input.action_press("jump")
			Input.action_press("dash")
		else:
			Input.action_release("jump")
			Input.action_release("dash")
		if Dialogue._active:
			saw_dialogue = true
			# Leave every page open long enough to exercise held/pulsed controls.
			if i % 45 == 0:
				Dialogue._finish_reveal_instantly()
				Dialogue.line_finished.emit()
		elif saw_dialogue and Dialogue.visible:
			saw_close = true
		await get_tree().physics_frame
		if not player._frozen:
			break
		largest_motion = maxf(largest_motion, player.global_position.distance_to(frozen_at))
	for action in ["move_right", "jump", "dash"]:
		Input.action_release(action)
	_check(saw_dialogue and saw_close, "test covers speech and banner close transitions")
	_check(largest_motion < 0.01, "walking, jumping, dashing and gravity cannot move him during the scene")
	_check(not player._frozen and player.is_physics_processing() and not player.input_locked,
		"finishing the conversation restores movement and physics")
	print("V1 DIALOGUE FREEZE TEST: %s" % ("ALL PASS" if failures.is_empty() else str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures.append(message)
