extends "res://tests/prison_navigation_test.gd"
## Input-driven two-phrase capstone; no progress or position injection.
const OUT := "res://output/prison_challenge/cafeteria_capstone"
var activation_tick := 0
var bank_tick := -1
var phase_delay := 0
var full_loop := false
var starts: Dictionary = {}
var durations: Dictionary = {}
var capture_root := OUT
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	world=load("res://ldtk/Act2World.tscn").instantiate()
	full_loop = "--full" in OS.get_cmdline_user_args()
	world.debug_start_room="Prison_Hub" if full_loop else "Prison_R03"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed:=PackedScene.new()
	packed.pack(actor)
	actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func(): deaths+=1)
	world.timers.changed.connect(func():
		if world!=null and bank_tick<0 and world.timers.solved("cafeteria_pantry_upper"): bank_tick=ticks)
	world.timers.attempt_started.connect(func(id): starts[id]=ticks)
	world.timers.changed.connect(func():
		if world==null:return
		for id in starts:
			if world.timers.solved(id) and not durations.has(id): durations[id]=(ticks-int(starts[id]))/60.0)
	skip_patrol_wait=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delay="): phase_delay=int(arg.trim_prefix("--delay="))
	await frames(20+phase_delay)
	await run_route()
	release()
	var result:={"failure":failure,"deaths":deaths,"forbidden":forbidden,"room":str(world.current_room.name),"bank_seconds":(bank_tick-activation_tick)/60.0 if bank_tick>=0 else -1.0,"phase_delay":phase_delay,"full_loop":full_loop,"backtrack": "--backtrack" in OS.get_cmdline_user_args(),"phrase_seconds":durations,"completed":world.timers.save_completed(),"trace":trace}
	FileAccess.open(OUT+("/full_route.json" if full_loop else "/route.json" if phase_delay==0 else "/route_delay%d.json" % phase_delay),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PANTRY INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"bank_seconds":result.bank_seconds}))
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)
func run_route() -> void:
	if full_loop:
		if not await approach():return
		if not await navigate(Vector2(40,154)):return
	await capture("01_closed")
	activation_tick=ticks
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	Input.action_press("jump")
	await frames(35)
	Input.action_release("jump")
	await frames(8)
	if not await navigate(Vector2(60,130)):return
	# The crumble prop is deliberately not a permanent graph support.
	if not await move_to(Vector2(108,130),"Prison_R03"):return
	var shelf=world.props.filter(func(p): return p.kind=="CrumblingShelf" and p.get_parent().get_parent()==world.current_room)[0]
	if not shelf._spent:failure="service shelf was not traversed";return
	await capture("02_shelf")
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(18)
	Input.action_release("jump")
	Input.action_press("dash")
	await frames(10)
	Input.action_release("dash")
	for i in 60:
		if local_player().x>=172:break
		await frames(1)
	release()
	await frames(15)
	if not await navigate(Vector2(168,114)):return
	if not world.timers.solved("cafeteria_pantry_shelf"):failure="midpoint seal not banked";return
	await capture("03_midpoint")
	if not await navigate(Vector2(200,114)):return
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	if not await navigate(Vector2(204,90)):return
	var patrol=world.props.filter(func(p):return p.kind=="Patrol" and p.get_parent().get_parent()==world.current_room)[0]
	for i in 200:
		var angle: float=patrol.clock*2.0*float(patrol.fields.get("Speed",1.0))+float(patrol.fields.get("Phase",0.0))
		if sin(angle)<-0.75 and cos(angle)<0:break
		await frames(1)
	Input.action_press("move_right")
	Input.action_press("dash")
	await frames(10)
	Input.action_release("dash")
	await frames(14)
	release()
	await frames(16)
	if not await navigate(Vector2(280,106)):return
	if not world.timers.solved("cafeteria_pantry_upper"):failure="upper seal not banked";return
	await capture("04_upper")
	if not await navigate(Vector2(304,138)):return
	if not await navigate(Vector2(288,154)):return
	await frames(8)
	if not world.collected.has("Red"):failure="Red key not collected";return
	await capture("05_key")
	if not await cross("Prison_R04"):return
	if not await cross("Prison_Hub"):return
	await capture("06_hub")
	if "--backtrack" in OS.get_cmdline_user_args():await return_loop()
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(capture_root+"/"+("full_" if full_loop else "" if phase_delay==0 else "delay%d_" % phase_delay)+label+".png")

func approach() -> bool:
	if not await cross("Prison_R01"):return false
	if not await navigate(Vector2(264,154)):return false
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	skip_patrol_wait=false
	if not await navigate(Vector2(64,154)):return false
	if not world.timers.solved("cafeteria_intro"):failure="R01 not banked";return false
	if not await cross("Prison_R02"):return false
	skip_patrol_wait=true
	if not await navigate(Vector2(288,154)):return false
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	if not await navigate(Vector2(224,154)):return false
	var patrol=world.props.filter(func(p): return p.kind=="Patrol" and p.get_parent().get_parent()==world.current_room and p.origin.x==200)[0]
	for i in 200:
		var angle: float=patrol.clock*2.0*float(patrol.fields.get("Speed",1.0))+float(patrol.fields.get("Phase",0.0))
		if sin(angle)<-0.75 and cos(angle)<0:break
		await frames(1)
	if not await navigate(Vector2(200,138)):return false
	if not await navigate(Vector2(168,114)):return false
	Input.action_press("move_left")
	Input.action_press("dash")
	await frames(10)
	Input.action_release("dash")
	await frames(22)
	release()
	await frames(15)
	if not await navigate(Vector2(64,130)):return false
	if not world.timers.solved("cafeteria_serving"):failure="R02 not banked";return false
	return await cross("Prison_R03")

func return_loop() -> void:
	if not await cross("Prison_R04"):return
	if not await cross("Prison_R03"):return
	if not await navigate(Vector2(304,138)):return
	if not await move_to(Vector2(288,106),"Prison_R03"):return
	var patrol=world.props.filter(func(p):return p.kind=="Patrol" and p.get_parent().get_parent()==world.current_room)[0]
	for i in 200:
		var angle: float=patrol.clock*2.0+float(patrol.fields.get("Phase",0.0))
		if sin(angle)<-0.75 and cos(angle)<0:break
		await frames(1)
	Input.action_press("move_left")
	Input.action_press("dash")
	await frames(10)
	Input.action_release("dash")
	await frames(28)
	release()
	await frames(15)
	if not await navigate(Vector2(176,114)):return
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	Input.action_press("move_left")
	Input.action_press("dash")
	await frames(10)
	Input.action_release("dash")
	for i in 60:
		if local_player().x<=108:break
		await frames(1)
	release()
	await frames(12)
	if not await move_to(Vector2(56,130),"Prison_R03"):return
	if not await move_to(Vector2(48,98),"Prison_R03"):return
	if not await move_to(Vector2(64,66),"Prison_R03"):return
	if not await navigate(Vector2(96,42)):return
	if not await cross("Prison_R02"):return
	if not await navigate(Vector2(112,130)):return
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
	skip_patrol_wait=false
	if not await navigate(Vector2(288,154)):return
	if not await cross("Prison_R01"):return
	if not await cross("Prison_Hub"):return
	await capture("07_backtrack_hub")
