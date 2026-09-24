extends Node
var failures: Array[String] = []

func _ready() -> void:
	SaveGame.slot = -1
	var player: Player = load("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	player.camera.enabled = false
	for library in ["res://assets/characters/hooshang/hooshang_frames.tres", "res://assets/characters/hooshang_child/act2_frames.tres"]:
		player.visual.sprite_frames = load(library)
		for arrival in [Player.State.RUN, Player.State.DASH, Player.State.SWIM]:
			player.state = arrival
			player.facing = -1
			player.velocity = Vector2(72,0)
			player._update_visual()
			_check(player.visual.animation != &"idle", "test starts in an active movement pose")
			Dialogue.begin_conversation(self, player)
			_check(player.visual.animation == &"idle" and player.visual.is_playing(), "dialogue immediately plays idle")
			_check(player.visual.flip_h and player.visual.rotation == 0, "idle keeps facing and removes swim tilt")
			Input.action_press("move_right")
			await get_tree().physics_frame
			Dialogue._process(0.1)
			_check(player.visual.animation == &"idle" and not player.is_physics_processing(), "held run stays idle while frozen")
			Input.action_release("move_right")
			Dialogue.end_conversation()
			_check(player.is_physics_processing() and not player.input_locked, "dialogue releases movement")
			player.state = Player.State.RUN
			player._update_visual()
			_check(player.visual.animation == &"run" and player.visual.is_playing(), "running animation resumes after dialogue")
		# Authored seated dialogue must not be overridden every UI tick/page.
		Dialogue.begin_conversation(self, player)
		player.cutscene_rest(true, 1)
		var seated := player.visual.animation
		Dialogue._hold_conversation_player(player)
		Dialogue._process(0.1)
		_check(player.visual.animation == seated, "explicit seated scene pose survives dialogue upkeep")
		Dialogue.end_conversation()
	player.queue_free()
	print("DIALOGUE IDLE: ", "ALL PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
