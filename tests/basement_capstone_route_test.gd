extends "res://tests/prison_navigation_test.gd"
## Real child input route. No injected positions, keys or mechanism state.
const OUT := "res://output/prison_challenge/basement_capstone"
var saw_swim := false
var full_loop := false
var capture_root := OUT
var phase_delay_frames := 0
var retry_mode := false
var retry_verified := false
var late_mode := false
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	retry_mode="--retry" in OS.get_cmdline_user_args()
	late_mode="--late" in OS.get_cmdline_user_args()
	if late_mode:phase_delay_frames=90
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delay="):phase_delay_frames=int(arg.trim_prefix("--delay="))
		if arg.begins_with("--output="):capture_root=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(capture_root)
	world=load("res://ldtk/Act2World.tscn").instantiate()
	full_loop="--full" in OS.get_cmdline_user_args()
	world.debug_start_room="Prison_Hub" if full_loop else "Prison_B03"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed:=PackedScene.new()
	packed.pack(actor)
	actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func():deaths+=1)
	await frames(20)
	await run_route()
	release()
	var result:={"failure":failure,"deaths":deaths,"forbidden":forbidden,"swim":saw_swim,"full_loop":full_loop,"backtrack": "--backtrack" in OS.get_cmdline_user_args(),"room":str(world.current_room.name),"completed":world.circuits.save_completed(),"trace":trace,"retry_verified":retry_verified,"late_mode":late_mode,"phase_delay_frames":phase_delay_frames}
	FileAccess.open(capture_root+("/full_route.json" if full_loop else "/route.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PUMP ROOM INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"swim":saw_swim}))
	await shutdown(0 if failure=="" and deaths==navigation_deaths_allowed and not forbidden and saw_swim and (not (retry_mode or late_mode) or retry_verified) else 1)
func run_route() -> void:
	skip_patrol_wait=true
	if full_loop and not retry_verified:
		if not await approach():return
		for at in [Vector2(228,136),Vector2(228,112),Vector2(256,90)]:
			if not await navigate(at):return
	var gate=world.props.filter(func(p):return p.kind=="CircuitGate" and p.get_parent().get_parent()==world.current_room)[0]
	var hit:=KinematicCollision2D.new()
	if not world.player.test_move(Transform2D(0,world.current_room.global_position+Vector2(256,82)),Vector2(40,0),hit) or hit.get_collider()!=gate.get_node("Barrier"):
		failure="key gate can be bypassed";return
	await capture("01_closed")
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	if not world.circuits.solved("basement_pump_valve"):
		failure="dry valve not operated";return
	geo=world.current_room.get_node("PrisonGeometry")
	if not await move_to(Vector2(228,136),"Prison_B03"):return
	for at in [Vector2(184,156),Vector2(144,160),Vector2(112,164)]:
		if not await navigate(at):return
	if not await wait_patrol_high(Vector2(112,164)):return
	var reached_seal: bool=await swim_brake(Vector2(112,140))
	if reached_seal:reached_seal=await swim_brake(Vector2(72,128))
	if not reached_seal:
		if not late_mode or retry_verified or deaths!=1:return
		release();await frames(100)
		if not world.player.is_on_floor() or world.player.swimming() or not world.circuits.solved("basement_pump_valve") or world.circuits.solved("basement_pump_key"):
			failure="late patrol failure did not restore dry retry";return
		failure="";phase_delay_frames=0;navigation_deaths_allowed=1;retry_verified=true
		await capture("late_retry_checkpoint")
		await run_route();return
	saw_swim=world.player.swimming()
	await capture("02_deep_seal")
	if world.circuits.solved("basement_pump_key"):
		failure="one seal opened the key gate";return
	if retry_mode and not retry_verified:
		release()
		var event:=InputEventAction.new()
		event.action="respawn";event.pressed=true;Input.parse_input_event(event)
		await frames(1)
		event=InputEventAction.new();event.action="respawn";event.pressed=false;Input.parse_input_event(event)
		await frames(100)
		if deaths!=1 or not world.player.is_on_floor() or world.player.swimming() or not world.circuits.solved("basement_pump_valve") or world.circuits.solved("basement_pump_key"):
			failure="deep retry did not preserve a solvable dry checkpoint";return
		navigation_deaths_allowed=1
		retry_verified=true;await capture("retry_checkpoint")
		await run_route();return
	if not await wait_patrol_high(Vector2(72,128)):return
	if not await swim_brake(Vector2(112,140)):return
	if not await swim_brake(Vector2(112,164)):return
	for at in [Vector2(144,160),Vector2(184,156),Vector2(228,112),Vector2(256,90)]:
		if not await navigate(at):return
	if not await move_to(Vector2(232,58),"Prison_B03"):return
	await capture("03_launch")
	Input.action_press("jump")
	await frames(18)
	Input.action_release("jump")
	Input.action_press("move_left")
	Input.action_press("dash")
	await frames(10)
	Input.action_release("dash")
	release()
	await frames(20)
	if not await navigate(Vector2(184,34)):return
	if not world.circuits.solved("basement_pump_key"):
		failure="high seal not reached";return
	await capture("04_key_open")
	for at in [Vector2(232,58),Vector2(256,90),Vector2(296,90)]:
		if not await navigate(at):return
	await frames(8)
	if not world.collected.has("Blue"):
		failure="Blue key not collected";return
	await capture("05_key")
	# Climb the existing left stairs to the upper shortcut after the reward.
	for at in [Vector2(256,90)]:
		if not await navigate(at):return
	if not await move_to(Vector2(232,58),"Prison_B03"):return
	Input.action_press("jump")
	await frames(18)
	Input.action_release("jump")
	Input.action_press("move_left")
	Input.action_press("dash")
	await frames(10)
	Input.action_release("dash")
	release()
	await frames(20)
	if not await navigate(Vector2(184,34)):return
	if not await cross("Prison_B04"):return
	if not await cross("Prison_Hub"):return
	await capture("06_hub")
	if "--backtrack" in OS.get_cmdline_user_args():await return_loop()
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(capture_root+"/"+("full_" if full_loop else "")+label+".png")

func approach() -> bool:
	if not await cross("Prison_B01"):return false
	var intro=load("res://tests/precision_basement_intro_test.gd").new()
	intro.run_on_ready=false;intro.return_to_hub=false
	add_child(intro);intro.world=world
	var on_death=func():intro.deaths+=1
	world.player.died.connect(on_death)
	await intro.run_route()
	intro.release();failure=intro.failure
	forbidden=forbidden or intro.forbidden
	trace.append_array(intro.trace)
	world.player.died.disconnect(on_death);intro.queue_free()
	if failure!="":return false
	var stores=load("res://tests/precision_basement_stores_test.gd").new()
	stores.run_on_ready=false;stores.return_to_entrance=false
	add_child(stores);stores.world=world
	var stores_death=func():stores.deaths+=1
	world.player.died.connect(stores_death)
	await stores.run_route()
	stores.release();failure=stores.failure
	forbidden=forbidden or stores.forbidden
	trace.append_array(stores.trace)
	world.player.died.disconnect(stores_death);stores.queue_free()
	return failure==""

func return_loop() -> void:
	if not await cross("Prison_B04"):return
	if not await cross("Prison_B03"):return
	if not await navigate(Vector2(228,136)):return
	if not await navigate(Vector2(292,144)):return
	if not await cross("Prison_B02"):return
	var stores=load("res://tests/precision_basement_stores_test.gd").new()
	stores.run_on_ready=false
	add_child(stores);stores.world=world
	var stores_death=func():stores.deaths+=1
	world.player.died.connect(stores_death)
	await stores.return_route()
	stores.release();failure=stores.failure
	forbidden=forbidden or stores.forbidden
	trace.append_array(stores.trace)
	world.player.died.disconnect(stores_death);stores.queue_free()
	if failure!="":return
	var intro=load("res://tests/precision_basement_intro_test.gd").new()
	intro.run_on_ready=false
	add_child(intro);intro.world=world
	var on_death=func():intro.deaths+=1
	world.player.died.connect(on_death)
	await intro.return_route()
	intro.release();failure=intro.failure
	forbidden=forbidden or intro.forbidden
	trace.append_array(intro.trace)
	world.player.died.disconnect(on_death);intro.queue_free()
	if failure!="":return
	await capture("07_backtrack_hub")

func wait_patrol_high(anchor: Vector2) -> bool:
	var patrol=world.props.filter(func(p):return p.kind=="Patrol" and p.get_parent().get_parent()==world.current_room)[0]
	var release_frame:=-1
	for frame in 720:
		release()
		var delta: Vector2=anchor-local_player()
		if absf(delta.x)>2:Input.action_press("move_right" if delta.x>0 else "move_left")
		if absf(delta.y)>2:Input.action_press("move_down" if delta.y>0 else "move_up")
		await frames(1)
		var angle: float=patrol.clock*2.0*float(patrol.fields.Speed)+float(patrol.fields.Phase)
		if release_frame<0 and local_player().distance_to(anchor)<5 and sin(angle)<-.9 and cos(angle)<0:
			release_frame=frame+phase_delay_frames
		if release_frame>=0 and frame>=release_frame:
			release();return true
	release();failure="no safe swim observation window";return false

func swim_brake(target: Vector2) -> bool:
	for frame in 240:
		release()
		var delta: Vector2=target-local_player()
		var aim_y: float=delta.y-world.player.velocity.y*.22
		if absf(delta.x)>2:Input.action_press("move_right" if delta.x>0 else "move_left")
		if absf(aim_y)>1:Input.action_press("move_down" if aim_y>0 else "move_up")
		await frames(1)
		if deaths>navigation_deaths_allowed:failure="death during swim turn";return false
		if local_player().distance_to(target)<3 and absf(world.player.velocity.y)<20:
			release();return true
	release();failure="swim turn did not settle";return false
