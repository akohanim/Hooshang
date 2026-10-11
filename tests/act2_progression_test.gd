extends Node
var failures:=0
var world:LdtkWorld
func _ready() -> void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Act_2_Level_3"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(10)
	world=Screen.current as LdtkWorld
	world.player.has_dash=true
	for n in range(3,13):
		var room:=world.current_room
		var ex:=world._exit_in(room)
		world.player.respawn(ex.global_position+Vector2(-20,26))
		Input.action_press("move_right")
		for i in 90:
			await frames(1)
			if world.current_room!=room:break
		Input.action_release("move_right")
		await frames(40)
		check(str(world.current_room.name)=="Act_2_Level_%d" % (n+1),"actual doorway advances to room "+str(n+1))
		# A death at the entrance must not trigger the return strip.
		world.player.respawn(world.spawn_point_for(world.current_room))
		await frames(20)
		check(str(world.current_room.name)=="Act_2_Level_%d" % (n+1),"retry stays in the new room")
	var finale:=world.current_room
	var final_exit:=world._exit_in(finale)
	world.player.respawn(final_exit.global_position+Vector2(-20,26))
	Input.action_press("move_right")
	await frames(90)
	Input.action_release("move_right")
	await frames(45)
	check(str(world.current_room.name)=="Act_2_Level_14" and not Game.completed,
		"room 13 leads into the castle approach without completing the act")
	check(finale.get_node("SkyGarden").get_child_count()==0,
		"leaving the final garden adds no premature completion banner")
	# The approach now has a real story encounter. Finish its retained control
	# ownership before this doorway fixture changes rooms for the return sweep.
	for i in 360:
		if not world.player.input_locked and not world._transitioning:break
		Input.action_press("skip_dialogue")
		await frames(1)
	Input.action_release("skip_dialogue")
	check(not world.player.input_locked,"castle encounter releases controls through ordinary skip input")
	# Independently retain the pre-prison return-chain acceptance test.
	world._enter_room(finale,true)
	world.player.respawn(world.spawn_point_for(finale))
	world._arm_return(world._room_before(finale))
	for candidate in world.rooms:
		if str(candidate.name)=="Act_2_Level_8":
			check(candidate.get_node("SkyGarden").get_child_count()==0,
				"room 8 continues without a premature completion banner")
	for n in range(13,3,-1):
		var room:=world.current_room
		world.player.respawn(world.spawn_point_for(room))
		await frames(10)
		Input.action_press("move_left")
		for i in 100:
			await frames(1)
			if world.current_room!=room:break
		Input.action_release("move_left")
		await frames(40)
		check(str(world.current_room.name)=="Act_2_Level_%d" % (n-1),
			"actual return doorway reaches room %d [actual %s, position %s, state %s, locked %s, armed %s, transition %s]" % [
				n-1,world.current_room.name,world.player.global_position-world.current_room.global_position,
				world.player.state_name(),world.player.input_locked,world._return_armed,world._transitioning])
		check(world.player.is_on_floor(),"return lands clear of the destination trigger, on solid ground")
		if str(world.current_room.name)!="Act_2_Level_%d" % (n-1):break
	check(world._return_zone.global_position.x<world.room_rect(world.current_room).get_center().x,"legacy tall-room portal keeps the new room's return at its entrance")
	print("ACT2_PROGRESSION: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
func frames(n:int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
