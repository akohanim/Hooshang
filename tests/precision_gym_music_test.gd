extends "res://tests/prison_navigation_test.gd"
## Real child input route. No injected positions, keys or mechanism state.
const OUT := "res://output/prison_precision/gym_music"
var capture_root:=OUT
var dwell:=6
var elapsed:=0.0
var timer_at_finish:=0.0
var full_loop:=false
var approach_done:=false
var beam_threshold:=66.0
var late_mode:=false
var late_verified:=false
var wrong_mode:=false
var wrong_verified:=false
var skip_stone_probe:=false
var probe_verified:=false
var probe_observation:=""
func _ready() -> void:
	if not run_on_ready:return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--beam="):beam_threshold=float(arg.trim_prefix("--beam="))
		if arg.begins_with("--hold="):dwell=int(arg.trim_prefix("--hold="))
	full_loop="--full" in OS.get_cmdline_user_args()
	late_mode="--late" in OS.get_cmdline_user_args()
	wrong_mode="--wrong-note" in OS.get_cmdline_user_args()
	skip_stone_probe="--skip-stone" in OS.get_cmdline_user_args()
	if late_mode:beam_threshold=74
	SaveGame.unbind()
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_Hub" if full_loop else "Prison_Y03"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed:=PackedScene.new()
	packed.pack(actor)
	actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func():deaths+=1)
	world.timers.changed.connect(func():
		if not world.timers.solved("gym_reverse"):timer_at_finish=world.timers.remaining("gym_reverse"))
	await frames(20)
	await run_route()
	release()
	var result:={"failure":failure,"deaths":deaths,"forbidden":forbidden,"wall_jump":saw_wall_jump,"room":str(world.current_room.name),"completed":world.timers.save_completed(),"trace":trace,"dwell_frames":dwell,"elapsed":elapsed,"late_verified":late_verified,"wrong_verified":wrong_verified,"probe_only":skip_stone_probe,"probe_verified":probe_verified,"probe_observation":probe_observation,"beam_threshold":beam_threshold,"full_loop":full_loop,"backtrack":"--backtrack" in OS.get_cmdline_user_args(),"music_solved":world.circuits.solved("gym_music"),"keys":world.collected,"timer_at_finish":timer_at_finish}
	FileAccess.open(OUT+("/skip_stone_probe.json" if skip_stone_probe else "/wrong_note.json" if wrong_mode else "/full_late.json" if full_loop and late_mode else "/late.json" if late_mode else "/full_route.json" if full_loop else "/beam_%d.json" % int(beam_threshold) if beam_threshold!=66 else "/hold_%d.json" % dwell),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("GYM MUSIC INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"wall_jump":saw_wall_jump}))
	await shutdown(0 if failure=="" and deaths==navigation_deaths_allowed and not forbidden and (not late_mode or late_verified) and (not wrong_mode or wrong_verified) and (not skip_stone_probe or probe_verified) else 1)
func run_route() -> void:
	if full_loop and not approach_done:
		if not await approach():return
		approach_done=true
	if local_player().x>208 and local_player().y<40:
		if not await arrival_to_start():return
	await capture("01_start")
	if not await navigate(Vector2(128,154)):return
	var first=world.props.filter(func(p):return p.kind=="MusicalTile" and p.get_parent().get_parent()==world.current_room and p.note_index==1)[0]
	if not world.circuits.touched("gym_music",first.entity_iid):
		release();Input.action_press("jump");await frames(8);release();await frames(20)
	if not note_hit(1):return
	if not await navigate(Vector2(172,154)):return
	for at in [Vector2(196,98)]:
		if not await gym_go(world.current_room.global_position+at,false):
			failure="wall-jump ascent missed";return
	await frames(6)
	await capture("02_wall_jump")
	if not await move_to(Vector2(232,114),"Prison_Y03"):return
	if not world.timers.solved("gym_ascent"):
		failure="ascent seal not banked";return
	if not await navigate(Vector2(264,114)):return
	release();Input.action_press("jump");await frames(15);release();await frames(20)
	if not note_hit(2):return
	await capture("03_note_two")
	if wrong_mode and not wrong_verified:
		release();Input.action_press("jump");await frames(15);release();await frames(20)
		var pads=world.props.filter(func(p):return p.kind=="MusicalTile" and p.get_parent().get_parent()==world.current_room)
		if pads.any(func(p):return world.circuits.touched("gym_music",p.entity_iid)) or world.collected.has("Gold"):
			failure="repeated note did not reset the unfinished melody";return
		wrong_verified=true;await capture("wrong_note_reset")
		if not await descend_to_start():return
		await run_route();return
	if not await navigate(Vector2(256,114)):return
	await capture("04_midpoint")
	var started:=ticks
	if not await move_to(Vector2(280,114),"Prison_Y03"):return
	if not await reach(Vector2(296,90),true):return
	if not note_hit(3):return
	if skip_stone_probe:
		var bypass: bool=await reach(Vector2(200,42),true)
		probe_observation=failure
		if bypass:
			failure="direct jump/dash skipped the first upper stone";return
		if deaths or world.circuits.solved("gym_music") or not world.player.is_on_floor():return
		failure="";probe_verified=true;await capture("direct_skip_blocked");return
	if not await reach(Vector2(248,50),true):return
	await capture("05_stone")
	if not await beam_transfer():
		if not late_mode or late_verified or deaths!=0:return
		if world.circuits.solved("gym_music") or not world.timers.solved("gym_ascent"):
			failure="late transfer did not leave the expected unfinished phrase";return
		release()
		var event:=InputEventAction.new()
		event.action="respawn";event.pressed=true;Input.parse_input_event(event)
		await frames(1)
		event=InputEventAction.new();event.action="respawn";event.pressed=false;Input.parse_input_event(event)
		await frames(100)
		var stones=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform)
		if deaths!=1 or not world.player.is_on_floor() or stones.any(func(p):return p._spent) or not world.timers.solved("gym_ascent"):
			failure="late retry did not restore safe footing, stones and banked ascent";return
		failure="";late_verified=true;navigation_deaths_allowed=1;trial_deaths=1;beam_threshold=66
		await capture("late_checkpoint")
		await run_route();return
	if not note_hit(4):return
	await capture("06_note_four")
	if not await reach(Vector2(152,50),false,true):return
	if not await reach(Vector2(104,34),true):return
	if not note_hit(5):return
	elapsed=(ticks-started)/60.0
	await capture("07_melody")
	if not world.circuits.solved("gym_music"):
		failure="five-note melody not solved";return
	if not await move_to(Vector2(88,58),"Prison_Y03"):return
	await frames(8)
	if not world.timers.solved("gym_reverse"):
		failure="upper seal not banked";return
	await capture("08_key_open")
	if not await navigate(Vector2(64,154)):return
	await frames(8)
	if not world.collected.has("Gold"):
		failure="Gold not collected";return
	await capture("09_key")
	if not await cross("Prison_Y04"):return
	if not await cross("Prison_Hub"):return
	await capture("10_hub")
	if "--backtrack" in OS.get_cmdline_user_args():await return_loop()

func note_hit(index: int) -> bool:
	var pad=world.props.filter(func(p):return p.kind=="MusicalTile" and p.get_parent().get_parent()==world.current_room and p.note_index==index)[0]
	if not world.circuits.touched("gym_music",pad.entity_iid):
		failure="note %d was not earned in order" % index;return false
	return true

func beam_transfer() -> bool:
	release();Input.action_press("move_left")
	for frame in 100:
		await frames(1)
		if deaths>navigation_deaths_allowed:failure="beam fall death";return false
		if local_player().y>=beam_threshold:break
	if local_player().y<beam_threshold:failure="stone did not give way at beam";return false
	Input.action_press("move_up");Input.action_press("dash")
	for frame in 100:
		if frame==10:Input.action_release("move_up");Input.action_release("dash")
		if frame>=10:
			Input.action_release("move_left");Input.action_release("move_right")
			var aim: float=200-local_player().x-world.player.velocity.x*.10
			Input.action_press("move_left" if aim<0 else "move_right")
		await frames(1)
		if world.player.is_on_floor() and absf(local_player().y-42)<2 and absf(local_player().x-200)<5:
			release();await frames(dwell);return true
	release();failure="beam recovery missed note4 at "+str(local_player());return false

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(capture_root+"/"+("full_" if full_loop else "")+("late_" if late_mode else "wrong_" if wrong_mode else "")+label+".png")

func reach(target: Vector2, diagonal: bool, low := false) -> bool:
	var origin_room=world.current_room
	release();Input.action_press("jump")
	for i in 180:
		Input.action_release("move_left");Input.action_release("move_right")
		var aim: float=target.x-local_player().x-world.player.velocity.x*0.10
		Input.action_press("move_left" if aim<0 else "move_right")
		if low and i==4:Input.action_release("jump")
		if i==(8 if low else 12):
			if diagonal:Input.action_press("move_up")
			Input.action_press("dash")
		if i==(18 if low else 22):Input.action_release("move_up");Input.action_release("dash")
		if i==24:Input.action_release("jump")
		await frames(1)
		if world.current_room!=origin_room:
			release();await frames(50);return true
		if deaths>navigation_deaths_allowed:break
		if world.player.is_on_floor() and absf(local_player().y-target.y)<2 and absf(local_player().x-target.x)<=7:
			release();await frames(dwell);return true
	release();failure="landing missed "+str(target)+" at "+str(local_player());return false

func arrival_to_start() -> bool:
	geo=world.current_room.get_node("PrisonGeometry")
	if not await move_to(Vector2(280,114),"Prison_Y03"):return false
	Input.action_press("move_up");await frames(4);release()
	return await descend_to_start()

func descend_to_start() -> bool:
	if not await navigate(Vector2(232,114)):return false
	if not await navigate(Vector2(196,98)):return false
	if not await move_to(Vector2(176,154),"Prison_Y03"):return false
	if not await navigate(Vector2(112,154)):return false
	await capture("entry_to_start")
	return true

func return_loop() -> void:
	if not await cross("Prison_Y04"):return
	if not await cross("Prison_Y03"):return
	if not await navigate(Vector2(172,154)):return
	for at in [Vector2(196,98)]:
		if not await gym_go(world.current_room.global_position+at,false):
			failure="return wall ascent failed";return
	if not await move_to(Vector2(256,114),"Prison_Y03"):return
	if not await move_to(Vector2(280,114),"Prison_Y03"):return
	if not await reach(Vector2(296,90),true):return
	if not await reach(Vector2(248,50),true):return
	release();Input.action_press("jump");await frames(12)
	Input.action_press("move_up");Input.action_press("dash");await frames(10)
	release();await frames(70)
	if str(world.current_room.name)=="Prison_Y03":
		if not world.player.is_on_floor() or absf(local_player().y-18)>2:
			failure="return did not reach the upper entrance bank";return
		if not await cross("Prison_Y02"):return
	elif str(world.current_room.name)!="Prison_Y02":
		failure="unexpected room after upper return";return
	if not await balcony_route(true):return
	if not await cross("Prison_Y01"):return
	if not await navigate(Vector2(48,154)):return
	if not await cross("Prison_Hub"):return
	await capture("11_backtrack_hub")

func approach() -> bool:
	if not await cross("Prison_Y01"):return false
	if not await navigate(Vector2(96,154)):return false
	if not await navigate(Vector2(172,154)):return false
	for at in [Vector2(176,114),Vector2(196,98)]:
		if not await gym_go(world.current_room.global_position+at,false):failure="Y01 ascent";return false
	if not await navigate(Vector2(288,154)):return false
	if not world.timers.solved("gym_plate_intro"):failure="Y01 seal";return false
	if not await cross("Prison_Y02"):return false
	return await balcony_route(false)

func balcony_route(reverse: bool) -> bool:
	var route=load("res://tests/precision_gym_balcony_test.gd").new()
	route.run_on_ready=false;route.return_to_entrance=false
	add_child(route);route.world=world
	var on_death=func():route.deaths+=1
	world.player.died.connect(on_death)
	if reverse:await route.return_route()
	else:await route.run_route()
	route.release();failure=route.failure
	forbidden=forbidden or route.forbidden
	trace.append_array(route.trace)
	world.player.died.disconnect(on_death);route.queue_free()
	return failure==""
