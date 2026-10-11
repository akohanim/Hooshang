extends Node
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_Hub"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	for i in 20:await get_tree().physics_frame
	var world=Screen.current
	world.portals.clear()
	var nav=load("res://tests/fixtures/act2_precision_navigator.gd").new()
	nav.run_on_ready=false;nav.world=world
	add_child(nav)
	var failures:=0
	for target in [Vector2(24,154),Vector2(616,154),Vector2(24,346),Vector2(616,346),Vector2(88,18),Vector2(408,18),Vector2(88,362),Vector2(408,362)]:
		world.player.respawn(world.spawn_point_for(world.current_room))
		world.player.input_locked=false
		for i in 8:await get_tree().physics_frame
		nav.failure=""
		var reached:bool
		if target==Vector2(408,362):
			reached=await nav.navigate(Vector2(444,370))
			if reached:reached=await nav.gym_go(world.current_room.global_position+target,false)
		else:reached=await nav.navigate(target)
		print("HUB ",target," reached=",reached," at=",nav.local_player()," failure=",nav.failure)
		if not reached:failures+=1
	nav.release()
	print("PRECISION HUB: ",failures," failures")
	get_tree().quit(1 if failures else 0)
