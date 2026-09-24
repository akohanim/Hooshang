extends "res://tests/level_v9_test.gd"
## Real input climbs and dismounts, with live moving hazards. Each failed trial
## restarts at the foot; a trial passes only after landing on the scaffold.
func _ready() -> void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_V10"
	world=load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(8)
	player=world.player
	player.died.disconnect(world._on_player_died)
	player.died.disconnect(world.get_node("ChasePacing")._death)
	world.set_physics_process(false)
	var configs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	for c:Dictionary in configs.slice(0,5):
		if not OS.get_cmdline_user_args().is_empty() and c.name not in OS.get_cmdline_user_args():continue
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
		for door in get_tree().get_nodes_in_group("exit"):door.set_deferred("monitoring",false)
		await frames(4)
		var tones:Dictionary={};var motions:Dictionary={};var ladders:=0
		for e in room.get_node("Entities").get_children():
			if e is Ladder:ladders+=1
			if e is DarkThought:tones[e.tone]=true;motions[e.motion]=true
		check(ladders==c.ladders.size() and ladders>=4,"%s imports climbable ladders" % c.name)
		check(tones.size()==3 and motions.size()>=3,"%s has all tones and varied motion" % c.name)
		if c.name=="Level_V10":
			player.respawn(origin+Vector2(100,190))
			Input.action_press("move_up")
			await frames(6)
			check(player.state==Player.State.CLIMB,"first life grips the ladder")
			var retry:=player.global_position
			player.die();player.respawn(retry)
			await frames(6)
			check(player.state==Player.State.CLIMB and player.global_position.y<retry.y,"death on the same rail reacquires climbing")
			release()
		for i in c.ladders.size():
			var rail:Array=c.ladders[i]
			var dest:Array=c.route[i+1]
			var solved:=false
			for wait in range(0,360,20):
				if await climb(rail,dest,wait):solved=true;break
			check(solved,"%s ladder %d climb and scaffold landing with live thoughts" % [c.name,i+1])
	release()
	print("LADDER OVERHAUL: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func climb(rail:Array,dest:Array,wait:int)->bool:
	release()
	Input.action_release("move_down")
	DarkThought.reset_all(get_tree())
	player.respawn(origin+Vector2(rail[0],rail[2]-6))
	await frames(4)
	# Upper split shafts begin mid-air: grip before waiting, as in a transfer.
	Input.action_press("move_up")
	await frames(3)
	Input.action_release("move_up")
	await frames(wait)
	if player.state==Player.State.DEAD:return false
	Input.action_press("move_up")
	var climbed:=false
	for f in 240:
		await frames(1)
		if player.state==Player.State.DEAD:break
		if player.global_position.y-origin.y<=float(dest[1])-18:
			climbed=true;break
	Input.action_release("move_up")
	if not climbed:
		return false
	Input.action_press("move_right")
	Input.action_press("jump")
	for f in 90:
		var dx:float=origin.x+dest[0]+dest[2]/2.0-player.global_position.x
		Input.action_release("move_left");Input.action_release("move_right")
		if absf(dx)>2:Input.action_press("move_right" if dx>0 else "move_left")
		if f==12:Input.action_release("jump")
		await frames(1)
		if player.state==Player.State.DEAD:break
		if f>3 and player.is_on_floor() and absf(player.global_position.y-origin.y-(float(dest[1])-6))<3 and absf(dx)<12:
			release();return true
	release()
	return false
