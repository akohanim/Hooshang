extends "res://tests/prison_navigation_test.gd"
## Real child physics driven by input actions, with no position/progress writes.
## Starts at G01's authored spawn; verifies the introductory circuit and exit.
const OUT := "res://output/prison_challenge/library_intro"
func _ready() -> void:
	SaveGame.unbind()
	DirAccess.make_dir_recursive_absolute(OUT)
	world = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_G01"
	var player = world.player_scene.instantiate()
	player.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed := PackedScene.new()
	packed.pack(player)
	player.free()
	world.player_scene = packed
	Screen.set_scene(world)
	world.player.died.connect(func(): deaths += 1)
	await frames(20)
	await capture("01_arrival")
	if not await navigate(Vector2(104,130)):
		await finish()
		return
	await frames(5)
	if not world.circuits.touched("library_reading", world.props.filter(func(p): return p.kind=="CircuitNode" and p.position.x==104)[0].entity_iid):
		failure = "low node not touched"
	if world.circuits.solved("library_reading"): failure = "gate opened before second node"
	await capture("02_first_node")
	if failure != "":
		await finish()
		return
	if not await navigate(Vector2(200,106)):
		await finish()
		return
	await frames(5)
	if not world.circuits.solved("library_reading"): failure = "second node did not open gate"
	await capture("03_circuit_open")
	if failure != "":
		await finish()
		return
	if not await cross("Prison_G02"):
		await finish()
		return
	await capture("04_exit_reached")
	await finish()

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+label+".png")

func finish() -> void:
	release()
	var result := {"failure":failure,"deaths":deaths,"forbidden":forbidden,"room":str(world.current_room.name),"trace":trace}
	FileAccess.open(OUT+"/route.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("LIBRARY INTRO INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"room":str(world.current_room.name)}))
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)
