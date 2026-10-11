extends "res://tests/prison_navigation_test.gd"
## Earned intro route; real inputs, no position or puzzle-state grants.
const OUT="res://output/prison_precision/library_stacks"
var contacts: Array=[]
var dwell:=6
var mode:="route"
var expected_deaths:=0
var landing_offset:=0.0
var late_verified:=false
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	if "--late" in OS.get_cmdline_user_args():mode="late_retry";expected_deaths=1
	if "--bypass" in OS.get_cmdline_user_args():mode="floor_bypass"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--offset="):
			landing_offset=float(arg.trim_prefix("--offset="));mode="offset_%d" % int(landing_offset)
		if arg.begins_with("--hold="):
			dwell=int(arg.trim_prefix("--hold="));mode="hold_%d" % dwell
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_G02"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed=PackedScene.new();packed.pack(actor);actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func():deaths+=1)
	await frames(20)
	if mode=="floor_bypass":await floor_bypass()
	else:await run_route()
	release()
	var result={"failure":failure,"deaths":deaths,"forbidden":forbidden,"contacts":contacts,"room":str(world.current_room.name),"trace":trace}
	FileAccess.open(OUT+"/"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PRECISION G02: ",JSON.stringify(result))
	await shutdown(0 if failure=="" and deaths==expected_deaths and not forbidden else 1)
func capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+label+".png")
func run_route() -> void:
	await capture("01_observe")
	if local_player().x>128 and local_player().y>150:
		# The generic waypoint graph omits floor-row23 under this low beam.
		# Walk the real passage, then jump through its small approach step.
		for frame in 240:
			Input.action_release("move_left");Input.action_release("move_right")
			var aim: float=64-local_player().x-world.player.velocity.x*.10
			Input.action_press("move_left" if aim<0 else "move_right")
			await frames(1)
			if world.player.is_on_floor() and absf(local_player().x-64)<4:break
		release();await frames(8)
		if not await reach(Vector2(64,162),false,false):return
		await capture("approach_passage")
	if not await navigate(Vector2(104,146)):return
	if not await reach(Vector2(160,122),true):return
	await capture("02_first")
	if mode=="late_retry" and not late_verified:
		release();await frames(160)
		var stones=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform)
		if deaths!=1 or world.player.global_position.distance_to(world._checkpoint)>4 or stones.any(func(p):return p._spent or p._falling):
			failure="collapse did not restore checkpoint and four stones";return
		late_verified=true;navigation_deaths_allowed=1
		await capture("late_respawn")
		await run_route();return
	if not await reach(Vector2(216,122),false,true,true):return
	await capture("03_low_crossing")
	Input.action_press("move_right")
	for frame in 20:
		await frames(1)
		if local_player().x>=222:break
	release()
	if not await reach(Vector2(264,90),true):return
	await capture("04_outer_turn")
	if not await reach(Vector2(216,58),true):return
	await capture("05_reverse")
	if not await reach(Vector2(160,34),true):return
	if not world.circuits.solved("library_stacks"):
		failure="stack seals incomplete";return
	await capture("06_bank")
	if not await navigate(Vector2(176,34)):return
	if not await reach(Vector2(280,58),false):return
	if not await cross("Prison_G03"):return
	await capture("07_exit")
func reach(target: Vector2, diagonal: bool, use_dash := true, low := false) -> bool:
	var origin_room=world.current_room
	for stone in world.current_room.get_node("Entities").get_children():
		if stone is CrumblingPlatform and absf(stone.position.x-target.x)<1 and absf(stone.position.y-target.y-10)<1:
			target.x+=landing_offset;break
	release();Input.action_press("jump")
	for i in 180:
		Input.action_release("move_left");Input.action_release("move_right")
		var aim: float=target.x-local_player().x-world.player.velocity.x*0.10
		Input.action_press("move_left" if aim<0 else "move_right")
		if use_dash and i==(8 if low else 12):
			if diagonal:Input.action_press("move_up")
			Input.action_press("dash")
		if i==22:Input.action_release("move_up");Input.action_release("dash")
		if i==(4 if low else 24):Input.action_release("jump")
		await frames(1)
		if world.current_room!=origin_room:
			release();await frames(50);return true
		if deaths>expected_deaths:break
		if world.player.is_on_floor() and absf(local_player().y-target.y)<2 and absf(local_player().x-target.x)<=7:
			release();await frames(dwell)
			for stone in world.current_room.get_node("Entities").get_children():
				if stone is CrumblingPlatform and absf(stone.position.x-target.x)<=4 and absf(stone.position.y-target.y-10)<1:
					contacts.append({"stone":str(stone.position),"age":stone._timer,"at":str(local_player())})
			return true
	release();failure="return landing missed "+str(target)+" at "+str(local_player());return false

func reverse_route() -> void:
	if not await navigate(Vector2(256,58)):return
	if not await reach(Vector2(216,58),false,false):return
	if not await reach(Vector2(160,34),true):return
	Input.action_press("move_left")
	for frame in 90:
		await frames(1)
		if local_player().x<=128:break
	release();await frames(60)
	for frame in 240:
		Input.action_release("move_left");Input.action_release("move_right")
		var aim: float=216-local_player().x-world.player.velocity.x*.10
		Input.action_press("move_left" if aim<0 else "move_right")
		await frames(1)
		if world.player.is_on_floor() and absf(local_player().x-216)<4:break
	release();await frames(8)
	if not await reach(Vector2(244,170),false,false,true):return
	if str(world.current_room.name)!="Prison_G01":
		if not await cross("Prison_G01"):return
	await capture("reverse_exit")

func floor_bypass() -> void:
	for frame in 240:
		Input.action_release("move_left");Input.action_release("move_right")
		var aim: float=208-local_player().x-world.player.velocity.x*.10
		Input.action_press("move_left" if aim<0 else "move_right")
		await frames(1)
		if world.player.is_on_floor() and absf(local_player().x-208)<4:break
	release();await frames(10)
	Input.action_press("jump");await frames(12)
	Input.action_press("move_up");Input.action_press("dash");await frames(10)
	release();await frames(60)
	var stones=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform)
	if deaths or local_player().y<160 or stones.any(func(p):return p._spent) or world.circuits.solved("library_stacks"):
		failure="floor bypass probe unexpectedly reached the challenge or died"
	await capture("floor_bypass_blocked")
