extends "res://tests/prison_navigation_test.gd"
## Input-driven shared-timer encounter; no progress or position injection.
const OUT := "res://output/prison_challenge/cafeteria_development"
var activation_tick := 0
var bank_tick := -1
var phase_delay := 0
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
	Screen.set_scene(world)
	world.player.died.connect(func(): deaths+=1)
	world.timers.changed.connect(func():
		if world!=null and bank_tick<0 and world.timers.solved("cafeteria_serving"): bank_tick=ticks)
	skip_patrol_wait=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delay="): phase_delay=int(arg.trim_prefix("--delay="))
	await frames(20+phase_delay)
	await run_route()
	release()
	var result:={"failure":failure,"deaths":deaths,"forbidden":forbidden,"room":str(world.current_room.name),"bank_seconds":(bank_tick-activation_tick)/60.0 if bank_tick>=0 else -1.0,"phase_delay":phase_delay,"completed":world.timers.save_completed(),"trace":trace}
	FileAccess.open(OUT+("/route.json" if phase_delay==0 else "/route_delay%d.json" % phase_delay),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SERVING LINE INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"bank_seconds":result.bank_seconds}))
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)
func run_route() -> void:
	await capture("01_closed")
	activation_tick=ticks
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	for prop in world.props:
		if prop.get_parent().get_parent()!=world.current_room:continue
		if prop.kind in ["TimedGate","TimedShutter"]:
			if prop.barrier.disabled==bool(prop.fields.get("RequireBank",false)):
				failure="shared shutters/exit seal opened incorrectly: "+prop.kind+" active="+str(world.timers.active("cafeteria_serving"));return
	if not await navigate(Vector2(224,154)):return
	var patrol=world.props.filter(func(p): return p.kind=="Patrol" and p.get_parent().get_parent()==world.current_room and p.origin.x==200)[0]
	for i in 200:
		var angle: float=patrol.clock*2.0*float(patrol.fields.get("Speed",1.0))+float(patrol.fields.get("Phase",0.0))
		if sin(angle)<-0.75 and cos(angle)<0:break
		await frames(1)
	if not await navigate(Vector2(200,138)):return
	if not await navigate(Vector2(168,114)):return
	await capture("02_counter")
	Input.action_press("move_left")
	Input.action_press("dash")
	await frames(10)
	Input.action_release("dash")
	await frames(22)
	release()
	await frames(15)
	if deaths>0:failure="serving dash died";return
	if not await navigate(Vector2(64,130)):return
	await frames(5)
	if not world.timers.solved("cafeteria_serving"):
		failure="completion seal missed deadline";return
	await capture("03_banked")
	if not await cross("Prison_R03"):return
	await capture("04_next_room")
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+("" if phase_delay==0 else "delay%d_" % phase_delay)+label+".png")
