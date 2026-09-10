extends "res://tests/level_v9_test.gd"
## Route acceptance for all fifteen new layouts, driven by real player input.
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_V10"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(5)
	player=world.player
	world.set_physics_process(false)
	player.died.disconnect(world._on_player_died)
	for exit in get_tree().get_nodes_in_group("exit"):
		exit.set_deferred("monitoring",false)
	var definitions: Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	var solutions: Dictionary={}
	for definition: Dictionary in definitions:
		var room: Node2D=null
		for candidate in world.rooms:
			if str(candidate.name)==definition.name:room=candidate
		check(room!=null,"%s exists" % definition.name)
		if room==null:continue
		world.current_room=room
		origin=room.global_position
		route=[]
		for r: Array in definition.route:route.append(Vector3(r[0],r[1],r[2]))
		var timings: Array=[]
		for i in range(route.size()-1):
			var solved:=false
			for timing in [-1,12,16,8,20,4,24]:
				if await jump_leg(route[i],route[i+1],timing):
					timings.append(timing)
					solved=true
					break
			check(solved,"%s jump %d" % [definition.name,i+1])
			if not solved:timings.append(-99)
		solutions[definition.name]=timings
	# The last room literally reuses the opening's collision layout.
	var first:Node2D
	var last:Node2D
	for room in world.rooms:
		if room.name=="Level_0":first=room
		if room.name=="Level_25":last=room
	var first_tiles:=first.get_node("Collisions") as TileMapLayer
	var last_tiles:=last.get_node("Collisions") as TileMapLayer
	check(first_tiles.get_used_cells()==last_tiles.get_used_cells(),"homecoming retains original cubicle geometry")
	check(world.room_backdrop_overrides["Level_0"]==world.room_backdrop_overrides["Level_25"],"homecoming uses original cubicle art")
	check(last.get_node("Entities").get_child_count()==1,"homecoming has one spawn and no competing opening/exit trigger")
	var file:=FileAccess.open("res://output/act1_expansion/route_timings.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(solutions,"  "))
	release()
	print("ACT I EXPANSION: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
