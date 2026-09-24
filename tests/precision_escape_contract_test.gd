extends "res://tests/precision_escape_test.gd"
## Retry and difficulty contracts, separate from the continuous playthrough.
func _ready()->void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_15"
	world=load("res://ldtk/Act1World.tscn").instantiate();add_child(world)
	await frames(12)
	player=world.player;player.has_dash=true
	player.died.connect(func():died=true)
	var shadow:Darkshang=get_tree().get_first_node_in_group("darkshang")
	var configs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	for c:Dictionary in configs:
		if not c.get("precision_escape",false):continue
		config=c
		for r in world.rooms:
			if r.name==c.name:room=r
		world._enter_room(room,true);await frames(8)
		var pursued:bool=c.encounter.continuous_chase
		check((shadow.state==Darkshang.State.FOLLOWING)==pursued,"%s pursuit matches its pacing" % c.name)
		if c.name!="Level_18":check(not room.get_meta("exit_locked",false),"%s has no hidden exit requirement" % c.name)
		for cp in get_tree().get_nodes_in_group("checkpoint"):
			if not room.is_ancestor_of(cp):continue
			player.respawn(cp.global_position);await frames(8)
			check(world._checkpoint.distance_to(cp.global_position)<2,"%s checkpoint activates on contact" % c.name)
			player.invulnerable_timer=0;player.die();await frames(90)
			check(player.is_on_floor() and player.global_position.distance_to(cp.global_position)<12 and not player.input_locked,"%s death returns to a safe checkpoint" % c.name)
	# These two rising transfers are the crux entrance moves. An ordinary jump
	# and a flat dash both fail against real collision; up-diagonal input passes.
	player.died.disconnect(world._on_player_died)
	for name in ["Level_20","Level_23"]:
		for c:Dictionary in configs:
			if c.name==name:config=c
		for r in world.rooms:
			if r.name==name:room=r
		world._enter_room(room,true);await frames(8)
		var timing:=22 if name=="Level_20" else 18
		for move:Array in [[14,-1,0,8],[14,timing,0,8],[14,timing,-1,8]]:
			release();CrumblingPlatform.reset_all(get_tree())
			var a:Array=config.route[0]
			player.respawn(room.global_position+Vector2(float(a[0])+8,float(a[1])-6))
			player.has_dash=true;await frames(4);died=false
			var reached:=await transfer(0,move,false)
			check(reached==(int(move[2])==-1),"%s crux requires upward diagonal dash: %s" % [name,move])
	release()
	print("PRECISION CONTRACTS: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
