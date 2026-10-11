extends "res://tests/prison_navigation_test.gd"
## Earned intro route; real inputs, no position or puzzle-state grants.
const OUT="res://output/prison_precision/library_intro"
var contacts: Array=[]
var dwell:=6
var mode:="route"
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	if "--backtrack" in OS.get_cmdline_user_args():mode="backtrack"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hold="):
			dwell=int(arg.trim_prefix("--hold="));mode="hold_%d" % dwell
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_G01"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed=PackedScene.new();packed.pack(actor);actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func():deaths+=1)
	await frames(20)
	await run_route()
	if mode=="backtrack" and failure=="":
		if await cross("Prison_G01"):await reverse_route()
	release()
	var result={"failure":failure,"deaths":deaths,"forbidden":forbidden,"contacts":contacts,"room":str(world.current_room.name),"trace":trace}
	FileAccess.open(OUT+"/"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PRECISION G01: ",JSON.stringify(result))
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)
func capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+label+".png")
func run_route() -> void:
	await capture("01_observe")
	if not await navigate(Vector2(104,130)):return
	for point in [Vector2(160,106),Vector2(208,82),Vector2(248,58)]:
		if not await reach(point,true):return
		await capture("landing_%d" % int(point.x))
	if not world.circuits.solved("library_reading"):
		failure="reading seals incomplete";return
	release();Input.action_press("jump");await frames(12)
	Input.action_press("move_up");Input.action_press("dash");await frames(10)
	release();await frames(45)
	if str(world.current_room.name)!="Prison_G02":
		if not await cross("Prison_G02"):return
	await capture("exit")
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
			release();await frames(dwell)
			for stone in world.current_room.get_node("Entities").get_children():
				if stone is CrumblingPlatform and absf(stone.position.x-target.x)<1:
					contacts.append({"stone":str(stone.position),"age":stone._timer,"at":str(local_player())})
			return true
	release();failure="return landing missed "+str(target)+" at "+str(local_player());return false

func reverse_route() -> void:
	# Drop off the upper entrance lip to the permanent seal bank.
	Input.action_press("move_right")
	for frame in 80:
		await frames(1)
		if local_player().x>=280:break
	release();await frames(40)
	if not await navigate(Vector2(248,58)):return
	for point in [Vector2(208,82),Vector2(160,106),Vector2(104,130)]:
		if not await reach(point,false,false):return
	if not await cross("Prison_Hub"):return
	await capture("reverse_hub")
