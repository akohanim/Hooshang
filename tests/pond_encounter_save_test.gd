extends "res://tests/pond_encounter_entry_test.gd"
## The observed swim route, followed by a disk-backed reload and repeat visit.
## Disposable save directory: never binds a player's real slot.
func _ready() -> void:
	SaveGame.dir = "user://pond_encounter_acceptance_saves"
	SaveGame.erase(0)
	SaveGame.unbind()
	SaveGame._bind(0)
	LdtkWorld.debug_start_room = "Act_2_Level_1"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(30)
	await swim_to_encounter()
	await wait_for_line("Cousin joon!")
	Input.action_press("skip_dialogue")
	await frames(150)
	Input.action_release("skip_dialogue")
	await frames(30)
	var world = Screen.current
	check(world.story_flags.get("pond_dawn", false), "departure banks the pond story flag")
	check(SaveGame.save_now(), "morning writes to disposable save slot")
	SaveGame.unbind()
	check(SaveGame.resume(0), "morning save reloads from disk")
	await frames(35)
	world = Screen.current
	var beats: Act2Beats = world.get_node("Act2Beats")
	check(beats._played and not beats._speaker.visible and not Dialogue.visible,
		"resume keeps Jamshid departed and dialogue closed")
	check(is_instance_valid(beats._encounter_fire) and not beats._encounter_fire.is_lit(),
		"resume restores the cold campfire")
	check(world.player.is_on_floor() and not world.player.input_locked and world.current_room.name == "Act_2_Level_1",
		"resume retains safe room-entry checkpoint behavior")
	check(beats._canvas_mod.color.is_equal_approx(Act2Beats.DAWN), "morning lighting survives reload")
	await swim_to_encounter()
	await frames(60)
	check(not Dialogue.visible and not world.player.input_locked, "swimming to the bank again does not replay the encounter")
	world.player.die()
	await frames(120)
	check(world.player.is_on_floor() and not world.player.input_locked and beats._played,
		"death retries at room entry without resetting completed story")
	# Reach the next room after the retry, then reload there. Restoring the
	# pond scenery must not teleport the player back to its scene endpoint.
	await swim_to_encounter()
	Input.action_press("move_right")
	await frames(300)
	Input.action_release("move_right")
	await frames(80)
	check(world.current_room.name == "Level_2", "actual onward exit reaches the carpet lesson")
	check(SaveGame.save_now(), "next room writes to disposable save slot")
	SaveGame.unbind()
	check(SaveGame.resume(0), "next-room save reloads from disk")
	await frames(35)
	world = Screen.current
	check(world.current_room.name == "Level_2" and world.player.is_on_floor() and not world.player.input_locked,
		"restoring pond story does not move the next-room spawn")
	check(world.story_flags.get("pond_dawn", false), "onward save retains departure flag")
	SaveGame.unbind()
	SaveGame.erase(0)
	print("POND ENCOUNTER SAVE: ", "ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
