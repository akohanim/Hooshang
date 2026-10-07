extends "res://tests/prison_navigation_test.gd"
## Independent setup per pit; escape itself uses inputs and never resets position.
func _ready() -> void:
	await setup_world()
	var cases: Array=[]
	for wing in ["R","G"]:
		for number in [1,2,3]:
			for x in ([20] if number==1 else [18,30] if number==2 else [22]):
				var edge: int=19 if number==1 else 17 if number==2 and x==18 else 28 if number==2 else 20
				cases.append(["Prison_%s%02d" % [wing,number],Vector2(x*8+4,166),Vector2(edge*8-12,154)])
	for number in [1,2,3]: cases.append(["Prison_Y%02d" % number,Vector2(172,154),Vector2(132,154)])
	cases.append(["Prison_Hub",Vector2(112,358),Vector2(132,346)])
	cases.append(["Prison_G03",Vector2(264,166),Vector2(284,154)])
	cases.append(["Prison_G04",Vector2(112,166),Vector2(132,154)])
	cases.append(["Prison_B04",Vector2(112,166),Vector2(132,154)])
	var passed:=0
	for case in cases:
		release()
		world.collected.clear()
		world.inserted.clear()
		world._refresh()
		var room: Node
		for candidate in world.rooms:
			if str(candidate.name)==case[0]: room=candidate
		world._enter_room(room,true)
		world.player.respawn(room.global_position+case[1])
		await frames(35)
		if not await navigate(case[2]): break
		if str(world.current_room.name)!=case[0] or not world.player.is_on_floor():
			failure="escape did not reach the room floor";break
		passed+=1
		print("RECOVERY PASS ",case[0]," pit ",case[1])
	release()
	print("PRISON RECOVERY: ",passed,"/",cases.size()," escapes; deaths=",deaths," forbidden=",forbidden," ",failure)
	await shutdown(0 if passed==cases.size() and deaths==0 and not forbidden else 1)
