extends "res://tests/ladder_overhaul_test.gd"
## Traversal coverage separate from the gate/attack/state contract tests. Gate
## unlocking is tested there; here the resulting routes use real player physics.
func _ready()->void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_V10"
	world=load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(8)
	player=world.player
	player.died.disconnect(world._on_player_died)
	player.died.disconnect(world.get_node("ChasePacing")._death)
	world.set_physics_process(false)
	for exit in get_tree().get_nodes_in_group("exit"):exit.set_deferred("monitoring",false)
	var configs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	var solutions:Dictionary={}
	for c:Dictionary in configs.slice(0,5):
		var room:Node2D
		for r in world.rooms:
			if r.name==c.name:room=r
		world._enter_room(room,true)
		origin=room.global_position
		var chamber:=room.get_node("DarknessRoom")
		chamber.set_physics_process(false)
		chamber._set_phase(2)
		chamber._update_phase_door()
		chamber.gate_shape.set_deferred("disabled",true)
		await frames(3)
		if c.has("ladders"):
			for i in c.ladders.size():
				var solved:=false
				for delay in range(0,360,20):
					if await climb(c.ladders[i],c.route[i+1],delay):solved=true;break
				check(solved,"%s ladder leg %d" % [c.name,i+1])
			continue
		route=[]
		for r:Array in c.route:route.append(Vector3(r[0],r[1],r[2]))
		var timings:Array=[]
		for i in range(route.size()-1):
			var solved:=false
			var departure:Vector3=route[i]
			if c.name=="Level_25" and i==route.size()-2:
				departure.x+=24;departure.z-=24
			for wait_time in [0,45,90]:
				for timing in [-1,12,8,16,4,20,24]:
					if await jump_leg(departure,route[i+1],timing,wait_time):
						timings.append(timing);solved=true;break
				if solved:break
			check(solved,"%s route leg %d" % [c.name,i+1])
			if not solved:timings.append(-99)
		solutions[c.name]=timings
	DirAccess.make_dir_recursive_absolute("res://output/darkshang_redesign")
	FileAccess.open("res://output/darkshang_redesign/route_inputs.json",FileAccess.WRITE).store_string(JSON.stringify(solutions,"  "))
	release()
	print("DARKNESS GEOMETRY: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
