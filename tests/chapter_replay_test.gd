extends Node
var failures := 0
func _ready() -> void:
	SaveGame.dir = "user://_test_chapter_replay"
	for pair in [[1,"Level_5"],[2,"Prison_B03"],[3,"Act3_Level_1"]]:
		SaveGame.replay_room(pair[0],pair[1])
		for i in 30: await get_tree().physics_frame
		var world = Screen.current
		var ok: bool = world is LdtkWorld and str(world.current_room.name)==pair[1] and SaveGame.slot == -1 and world.player.has_dash
		print(('PASS ' if ok else 'FAIL ')+"save-free launch "+pair[1])
		if not ok: failures+=1
		Screen.clear()
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
