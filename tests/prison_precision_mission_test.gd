extends "res://tests/prison_navigation_test.gd"
## Connected rendered mission from hub through all keys and actual cage contact.
var out := "res://output/prison_precision/mission"
func _ready() -> void:
	SaveGame.dir="user://prison_precision_mission_saves"
	SaveGame.unbind()
	SaveGame.erase(0)
	SaveGame._bind(0)
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_Hub"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed:=PackedScene.new()
	packed.pack(actor)
	actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func():deaths+=1)
	await frames(20)
	var driver=load("res://tests/prison_challenge_driver.gd").new()
	driver.world=world
	var order: Array=["Green","Red","Blue","Gold"]
	if "--reverse-order" in OS.get_cmdline_user_args():
		order.reverse()
		out+="_reverse"
	DirAccess.make_dir_recursive_absolute(out)
	driver.capture_root=out
	add_child(driver)
	var save_verified:=false
	for index in order.size():
		if not await driver.traverse([order[index]]):failure=driver.failure;break
		if index==1:
			var keys: Array=world.collected.duplicate()
			var circuits: Array=world.circuits.save_completed().duplicate()
			var timers: Array=world.timers.save_completed().duplicate()
			if not SaveGame.save_now():failure="earned progress save failed";break
			SaveGame.unbind()
			if not SaveGame.resume(0):failure="earned progress resume failed";break
			await get_tree().create_timer(.5).timeout
			world=Screen.current;driver.world=world
			# Resume uses the production actor, with the same land-assist exclusion
			# as the full-act driver. Individual wing fixtures also disable bank assists.
			world.player._ledge_cooldown=3600.0
			world.player.died.connect(func():deaths+=1)
			if world.collected!=keys or circuits.any(func(id):return not world.circuits.solved(id)) or timers.any(func(id):return not world.timers.solved(id)):
				failure="earned keys or milestones lost on disk resume";break
			save_verified=true
			print("EARNED SAVE/LOAD PASS keys=",world.collected)

	forbidden=forbidden or driver.forbidden
	if failure=="":
		if await navigate(Vector2(292,346)):
			await frames(240)
			Input.action_press("skip_dialogue")
			await frames(150)
			Input.action_release("skip_dialogue")
			await frames(30)
			if not world.rescued or world.collected.size()!=4 or world.inserted.size()!=4 or not world.story_flags.get("cell_reunion",false):failure="cage/reunion incomplete"
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png(out+"/cage.png")
	var result={"failure":failure,"deaths":deaths,"forbidden":forbidden,"keys":world.collected,"locks":world.inserted,"rescued":world.rescued,"story":world.story_flags,"order":order,"save_verified":save_verified}
	FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CONNECTED PRISON MISSION: ",JSON.stringify(result))
	SaveGame.unbind()
	SaveGame.erase(0)
	driver.queue_free()
	await shutdown(0 if failure=="" and deaths==0 and not forbidden and save_verified else 1)
