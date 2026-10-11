extends "res://tests/prison_navigation_test.gd"
## Real child input route. No injected positions, keys or mechanism state.
const OUT := "res://output/prison_precision/basement_stores"
var saw_swim := false
var wet_retry:=false
var retry_verified:=false
var dwell:=6
var mode:="route"
var return_to_entrance:=true
var phase_delay_frames:=0
var stone_contacts: Array=[]
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	wet_retry="--wet-retry" in OS.get_cmdline_user_args()
	if wet_retry:mode="wet_retry"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delay="):phase_delay_frames=int(arg.trim_prefix("--delay="));mode="delay_%d" % phase_delay_frames
		if arg.begins_with("--hold="):dwell=int(arg.trim_prefix("--hold="));mode="hold_%d" % dwell
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_B02"
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
	var result:={"failure":failure,"deaths":deaths,"forbidden":forbidden,"swim":saw_swim,"room":str(world.current_room.name),"completed":world.circuits.save_completed(),"retry_verified":retry_verified,"dwell_frames":dwell,"phase_delay_frames":phase_delay_frames,"stone_contacts":stone_contacts,"trace":trace}
	FileAccess.open(OUT+"/"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FLOODED STORES INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"swim":saw_swim}))
	await shutdown(0 if failure=="" and deaths==0 and not forbidden and saw_swim else 1)
func run_route() -> void:
	skip_patrol_wait=true
	var gate=world.props.filter(func(p):return p.kind=="FloodGate" and p.get_parent().get_parent()==world.current_room)[0]
	var hit:=KinematicCollision2D.new()
	if not world.player.test_move(Transform2D(0,world.current_room.global_position+Vector2(24,144)),Vector2(-40,0),hit) or hit.get_collider()!=gate.get_node("Barrier"):
		failure="closed sluice does not block exit";return
	await capture("01_closed")
	for at in [Vector2(196,152),Vector2(184,156)]:
		if not await navigate(at):return
	if not await wait_patrol_high(Vector2(184,160)):return
	if not await navigate(Vector2(144,156)):return
	if not await swim_brake(Vector2(144,140)):return
	saw_swim=world.player.swimming()
	if not await land_from_water():return
	if wet_retry and not retry_verified:
		release()
		var first=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform and p.position.x==120)[0]
		var saw_collapse=false
		for frame in 120:
			await frames(1)
			if first._falling:saw_collapse=true
			if saw_collapse and not first._spent and Rect2(first.global_position-first.size*.5,first.size).intersects(world.player.hitbox_rect()):
				failure="stone restored around the swimmer";return
		if not saw_collapse:failure="water retry did not exercise an actual collapse";return
		var stones=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform)
		if deaths or not world.player.swimming() or stones.any(func(p):return p._spent or p._falling):
			failure="return to water did not safely restore the two stones";return
		retry_verified=true;await capture("water_reset")
		if not await wait_patrol_high(Vector2(112,160)):return
		if not await navigate(Vector2(144,160)):return
		if not await swim_brake(Vector2(144,140)):return
		if not await land_from_water():return
	await capture("first_stone")
	if not await reach(Vector2(88,106),true):return
	var air_stones=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform)
	if air_stones.any(func(p):return not p._spent):
		failure="a stone reset during the dry airborne sequence";return
	stone_contacts.append({"stone":"upper","age":air_stones.filter(func(p):return p.position.x==88)[0]._timer})
	if world.player.swimming() or not world.player.is_on_floor():
		failure="valve pocket is not dry stable footing";return
	await capture("02_dry_pocket")
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	if not world.circuits.solved("basement_stores"):
		failure="dry valve did not open sluice";return
	await capture("03_valve_open")
	if not await move_to(Vector2(120,152),"Prison_B02"):return
	for at in [Vector2(112,168),Vector2(64,168),Vector2(48,154)]:
		if not await navigate(at):return
	if not await cross("Prison_B03"):return
	await capture("04_next_room")
	if return_to_entrance:await return_route()

func return_route() -> void:
	var keys_before: Array=world.collected.duplicate()
	skip_patrol_wait=true
	if str(world.current_room.name)!="Prison_B02":
		if not await cross("Prison_B02"):return
	for at in [Vector2(64,168),Vector2(144,168),Vector2(184,156),Vector2(240,112)]:
		if not await navigate(at):return
	if not world.circuits.solved("basement_stores") or world.collected!=keys_before:
		failure="return changed the sluice or existing key state";return
	await capture("05_return")
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+label+".png")

func reach(target: Vector2, diagonal: bool, use_dash := true) -> bool:
	var origin_room=world.current_room
	release();Input.action_press("jump")
	for i in 180:
		Input.action_release("move_left");Input.action_release("move_right")
		var aim: float=target.x-local_player().x-world.player.velocity.x*0.10
		Input.action_press("move_left" if aim<0 else "move_right")
		if use_dash and i==12:
			if diagonal:Input.action_press("move_up")
			Input.action_press("dash")
		if i==22:Input.action_release("move_up");Input.action_release("dash")
		if i==24:Input.action_release("jump")
		await frames(1)
		if world.current_room!=origin_room:
			release();await frames(50);return true
		if deaths:break
		if world.player.is_on_floor() and absf(local_player().y-target.y)<2 and absf(local_player().x-target.x)<=7:
			release();await frames(dwell);return true
	release();failure="return landing missed "+str(target)+" at "+str(local_player());return false


func land_from_water() -> bool:
	var stone=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform and p.position.x==120)[0]
	if not await move_to(Vector2(132,128),"Prison_B02"):return false
	for frame in 90:
		Input.action_release("move_left");Input.action_release("move_right")
		var aim: float=120-local_player().x-world.player.velocity.x*.10
		Input.action_press("move_left" if aim<0 else "move_right")
		await frames(1)
		if world.player.state==Player.State.EXIT_WATER and stone._timer>.1:
			failure="water-exit animation consumed the crumble window";return false
		if world.player.is_on_floor() and world.player.state!=Player.State.EXIT_WATER and absf(local_player().y-130)<2:break
	release();await frames(dwell)

	if not world.player.is_on_floor() or world.player.swimming() or absf(local_player().y-130)>2:
		failure="first dry stone landing missed";return false
	stone_contacts.append({"stone":"lower","age":stone._timer})
	return true

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
		if deaths:failure="death during swim turn";return false
		if local_player().distance_to(target)<3 and absf(world.player.velocity.y)<20:
			release();return true
	release();failure="swim turn did not settle";return false
