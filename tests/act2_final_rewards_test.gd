extends "res://tests/act2_final_trials_test.gd"
## Optional water rewards, earned with normal swimming and bank landings.
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Act_2_Level_18"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	world=Screen.current;player=world.player;room=world.current_room;offset=room.global_position
	player.died.connect(func():deaths+=1)
	continuous=true
	var initial:=Collectibles.total
	var recipes:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_final_trials.json"))
	for path:Array in recipes[2].water_paths:
		await prepare(Vector2(path[0][0],path[0][1]-6))
		for point:Array in path.slice(1):
			await swim_to(Vector2(point[0],point[1]-6))
			if point[0]==264:
				await swim_to(Vector2(248,210))
				await swim_to(Vector2(264,190))
			if point[0]==368:
				await swim_to(Vector2(368,210))
				await swim_to(Vector2(368,190))
			if failures:break
		if failures:break
	await frames(60)
	check(Collectibles.total==initial+2,"both optional qanat lemons earned and banked")
	check(deaths==0,"optional detours have no deaths")
	print("FINAL REWARDS: ",failures," failures")
	get_tree().quit(1 if failures else 0)
