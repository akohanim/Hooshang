extends "res://tests/chase_reward_detour_test.gd"
## Castle approach reward, entered at its normal debug spawn, ending at the
## real gatehouse. Story uses held skip; no progression/position grants.
func _ready() -> void:
	SaveGame.unbind()
	capture_dir = "res://output/act2_polish/milestone3/castle_reward"
	DirAccess.make_dir_recursive_absolute(capture_dir)
	LdtkWorld.debug_start_room = "Act_2_Level_14"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(30)
	world = Screen.current; player = world.player; room = world.current_room; offset = room.global_position
	continuous = true
	player._ledge_cooldown = 3600.0
	player.died.connect(func(): deaths += 1)
	stage = "castle_reward"
	var target_id := ""
	for fruit in get_tree().get_nodes_in_group("lemon"):
		if fruit is Lemon and room.is_ancestor_of(fruit) and fruit.position.y<150: target_id = fruit.collect_id()
	Input.action_press("move_right")
	await frames(70)
	Input.action_release("move_right")
	Input.action_press("skip_dialogue")
	await frames(180)
	Input.action_release("skip_dialogue")
	await frames(30)
	await connected_capture("entrance")
	await jump_transfer({"kind":"jump","start":[96,200],"target":[144,184]})
	if failures==0: await jump_transfer({"kind":"jump","start":[160,184],"target":[208,168]})
	if failures==0: await vertical_reward(208)
	if failures==0:
		for i in 1100:
			if str(world.current_room.name)=="Act_2_Level_15": break
			if player.input_locked:
				Input.action_release("move_right")
				Input.action_press("skip_dialogue")
			else:
				Input.action_release("skip_dialogue")
				Input.action_press("move_right")
			await frames(1)
		release()
		Input.action_release("skip_dialogue")
		await frames(150)
	check(str(world.current_room.name)=="Act_2_Level_15","castle reward reaches real gatehouse exit")
	check(Collectibles.save_state().taken.has(target_id),"approach reward banked and retained")
	check(deaths==0 and not used_climb,"no deaths, climb or land mantle")
	await connected_capture("final")
	var result := {"failures":failures,"deaths":deaths,"used_climb":used_climb,"target":target_id,"banked":Collectibles.save_state().taken}
	FileAccess.open(capture_dir+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CASTLE REWARD ",JSON.stringify(result))
	get_tree().quit(0 if failures==0 else 1)
