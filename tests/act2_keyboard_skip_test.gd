extends Node
var failures: Array[String] = []

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act_2_Level_1"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await get_tree().create_timer(0.5).timeout
	var world := Screen.current as LdtkWorld
	var beats := world.get_node("Act2Beats") as Act2Beats
	world.player.global_position = beats._speaker.global_position + Vector2(-30, -8)
	for i in 180:
		await get_tree().physics_frame
		if Dialogue._active:
			break
	check(Dialogue._active, "real Act 2 conversation opens")
	key(true)
	await get_tree().create_timer(Dialogue.skip_hold_time + 0.6).timeout
	check(not world.player.input_locked and not world.player._frozen, "holding physical X returns control without another confirm")
	check(not Dialogue.visible and not beats._speaker.visible, "skip finishes the encounter instead of only the current line")
	key(false)
	await get_tree().create_timer(0.1).timeout
	Dialogue.begin_conversation(self, world.player)
	Dialogue.say("Hooshang", "The next playable section has its own dialogue.")
	await get_tree().create_timer(0.5).timeout
	check(Dialogue._active, "later conversation remains readable")
	key(true)
	await get_tree().create_timer(Dialogue.skip_hold_time + 0.5).timeout
	key(false)
	Dialogue.end_conversation()
	print("ACT 2 KEYBOARD SKIP: ", "ALL PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)

func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_X
	event.keycode = KEY_X
	event.pressed = pressed
	Input.parse_input_event(event)

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)
