extends "res://tests/prison_navigation_test.gd"
## Earned intro route; real inputs, no position or puzzle-state grants.
const OUT="res://output/prison_precision/cafeteria_development"
var shelf_age := -1.0
var contacts: Array = []
var mode := "route"
var expected_deaths := 0
var started := 0
var bank_seconds := -1.0
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	if "--bypass" in OS.get_cmdline_user_args():mode="bypass_probe"
	if "--late" in OS.get_cmdline_user_args():mode="late_retry";expected_deaths=1
	if "--backtrack" in OS.get_cmdline_user_args():mode="backtrack"
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_R02"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed=PackedScene.new();packed.pack(actor);actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func():deaths+=1)
	await frames(20)
	await run_route()
	release()
	var result={"mode":mode,"failure":failure,"deaths":deaths,"expected_deaths":expected_deaths,"forbidden":forbidden,"bank_seconds":bank_seconds,"contacts":contacts,"room":str(world.current_room.name),"trace":trace}
	FileAccess.open(OUT+"/"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PRECISION R02: ",JSON.stringify(result))
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
	await frames(6)
	contacts.append({"shelf":str(shelf.position),"age":shelf._timer,"at":str(local_player())})
	await capture("landing_%d" % contacts.size())
	return true
func run_route() -> void:
	await capture("01_observe")
	started=ticks
	Input.action_press("move_up");await frames(3);Input.action_release("move_up")
	if not await navigate(Vector2(236,154)):return
	# Approach tolerance must not leave the body below the ceiling partition.
	Input.action_press("move_left")
	for i in 30:
		if local_player().x<=236:break
		await frames(1)
	release();await frames(6)
	var shelves=world.props.filter(func(p):return p.kind=="CrumblingShelf" and p.get_parent().get_parent()==world.current_room)
	shelves.sort_custom(func(a,b):return a.position.y>b.position.y)
	var indices: Array=[1,3] if "--bypass" in OS.get_cmdline_user_args() else [0,1,2,3]
	for i in indices:
		if not await land(shelves[i],i>0):return
		if mode=="late_retry" and i==1:
			await frames(150)
			if deaths!=1 or local_player().distance_to(Vector2(288,154))>3:failure="late launch did not respawn safely"
			if world.timers.active("cafeteria_serving") or world.timers.solved("cafeteria_serving"):failure="late launch retained attempt"
			for shelf in shelves:
				if shelf._spent or not shelf.get_collision_layer_value(1):failure="late launch did not restore every shelf"
			await capture("restored_checkpoint")
			return
	# The final launch is a flat dash into the high shutter, then a low landing.
	Input.action_press("move_left");Input.action_press("dash")
	await frames(10);Input.action_release("dash")
	for i in 90:
		if local_player().x<96 or deaths:break
		await frames(1)
	release();await frames(12)
	if not await navigate(Vector2(64,82)):return
	if not world.timers.solved("cafeteria_serving"):failure="seal not banked";return
	bank_seconds=(ticks-started)/60.0
	await capture("06_banked")
	if not await cross("Prison_R03"):return
	await capture("07_exit")
	if mode=="backtrack":await return_route()

func return_route() -> void:
	if str(world.current_room.name)!="Prison_R02" and not await cross("Prison_R02"):return
	if not await navigate(Vector2(96,82)):return
	Input.action_press("move_up");await frames(3);Input.action_release("move_up")
	var shelves=world.props.filter(func(p):return p.kind=="CrumblingShelf" and p.get_parent().get_parent()==world.current_room)
	shelves.sort_custom(func(a,b):return a.position.y>b.position.y)
	if not await navigate(Vector2(108,82)):return
	if not await land(shelves[3],false,true):return
	if not await land(shelves[2],false):return
	# Drop beside the right partition into the permanently opened low passage.
	Input.action_press("move_right")
	for i in 180:
		if local_player().x>256 or deaths:break
		await frames(1)
	release()
	if not await cross("Prison_R01"):return
	if not await navigate(Vector2(40,154)):return
	Input.action_press("move_up");await frames(3);Input.action_release("move_up")
	if not await navigate(Vector2(128,154)):return
	var shelf=world.props.filter(func(p):return p.kind=="CrumblingShelf" and p.get_parent().get_parent()==world.current_room)[0]
	if not await land(shelf,true):return
	Input.action_press("move_right");Input.action_press("jump")
	await frames(16);Input.action_release("jump");Input.action_press("dash")
	await frames(10);Input.action_release("dash")
	for i in 80:
		if local_player().x>256 or deaths:break
		await frames(1)
	release();await frames(15)
	if not await cross("Prison_Hub"):return
	await capture("08_hub_return")
