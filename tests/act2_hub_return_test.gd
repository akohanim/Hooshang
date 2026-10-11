extends "res://tests/act2_precision_mission_test.gd"
## Enter the hub through its lower well, then jump clear instead of walking
## back through the open half of the same doorway.
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_B04"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	world=Screen.current;player=world.player;room=world.current_room;offset=room.global_position
	player.died.connect(func():deaths+=1)
	continuous=true
	player._ledge_cooldown=3600
	next_room="Prison_Hub"
	trial="blue_return"
	var recipes:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act2_precision.json"))
	for recipe:Dictionary in recipes:
		if recipe.name!="Prison_B04":continue
		var points:Array=recipe.paths[0]
		for i in range(1,points.size()):
			await precision_transfer(points[i-1],points[i])
			if failures or _route_exit_started():break
	await cross_to("Prison_Hub")
	next_room="Prison_Y01"
	room=world.current_room;offset=room.global_position
	trial="hub_well_jump"
	await precision_transfer([88,368],[156,352])
	check(str(world.current_room.name)=="Prison_Hub" and player.global_position.y-offset.y<352,"jumped clear onto hub terrace")
	navigator=load("res://tests/fixtures/act2_precision_navigator.gd").new()
	navigator.run_on_ready=false;navigator.world=world;add_child(navigator)
	if not failures:check(await navigator.navigate(Vector2(616,154)),"walked from lower return to gold entrance")
	if not failures:await cross_to("Prison_Y01")
	check(deaths==0,"lower return transfer has no deaths")
	print("HUB RETURN: ",failures," failures")
	get_tree().quit(1 if failures else 0)
