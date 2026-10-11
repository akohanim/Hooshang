extends "res://tests/prison_navigation_test.gd"
## Connected rendered mission from hub through all keys and actual cage contact.
var out := "res://output/prison_challenge/integration/mission"
func _ready() -> void:
	SaveGame.unbind()
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
	driver.capture_root=out
	add_child(driver)
	if not await driver.traverse(order):failure=driver.failure
	forbidden=forbidden or driver.forbidden
	if failure=="":
		if await navigate(Vector2(292,346)):
			await frames(240)
			Input.action_press("skip_dialogue")
			await frames(150)
			Input.action_release("skip_dialogue")
			await frames(30)
			if not world.rescued or world.collected.size()!=4 or world.inserted.size()!=4 or not world.story_flags.get("cell_reunion",false):failure="cage/reunion incomplete"
	await RenderingServer.frame_post_draw
	Screen.viewport.get_texture().get_image().save_png(out+"/cage.png")
	var result={"failure":failure,"deaths":deaths,"forbidden":forbidden,"keys":world.collected,"locks":world.inserted,"rescued":world.rescued,"story":world.story_flags,"order":order}
	FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CONNECTED PRISON MISSION: ",JSON.stringify(result))
	driver.queue_free()
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)
