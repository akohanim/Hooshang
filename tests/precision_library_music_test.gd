extends "res://tests/prison_navigation_test.gd"
## Earned capstone/key route; real inputs, no position or puzzle-state grants.
const OUT="res://output/prison_precision/library_music"
var contacts: Array = []
var mode := "route"
var expected_deaths := 0
var late_verified := false
var departure_frames := 6
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	if "--late" in OS.get_cmdline_user_args():mode="late_retry";expected_deaths=1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hold="):
			departure_frames=int(arg.trim_prefix("--hold="));mode="hold_%d" % departure_frames
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_G03"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed=PackedScene.new();packed.pack(actor);actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func():deaths+=1)
	await frames(20)
	await run_route()
	release()
	var result={"mode":mode,"failure":failure,"deaths":deaths,"expected_deaths":expected_deaths,"forbidden":forbidden,"contacts":contacts,"room":str(world.current_room.name),"trace":trace}
	FileAccess.open(OUT+"/"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("LIBRARY MUSIC: ",JSON.stringify(result))
	await shutdown(0 if failure=="" and deaths==expected_deaths and not forbidden else 1)
func capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+mode+"_"+label+".png")
func run_route() -> void:
	var route_deaths:=deaths
	await capture("01_start")
	if not await navigate(Vector2(56,98)):return
	for index in range(1,6):
		var pad=world.props.filter(func(p):return p.kind=="MusicalTile" and p.get_parent().get_parent()==world.current_room and p.note_index==index)[0]
		release();Input.action_press("jump")
		for frame in 30:
			await frames(1)
			if world.circuits.touched("library_archive",pad.entity_iid):break
		Input.action_release("jump")
		if not note_hit(index):return
		if index==5:
			await frames(20);break
		# Let the head clear the next pad's underside before the lateral dash.
		for frame in 30:
			if local_player().y>=94 and world.player.velocity.y>=0:break
			await frames(1)
		if index in [2,3,4]:
			var departing=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform and absf(p.position.x-(56+56*(index-1)))<1)[0]
			contacts[-1]["dash_age"]=departing._timer
		var target: float=56+56*index
		Input.action_press("move_right");Input.action_press("dash")
		var landed=false
		for frame in 100:
			if frame==12:Input.action_release("dash")
			if frame>=12:
				Input.action_release("move_right");Input.action_release("move_left")
				var aim: float=target-local_player().x-world.player.velocity.x*.10
				Input.action_press("move_left" if aim<0 else "move_right")
			await frames(1)
			if deaths>route_deaths:break
			if world.player.is_on_floor() and absf(local_player().x-target)<7 and absf(local_player().y-98)<2:
				landed=true;break
		release()
		if not landed:
			failure="melody landing missed: "+str(index+1)+" at "+str(local_player());return
		if index==1 and mode=="late_retry" and not late_verified:
			await frames(160)
			var stones=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform)
			if deaths!=1 or local_player().distance_to(Vector2(32,98))>3 or stones.any(func(p):return p._spent or p._falling):
				failure="late landing failed to restore a safe checkpoint and all stones"
			await capture("late_respawn")
			if failure=="":
				late_verified=true
				navigation_deaths_allowed=1
				await run_route()
			return
		var stones=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform and absf(p.position.x-target)<1)
		await frames(departure_frames)
		if not stones.is_empty():contacts.append({"note":index+1,"age":stones[0]._timer,"at":str(local_player())})
		await capture("note_%d_landing" % (index+1))
	if not world.circuits.solved("library_archive"):
		failure="five notes did not open the key roof";return
	await capture("gate_open")
	# Step off the permanent lip, then off the lower return step into the key.
	Input.action_press("move_right")
	for frame in 60:
		await frames(1)
		if local_player().x>=304:break
	release();await frames(40)
	if not await navigate(Vector2(288,154)):return
	await frames(10)
	if not world.collected.has("Green"):
		failure="open roof did not give access to Green";return
	await capture("key_collected")
	if not await reach(Vector2(244,170),false,false):return
	Input.action_press("move_right")
	for frame in 120:
		await frames(1)
		if str(world.current_room.name)=="Prison_G04":break
	release();await frames(40)
	if str(world.current_room.name)!="Prison_G04":failure="key return did not reach G04"
	await capture("shortcut_entry")

func note_hit(index: int) -> bool:
	var pad=world.props.filter(func(p):return p.kind=="MusicalTile" and p.get_parent().get_parent()==world.current_room and p.note_index==index)[0]
	if not world.circuits.touched("library_archive",pad.entity_iid):
		failure="note "+str(index)+" was not earned in order";return false
	return true

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
		if deaths>expected_deaths:break
		if world.player.is_on_floor() and absf(local_player().y-target.y)<2 and absf(local_player().x-target.x)<=7:
			release();await frames(6);return true
	release();failure="return landing missed "+str(target)+" at "+str(local_player());return false

func reverse_route() -> void:
	# Entered via the preserved partial catch ledge, with all stones reset.
	var stones=world.current_room.get_node("Entities").get_children().filter(func(p):return p is CrumblingPlatform)
	if stones.any(func(p):return p._spent or p._falling):
		failure="reentry left melody stones spent";return
	if not await reach(Vector2(304,154),true):return
	if not await reach(Vector2(304,138),false,false):return
	if not await reach(Vector2(280,98),true):return
	for x in [224,168,112,56]:
		if not await reach(Vector2(x,98),false):return
	await capture("reverse_bank")
	if not await navigate(Vector2(16,98)):return
	release();Input.action_press("jump");await frames(12)
	Input.action_press("move_up");Input.action_press("dash");await frames(10)
	release();await frames(45)
	if not await cross("Prison_G02"):return
	await capture("reverse_exit")
