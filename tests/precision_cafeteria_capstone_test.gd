extends "res://tests/prison_navigation_test.gd"
## Earned capstone/key route; real inputs, no position or puzzle-state grants.
const OUT="res://output/prison_precision/cafeteria_precision_capstone"
var shelf_age := -1.0
var contacts: Array = []
var mode := "route"
var expected_deaths := 0
var started := 0
var bank_seconds := -1.0
var second_seconds := -1.0
var departure_frames := 6
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	if "--bypass" in OS.get_cmdline_user_args():mode="bypass_probe"
	if "--late" in OS.get_cmdline_user_args():mode="late_retry";expected_deaths=1
	if "--backtrack" in OS.get_cmdline_user_args():mode="backtrack"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hold="):
			departure_frames=int(arg.trim_prefix("--hold="));mode="hold_%d" % departure_frames
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_R03"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed=PackedScene.new();packed.pack(actor);actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func():deaths+=1)
	await frames(20)
	await run_route()
	release()
	var result={"mode":mode,"failure":failure,"deaths":deaths,"expected_deaths":expected_deaths,"forbidden":forbidden,"bank_seconds":bank_seconds,"second_seconds":second_seconds,"contacts":contacts,"room":str(world.current_room.name),"trace":trace}
	FileAccess.open(OUT+"/"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PRECISION R03: ",JSON.stringify(result))
	await shutdown(0 if failure=="" and deaths==expected_deaths and not forbidden else 1)
func capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+mode+"_"+label+".png")
func land(shelf: Node, diagonal: bool, flat := false) -> bool:
	release()
	Input.action_press("jump")
	var target: float=shelf.position.x
	var arrived=false
	var dash_frame := 16 if flat else 12
	for i in 180:
		Input.action_release("move_left");Input.action_release("move_right")
		var aim: float=target-local_player().x-world.player.velocity.x*0.10
		Input.action_press("move_left" if aim<0 else "move_right")
		if (diagonal or flat) and i==dash_frame:
			if diagonal:Input.action_press("move_up")
			Input.action_press("dash")
		if i==dash_frame+10:
			Input.action_release("move_up");Input.action_release("dash")
		if i==24:Input.action_release("jump")
		await frames(1)
		if deaths:break
		if shelf._spent and world.player.is_on_floor() and absf(local_player().y-(shelf.position.y-10))<2 and absf(local_player().x-target)<=7:
			arrived=true;break
	release()
	if not arrived or shelf._falling:
		failure="temporary landing missed at "+str(shelf.position)+" actor="+str(local_player());return false
	await frames(departure_frames)
	contacts.append({"shelf":str(shelf.position),"age":shelf._timer,"at":str(local_player())})
	await capture("landing_%d" % contacts.size())
	return true
func run_route() -> void:
	if local_player().y<140:
		Input.action_press("move_left")
		for i in 240:
			if local_player().x<28:break
			await frames(1)
		release();await frames(80)
		if not await navigate(Vector2(40,154)):return
	await capture("01_observe")
	started=ticks
	Input.action_press("move_up");await frames(3);Input.action_release("move_up")
	if not await navigate(Vector2(28,154)):return
	var shelves=world.props.filter(func(p):return p.kind=="CrumblingShelf" and p.get_parent().get_parent()==world.current_room)
	var first=shelves.filter(func(p):return p.position.x<152)
	first.sort_custom(func(a,b):return a.position.y>b.position.y)
	for i in first.size():
		if not await land(first[i],i>0):return
	Input.action_press("move_right");Input.action_press("dash")
	await frames(10);Input.action_release("dash")
	for i in 90:
		if local_player().x>180 or deaths:break
		await frames(1)
	release();await frames(12)
	if not await navigate(Vector2(168,114)):return
	if not world.timers.solved("cafeteria_pantry_shelf"):failure="first seal not banked";return
	bank_seconds=(ticks-started)/60.0
	await capture("06_midpoint")
	if not await navigate(Vector2(200,114)):return
	Input.action_press("move_up");await frames(3);Input.action_release("move_up")
	var second_started := ticks
	var second=shelves.filter(func(p):return p.position.x>216)
	second.sort_custom(func(a,b):return a.position.y>b.position.y)
	var indices: Array=[2] if mode=="bypass_probe" else [0,1,2]
	for i in indices:
		if not await land(second[i],true):return
		if mode=="late_retry" and i==0:
			await frames(150)
			if deaths!=1 or local_player().distance_to(Vector2(40,154))>3:failure="late second phrase did not respawn safely"
			if not world.timers.solved("cafeteria_pantry_shelf"):failure="death lost first bank"
			if world.timers.active("cafeteria_pantry_upper") or world.timers.solved("cafeteria_pantry_upper"):failure="death retained unfinished second phrase"
			for shelf in shelves:
				if shelf._spent or not shelf.get_collision_layer_value(1):failure="death did not restore stones"
			await capture("restored_midpoint_progress")
			return
	second_seconds=(ticks-second_started)/60.0
	await capture("10_upper")
	Input.action_press("move_right")
	for i in 90:
		if local_player().y>=40 or deaths:break
		await frames(1)
	Input.action_press("dash");await frames(10);Input.action_release("dash")
	for i in 90:
		if local_player().x>=302 or deaths:break
		await frames(1)
	release();await frames(30)
	if not world.timers.solved("cafeteria_pantry_upper"):failure="second seal not banked";return
	await capture("11_second_bank")
	if not await navigate(Vector2(304,138)):return
	if not await navigate(Vector2(288,154)):return
	await frames(8)
	if not world.collected.has("Red"):failure="Red key not collected";return
	await capture("12_key")
	if not await cross("Prison_R04"):return
	if not await cross("Prison_Hub"):return
	await capture("13_hub")
	if mode=="backtrack":await return_route()

func reach(target: Vector2, diagonal: bool) -> bool:
	var origin_room=world.current_room
	release();Input.action_press("jump")
	for i in 180:
		Input.action_release("move_left");Input.action_release("move_right")
		var aim: float=target.x-local_player().x-world.player.velocity.x*0.10
		Input.action_press("move_left" if aim<0 else "move_right")
		if i==12:
			if diagonal:Input.action_press("move_up")
			Input.action_press("dash")
		if i==22:Input.action_release("move_up");Input.action_release("dash")
		if i==24:Input.action_release("jump")
		await frames(1)
		if world.current_room!=origin_room:
			release();await frames(50);return true
		if deaths:break
		if world.player.is_on_floor() and absf(local_player().y-target.y)<2 and absf(local_player().x-target.x)<=7:
			release();await frames(6);return true
	release();failure="return landing missed "+str(target)+" at "+str(local_player());return false

func return_route() -> void:
	if not await cross("Prison_R04"):return
	if not await cross("Prison_R03"):return
	if not await navigate(Vector2(304,138)):return
	var patrol=world.props.filter(func(p):return p.kind=="Patrol" and p.get_parent().get_parent()==world.current_room)[0]
	for i in 240:
		var angle: float=patrol.clock*2.0*float(patrol.fields.get("Speed",1.0))+float(patrol.fields.get("Phase",0.0))
		if sin(angle)<-0.5 and cos(angle)<0:break
		await frames(1)
	skip_patrol_wait=true
	if not await reach(Vector2(288,106),true):return
	Input.action_press("move_up");await frames(3);Input.action_release("move_up")
	var shelves=world.props.filter(func(p):return p.kind=="CrumblingShelf" and p.get_parent().get_parent()==world.current_room)
	if not await navigate(Vector2(244,106)):return
	if not await reach(Vector2(200,114),false):return
	if not await navigate(Vector2(176,114)):return
	Input.action_press("move_up");await frames(3);Input.action_release("move_up")
	for target_x in [104,64,112]:
		var stone=shelves.filter(func(p):return p.position.x==target_x)[0]
		if not await land(stone,true):return
	if not await reach(Vector2(96,18),true):return
	if str(world.current_room.name)!="Prison_R02" and not await cross("Prison_R02"):return
	await capture("14_return_R02")
