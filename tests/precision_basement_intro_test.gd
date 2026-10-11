extends "res://tests/prison_navigation_test.gd"
## Real child input route. No injected positions, keys or mechanism state.
const OUT := "res://output/prison_precision/basement_intro"
var saw_swim := false
var return_to_hub:=true
var mode:="route"
var expected_deaths:=0
var retry_verified:=false
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	if "--retry" in OS.get_cmdline_user_args():mode="retry";expected_deaths=1
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_B01"
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
	var result:={"failure":failure,"deaths":deaths,"forbidden":forbidden,"swim":saw_swim,"room":str(world.current_room.name),"completed":world.circuits.save_completed(),"trace":trace}
	FileAccess.open(OUT+"/"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BASEMENT INTRO INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"swim":saw_swim}))
	await shutdown(0 if failure=="" and deaths==expected_deaths and not forbidden and saw_swim else 1)
func run_route() -> void:
	var gate=world.props.filter(func(p):return p.kind=="FloodGate" and p.get_parent().get_parent()==world.current_room)[0]
	var hit:=KinematicCollision2D.new()
	if not world.circuits.solved("basement_landing") and (not world.player.test_move(Transform2D(0,world.current_room.global_position+Vector2(204,150)),Vector2(0,40),hit) or hit.get_collider()!=gate.get_node("Barrier")):
		failure="closed sluice does not block exit";return
	await capture("01_closed")
	var sequence=[Vector2(96,160),Vector2(144,160),Vector2(144,112),Vector2(192,112),Vector2(192,160),Vector2(248,160)]
	for point in sequence:
		if not await navigate(point):return
		if not world.player.swimming():failure="left water in the weave";return
		saw_swim=true
		await capture("swim_%d_%d" % [point.x,point.y])
	if not world.circuits.solved("basement_landing"):
		failure="submerged end seal not reached";return
	if mode=="retry" and not retry_verified:
		var event=InputEventAction.new();event.action="respawn";event.pressed=true
		Input.parse_input_event(event);await frames(1)
		event=InputEventAction.new();event.action="respawn";event.pressed=false
		Input.parse_input_event(event);await frames(100)
		if deaths!=1 or world.player.swimming() or not world.player.is_on_floor() or not world.circuits.solved("basement_landing") or not gate.barrier.disabled:
			failure="swim retry did not preserve sluice and restore dry checkpoint";return
		retry_verified=true;navigation_deaths_allowed=1
		await capture("dry_retry")
		await run_route();return
	if not await navigate(Vector2(204,160)):return
	if not await cross("Prison_B02"):return
	await capture("next_room")
	if return_to_hub:await return_route()

func return_route() -> void:
	if str(world.current_room.name)!="Prison_B01":
		if not await cross("Prison_B01"):return
	for point in [Vector2(192,160),Vector2(192,112),Vector2(144,112),Vector2(144,160),Vector2(96,160),Vector2(64,120),Vector2(64,100)]:
		if not await navigate(point):return
	await capture("return_mouth")
	Input.action_press("jump");await frames(8)
	Input.action_press("move_right");await frames(22)
	release();await frames(30)
	if not await navigate(Vector2(104,82)):return
	if not await cross("Prison_Hub"):return
	await capture("hub_return")
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+(mode+"_" if mode!="route" else "")+label+".png")
