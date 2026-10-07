extends "res://tests/prison_navigation_test.gd"
## Room-local challenge checks complement the continuous mission and retreat runs.
## Reuse the input navigator so timing hazards are approached from safe supports.
var saw_swim := false
var saw_dash := false
func _physics_process(_delta: float) -> void:
	if world==null or world.player==null: return
	saw_swim=saw_swim or world.player.swimming()
	saw_dash=saw_dash or world.player.state_name()=="DASH"
func _ready() -> void:
	await setup_world()
	var failures:=0
	var total_deaths:=0
	for wing in ["R","G","B","Y"]:
		for number in [1,2,3]:
			var room: Node
			var name:="Prison_%s%02d" % [wing,number]
			for candidate in world.rooms:
				if str(candidate.name)==name: room=candidate
			release()
			await frames(65)
			deaths=0
			world._enter_room(room,true)
			world._portal_cooldown=1000.0
			# These rooms enter through a seam, not their debug PlayerSpawn.
			var start: Vector2=world.spawn_point_for(room)
			if name=="Prison_R02": start=room.global_position+Vector2(292,154)
			if name=="Prison_G01": start=room.global_position+Vector2(100,170)
			world.player.respawn(start)
			await frames(20)
			var success:=true
			if wing=="Y":
				success=await navigate(Vector2(172,154))
				for point in [Vector2(176,114),Vector2(196,98)]:
					if success: success=await gym_go(room.global_position+point,false)
			if success: success=await navigate(Vector2(296,90) if wing=="B" else Vector2(132,154) if name=="Prison_R02" else Vector2(288,154))
			if not success:
				failures+=1
				print("FAIL ",name," ",failure)
			else: print("PASS ",name)
			total_deaths+=deaths
			failure=""
	release()
	print("PRISON ROUTES: ",failures," failures, deaths=",total_deaths," swim=",saw_swim," wall_jump=",saw_wall_jump," dash=",saw_dash," forbidden=",forbidden)
	await shutdown(0 if failures==0 and total_deaths==0 and saw_swim and saw_wall_jump and not forbidden else 1)
