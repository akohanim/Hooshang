extends "res://tests/prison_navigation_test.gd"
## Real child input route. No injected positions, keys or mechanism state.
const OUT := "res://output/prison_challenge/gym_intro"
func _ready() -> void:
	SaveGame.unbind()
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_Y01"
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
	var result:={"failure":failure,"deaths":deaths,"forbidden":forbidden,"wall_jump":saw_wall_jump,"room":str(world.current_room.name),"completed":world.timers.save_completed(),"trace":trace}
	FileAccess.open(OUT+"/route.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("GYM INTRO INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"wall_jump":saw_wall_jump}))
	await shutdown(0 if failure=="" and deaths==0 and not forbidden and saw_wall_jump else 1)
func run_route() -> void:
	if not await navigate(Vector2(96,154)):return
	await frames(540)
	if world.timers.remaining("gym_plate_intro")<7.8:
		failure="standing plate did not hold timer";return
	await capture("01_held_plate")
	if not await navigate(Vector2(48,154)):return
	await frames(500)
	if world.timers.active("gym_plate_intro"):
		failure="released plate did not expire";return
	await capture("02_expired")
	if not await navigate(Vector2(96,154)):return
	var started:=ticks
	if not await navigate(Vector2(172,154)):return
	for at in [Vector2(176,114),Vector2(196,98)]:
		if not await gym_go(world.current_room.global_position+at,false):
			failure="wall jump failed";return
	await capture("03_wall_jump")
	if not await navigate(Vector2(288,154)):return
	if not world.timers.solved("gym_plate_intro"):
		failure="seal did not bank crossing";return
	print("PLATE CROSSING SECONDS ",(ticks-started)/60.0)
	await capture("04_banked")
	if not await cross("Prison_Y02"):return
	if not await cross("Prison_Y01"):return
	if not world.timers.solved("gym_plate_intro"):
		failure="return reset completion";return
	if not await navigate(Vector2(48,154)):return
	if not await cross("Prison_Hub"):return
	await capture("05_return")
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+label+".png")
