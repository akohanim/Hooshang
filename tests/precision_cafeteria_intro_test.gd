extends "res://tests/prison_navigation_test.gd"
## Earned intro route; real inputs, no position or puzzle-state grants.
const OUT="res://output/prison_precision/cafeteria_intro"
var shelf_age := -1.0
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_R01"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed=PackedScene.new();packed.pack(actor);actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func():deaths+=1)
	await frames(20)
	await run_route()
	release()
	var result={"failure":failure,"deaths":deaths,"forbidden":forbidden,"shelf_contact_seconds":shelf_age,"room":str(world.current_room.name),"trace":trace}
	FileAccess.open(OUT+"/route.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PRECISION R01: ",JSON.stringify(result))
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)
func capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+label+".png")
func run_route() -> void:
	await capture("01_observe")
	if not await navigate(Vector2(264,154)):return
	Input.action_press("move_up");await frames(3);Input.action_release("move_up")
	if not await navigate(Vector2(244,154)):return
	var shelf=world.props.filter(func(p):return p.kind=="CrumblingShelf" and p.get_parent().get_parent()==world.current_room)[0]
	Input.action_press("jump")
	for i in 120:
		Input.action_release("move_left");Input.action_release("move_right")
		var aim: float=192-local_player().x-world.player.velocity.x*0.10
		Input.action_press("move_left" if aim<0 else "move_right")
		if i==24:Input.action_release("jump")
		await frames(1)
		if shelf._spent and world.player.is_on_floor():break
		if deaths:break
	release()
	if not shelf._spent or shelf._falling or not world.player.is_on_floor():failure="shelf landing not earned";return
	await frames(8)
	shelf_age=shelf._timer
	await capture("02_temporary_landing")
	Input.action_press("move_left");Input.action_press("jump")
	await frames(16);Input.action_release("jump");Input.action_press("dash")
	await frames(10);Input.action_release("dash")
	for i in 70:
		if local_player().x<128 or deaths:break
		await frames(1)
	release();await frames(18)
	await capture("03_bank")
	if not await navigate(Vector2(64,154)):return
	if not world.timers.solved("cafeteria_intro"):failure="seal not banked";return
	if not await cross("Prison_R02"):return
	await capture("04_exit")
