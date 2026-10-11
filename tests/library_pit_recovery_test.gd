extends "res://tests/prison_navigation_test.gd"
## Recovery fixture starts in the missed-jump pocket, then uses only inputs.
func _ready() -> void:
	SaveGame.unbind()
	world = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_G03"
	var actor = world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed := PackedScene.new()
	packed.pack(actor)
	actor.free()
	world.player_scene = packed
	add_child(world)
	world.player.died.connect(func(): deaths += 1)
	await frames(15)
	# Sole placement: establish the missed-jump state; no position writes afterward.
	world.player.respawn(world.current_room.global_position+Vector2(104,154))
	await frames(10)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(10)
	Input.action_release("jump")
	await frames(2)
	for direction in [1,-1,1,-1]:
		release()
		Input.action_press("move_right" if direction>0 else "move_left")
		await frames(3)
		Input.action_press("jump")
		await frames(2)
		Input.action_release("jump")
		await frames(7)
		print("POCKET RECOVERY ",local_player()," state=",world.player.state_name())
	release()
	await frames(40)
	var passed: bool=local_player().x<96 and local_player().y<135 and world.player.is_on_floor() and saw_wall_jump and not forbidden and deaths==0
	print("LIBRARY PIT RECOVERY: ","PASS" if passed else "FAIL"," at=",local_player()," wall_jump=",saw_wall_jump," forbidden=",forbidden," deaths=",deaths)
	await shutdown(0 if passed else 1)
