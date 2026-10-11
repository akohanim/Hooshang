extends "res://tests/prison_navigation_test.gd"
## Real child physics driven by input actions, with no position/progress writes.
## Starts at the hub; earns all library circuits and the key, then returns.
const OUT := "res://output/prison_precision/library_connected"
var capture_root := OUT
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):capture_root=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(capture_root)
	world = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_G03" if "--archive-test" in OS.get_cmdline_user_args() else "Prison_Hub"
	var player = world.player_scene.instantiate()
	player.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed := PackedScene.new()
	packed.pack(player)
	player.free()
	world.player_scene = packed
	Screen.set_scene(world)
	world.player.died.connect(func(): deaths += 1)
	await frames(20)
	await run_loop()
	await finish()

func archive_route() -> void:
	var driver=load("res://tests/precision_library_music_test.gd").new()
	driver.run_on_ready=false
	add_child(driver)
	driver.world=world
	var on_death=func():driver.deaths+=1
	world.player.died.connect(on_death)
	await driver.run_route()
	driver.release()
	failure=driver.failure
	forbidden=forbidden or driver.forbidden
	trace.append_array(driver.trace)
	
	if failure!="":return
	if not await cross("Prison_Hub"):return
	await capture("library_hub_return")

	if "--backtrack" in OS.get_cmdline_user_args():
		if not await cross("Prison_G04"):return
		if not await cross("Prison_G03"):return
		await driver.reverse_route()
		driver.release()
		failure=driver.failure
		forbidden=forbidden or driver.forbidden
		trace.append_array(driver.trace)
		if failure!="":return
		var stacks=load("res://tests/precision_library_stacks_test.gd").new()
		stacks.run_on_ready=false
		add_child(stacks);stacks.world=world
		var stacks_death=func():stacks.deaths+=1
		world.player.died.connect(stacks_death)
		await stacks.reverse_route()
		stacks.release();failure=stacks.failure
		forbidden=forbidden or stacks.forbidden
		trace.append_array(stacks.trace)
		world.player.died.disconnect(stacks_death);stacks.queue_free()
		if failure!="":return
		var intro=load("res://tests/precision_library_intro_test.gd").new()
		intro.run_on_ready=false
		add_child(intro);intro.world=world
		var intro_death=func():intro.deaths+=1
		world.player.died.connect(intro_death)
		await intro.reverse_route()
		intro.release();failure=intro.failure
		forbidden=forbidden or intro.forbidden
		trace.append_array(intro.trace)
		world.player.died.disconnect(intro_death);intro.queue_free()
		if failure!="":return
		await capture("library_reverse_hub")
	world.player.died.disconnect(on_death)
	driver.queue_free()

func run_loop() -> void:
	if str(world.current_room.name)=="Prison_G03":
		await archive_route()
		return
	if not await cross("Prison_G01"): return
	var intro=load("res://tests/precision_library_intro_test.gd").new()
	intro.run_on_ready=false
	add_child(intro);intro.world=world
	var on_death=func():intro.deaths+=1
	world.player.died.connect(on_death)
	await intro.run_route()
	intro.release();failure=intro.failure
	forbidden=forbidden or intro.forbidden
	trace.append_array(intro.trace)
	world.player.died.disconnect(on_death);intro.queue_free()
	if failure!="":return
	var stacks=load("res://tests/precision_library_stacks_test.gd").new()
	stacks.run_on_ready=false
	add_child(stacks);stacks.world=world
	var stack_death=func():stacks.deaths+=1
	world.player.died.connect(stack_death)
	await stacks.run_route()
	stacks.release();failure=stacks.failure
	forbidden=forbidden or stacks.forbidden
	trace.append_array(stacks.trace)
	world.player.died.disconnect(stack_death);stacks.queue_free()
	if failure!="":return
	await archive_route()

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(capture_root+"/"+label+".png")

func finish() -> void:
	release()
	var result := {"failure":failure,"deaths":deaths,"forbidden":forbidden,"room":str(world.current_room.name),"keys":world.collected,"circuits":world.circuits.save_completed(),"backtrack":"--backtrack" in OS.get_cmdline_user_args(),"trace":trace}
	FileAccess.open(capture_root+("/archive_route.json" if "--archive-test" in OS.get_cmdline_user_args() else "/route.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("LIBRARY WING INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"room":str(world.current_room.name)}))
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)
