extends "res://tests/prison_navigation_test.gd"
## One world, earned inputs from hub through every cafeteria room and back.
const OUT := "res://output/prison_precision/cafeteria_connected"
var stages: Array = []
func _ready() -> void:
	if not run_on_ready:return
	SaveGame.unbind()
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_Hub"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed=PackedScene.new();packed.pack(actor);actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func():deaths+=1)
	await frames(20)
	DirAccess.make_dir_recursive_absolute(OUT)
	await run_loop()
	var result={"failure":failure,"deaths":deaths,"forbidden":forbidden,"room":str(world.current_room.name),"keys":world.collected,"stages":stages,"hub_trace":trace}
	var label="backtrack" if "--backtrack" in OS.get_cmdline_user_args() else "route"
	FileAccess.open(OUT+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(OUT+"/return.png")
	print("CONNECTED CAFETERIA: ",failure," deaths=",deaths," forbidden=",forbidden)
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)

func run_loop() -> void:
	if await cross("Prison_R01"):
		for stage in ["intro","development","capstone"]:
			var driver=load("res://tests/precision_cafeteria_"+stage+"_test.gd").new()
			driver.run_on_ready=false
			driver.world=world
			if stage=="capstone" and "--backtrack" in OS.get_cmdline_user_args():driver.mode="backtrack"
			add_child(driver)
			var death_callback=func():driver.deaths+=1
			world.player.died.connect(death_callback)
			await driver.run_route()
			driver.release()
			world.player.died.disconnect(death_callback)
			stages.append({"stage":stage,"failure":driver.failure,"deaths":driver.deaths,"forbidden":driver.forbidden,"trace":driver.trace})
			forbidden=forbidden or driver.forbidden
			if driver.failure!="":failure=stage+": "+driver.failure
			driver.queue_free()
			if failure!="" or deaths:break
	if failure=="" and deaths==0 and "--backtrack" in OS.get_cmdline_user_args():
		var driver=load("res://tests/precision_cafeteria_development_test.gd").new()
		driver.run_on_ready=false;driver.world=world;add_child(driver)
		var death_callback=func():driver.deaths+=1
		world.player.died.connect(death_callback)
		await driver.return_route()
		driver.release();world.player.died.disconnect(death_callback)
		stages.append({"stage":"lower_rooms_return","failure":driver.failure,"deaths":driver.deaths,"forbidden":driver.forbidden,"trace":driver.trace})
		failure=driver.failure;forbidden=forbidden or driver.forbidden
		driver.queue_free()
	if failure=="" and (not world.collected.has("Red") or str(world.current_room.name)!="Prison_Hub"):failure="key loop did not finish"
