extends "res://tests/prison_navigation_test.gd"
## Closed shafts are approached from above their gate cap, never spawned inside it.
## Independent setup per pit; escape itself uses inputs and never resets position.
func _ready() -> void:
	await setup_world()
	var cases: Array=[]
	for wing in ["R","G"]:
		for number in [1,2,3]:
			for x in ([20] if number==1 else [18,30] if number==2 else [22]):
				# G02's former side pocket is filled: test that lip, not a
				# point inside the open exit that correctly transfers to G03.
				if wing=="G" and number==2 and x==30: x=28
				var edge: int=19 if number==1 else 17 if number==2 and x==18 else 28 if number==2 else 20
				cases.append(["Prison_%s%02d" % [wing,number],Vector2(x*8+4,154 if wing=="G" and number==2 and x==28 else 166),Vector2(edge*8-12,154)])
	for number in [1,3]: cases.append(["Prison_Y%02d" % number,Vector2(172,154),Vector2(132,154)])
	# Y02 is now the authored dash balcony, not the former walkable wall pocket.
	# Missing its gap must kill once and return to this room's supported entry.
	cases.append(["Prison_Hub",Vector2(112,330),Vector2(132,346)])
	cases.append(["Prison_G03",Vector2(264,138),Vector2(284,154)])
	cases.append(["Prison_G04",Vector2(112,138),Vector2(132,154)])
	cases.append(["Prison_B04",Vector2(112,138),Vector2(132,154)])
	# Run last: the movement navigator intentionally rejects any run after a
	# death, whereas this final case explicitly requires the lethal retry.
	cases.append(["Prison_Y02",Vector2(172,154),Vector2.ZERO,"lethal_retry"])
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
		var before_deaths:=deaths
		var expected_checkpoint:Vector2=world._checkpoint
		world.player.respawn(room.global_position+case[1])
		await frames(35)
		if case.size()>3:
			await frames(150)
			if deaths!=before_deaths+1 or world.current_room!=room \
					or world.player.state==Player.State.DEAD or not world.player.is_on_floor() \
					or world._checkpoint!=expected_checkpoint \
					or world.player.global_position.distance_to(expected_checkpoint)>2:
				failure="balcony miss did not restore its room entry exactly once";break
			passed+=1
			print("RECOVERY PASS Prison_Y02 lethal gap: one death, supported room-entry retry")
			continue
		if not await navigate(case[2]): break
		if str(world.current_room.name)!=case[0] or not world.player.is_on_floor() or deaths!=before_deaths:
			failure="escape did not reach the room floor";break
		passed+=1
		print("RECOVERY PASS ",case[0]," pit ",case[1])
	release()
	print("PRISON RECOVERY: ",passed,"/",cases.size()," recoveries; deaths=",deaths," forbidden=",forbidden," ",failure)
	await shutdown(0 if passed==cases.size() and deaths==1 and not forbidden else 1)
