extends "res://tests/prison_navigation_test.gd"
## Real child input route. No injected positions, keys or mechanism state.
const OUT := "res://output/prison_precision/gym_balcony"
var dwell:=6
var elapsed:=0.0
var late_mode:=false
var bypass_mode:=false
var bypass_verified:=false
var retry_verified:=false
var timer_at_finish:=0.0
var return_to_entrance:=true
func _ready() -> void:
	if not run_on_ready:return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hold="):dwell=int(arg.trim_prefix("--hold="))
	late_mode="--late" in OS.get_cmdline_user_args()
	bypass_mode="--bypass" in OS.get_cmdline_user_args()
	SaveGame.unbind()
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_Y02"
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
	var result:={"failure":failure,"deaths":deaths,"forbidden":forbidden,"wall_jump":saw_wall_jump,"room":str(world.current_room.name),"completed":world.timers.save_completed(),"trace":trace,"dwell_frames":dwell,"elapsed":elapsed,"retry_verified":retry_verified,"bypass_verified":bypass_verified,"timer_at_finish":timer_at_finish}
	FileAccess.open(OUT+("/bypass.json" if bypass_mode else "/late.json" if late_mode else "/hold_%d.json" % dwell),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("GYM PRECISION BALCONY INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"wall_jump":saw_wall_jump}))
	await shutdown(0 if failure=="" and deaths==navigation_deaths_allowed and not forbidden and (not late_mode or retry_verified) and (not bypass_mode or bypass_verified) else 1)
func run_route() -> void:
	await capture("01_plate")
	if not await navigate(Vector2(108,154)):return
	if bypass_mode and not bypass_verified:
		if await reach(Vector2(232,122),true):
			failure="single jump/dash bypass reached the second stone";return
		release();await frames(100)
		if deaths!=1 or not world.player.is_on_floor() or local_player().distance_to(Vector2(48,154))>3 or world.timers.solved("gym_balcony"):
			failure="bypass probe did not fail into a safe retry";return
		failure="";navigation_deaths_allowed=1;bypass_verified=true
		await run_route();return
	var started:=ticks
	if not await reach(Vector2(184,146),false):return
	await capture("02_first_stone")
	if late_mode and not retry_verified:
		release();await frames(120)
		var stones=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform)
		if deaths!=1 or not world.player.is_on_floor() or local_player().distance_to(Vector2(48,154))>3 or stones.any(func(p):return p._spent):
			failure="collapse did not restore the plate checkpoint and stones";return
		navigation_deaths_allowed=1;retry_verified=true
		await capture("late_retry")
		await run_route();return
	if not await reach(Vector2(232,122),true):return
	await capture("03_second_stone")
	if not await reach(Vector2(296,154),false,true):return
	if not await navigate(Vector2(288,154)):return
	if not world.timers.solved("gym_balcony"):
		failure="far seal did not bank the sequence";return
	elapsed=(ticks-started)/60.0
	await capture("04_banked")
	if not await cross("Prison_Y03"):return
	await capture("05_next_room")
	if return_to_entrance:
		if not await cross("Prison_Y02"):return
		await return_route()

func return_route() -> void:
	if not await reach(Vector2(296,154),false):return
	if not await reach(Vector2(232,122),true):return
	if not await reach(Vector2(184,146),false,true):return
	if not await reach(Vector2(104,154),true):return
	if not await navigate(Vector2(48,154)):return
	await capture("06_return")

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+label+".png")

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
		if not world.timers.solved("gym_balcony"):timer_at_finish=world.timers.remaining("gym_balcony")
		if world.current_room!=origin_room:
			release();await frames(50);return true
		if deaths>navigation_deaths_allowed:break
		if world.player.is_on_floor() and absf(local_player().y-target.y)<2 and absf(local_player().x-target.x)<=7:
			release();await frames(dwell);return true
	release();failure="landing missed "+str(target)+" at "+str(local_player());return false
