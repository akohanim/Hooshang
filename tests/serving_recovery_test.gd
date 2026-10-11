extends "res://tests/prison_navigation_test.gd"
## Establish the expired-attempt far side, then retreat using only input actions.
func _ready() -> void:
	SaveGame.unbind()
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_R02"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed:=PackedScene.new()
	packed.pack(actor)
	actor.free()
	world.player_scene=packed
	add_child(world)
	world.player.died.connect(func(): deaths+=1)
	skip_patrol_wait=true
	await frames(15)
	world.player.respawn(world.current_room.global_position+Vector2(40,154))
	await frames(15)
	await retreat()
	release()
	print("SERVING RECOVERY INPUT FIXTURE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"at":var_to_str(local_player())}))
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)
func retreat() -> void:
	for panel in world.props:
		if panel.get_parent().get_parent()!=world.current_room or panel.kind not in ["TimedGate","TimedShutter"]:continue
		var at := Vector2(268,154) if panel.kind=="TimedGate" else Vector2(92,150) if bool(panel.fields.get("RequireBank",false)) else Vector2(148,114)
		var travel := Vector2(0,40) if bool(panel.fields.get("RequireBank",false)) else Vector2(-40,0)
		var hit := KinematicCollision2D.new()
		if not world.player.test_move(Transform2D(0,world.current_room.global_position+at),travel,hit) or hit.get_collider()!=panel.get_node("Barrier"):
			failure="closed shutter did not physically seal its passage";return
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	if not world.timers.active("cafeteria_serving"):
		failure="far return lever failed";return
	var exit_seal=world.props.filter(func(p): return p.kind=="TimedShutter" and p.get_parent().get_parent()==world.current_room and bool(p.fields.get("RequireBank",false)))[0]
	var collision:=KinematicCollision2D.new()
	var blocked: bool=world.player.test_move(Transform2D(0,world.current_room.global_position+Vector2(92,150)),Vector2(0,40),collision)
	if not blocked or collision.get_collider()!=exit_seal.get_node("Barrier"):
		failure="return activation bypassed completion exit";return
	for point in [Vector2(64,130),Vector2(112,130)]:
		if not await navigate(point):return
	if world.timers.solved("cafeteria_serving"):
		failure="return lever incorrectly banked relay";return
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(24)
	Input.action_release("jump")
	for i in 70:
		if local_player().x>=160:break
		await frames(1)
	release()
	await frames(12)
	if not await navigate(Vector2(168,114)):return
	var patrol=world.props.filter(func(p):return p.kind=="Patrol" and p.get_parent().get_parent()==world.current_room and p.origin.x==200)[0]
	for i in 200:
		var angle: float=patrol.clock*2.0*float(patrol.fields.get("Speed",1.0))+float(patrol.fields.get("Phase",0.0))
		if sin(angle)<-0.75 and cos(angle)<0:break
		await frames(1)
	if not await navigate(Vector2(232,154)):return
	if not await navigate(Vector2(208,154)):return
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	if not await navigate(Vector2(288,154)):return
	if world.timers.solved("cafeteria_serving") or exit_seal.barrier.disabled:
		failure="recovery route granted completion";return
