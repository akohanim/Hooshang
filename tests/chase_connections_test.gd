extends Node
## Transition and checkpoint integration. Position fixtures are not route playtests.
var failures: Array[String] = []
func _ready() -> void:
	SaveGame.slot = -1
	SaveGame._pending = {}
	LdtkWorld.debug_start_room = "Prison_Hub"
	var world = load("res://ldtk/Act2World.tscn").instantiate()
	world.get_node("Act2Ending").free()
	add_child(world)
	await frames(20)
	world.story_flags.merge({"cell_reunion":true,"chase_banter":true,"wall_reunion":true})
	for id in world.IDS:
		world.collected.append(id)
		world.inserted.append(id)
	world.finish_rescue()
	world.player.respawn(world.current_room.global_position+Vector2(64,346))
	await frames(5)
	Input.action_press("move_up")
	await frames(2)
	Input.action_release("move_up")
	await frames(55)
	check(world.current_room.name=="Act_2_Level_16","rescued courtyard passage enters the chase")
	check(world._room_before(world.current_room).name=="Prison_Hub","loaded chase return points at the actual prison entrance")
	for n in range(16,20):
		check(world.current_room.name=="Act_2_Level_%d"%n,"connected room %d"%n)
		await frames(25)
		check(world.player.is_on_floor(),"room %d spawn has footing"%n)
		var room: Node2D = world.current_room
		var checkpoint: Vector2 = world._checkpoint
		var guide = room.get_node("ChaseRoom")
		if n < 19:
			world.player.global_position=room.global_position+Vector2(180,150)
			await frames(80)
			check(guide.index>0,"room %d guide runs ahead before retry"%n)
		world.player.die()
		await frames(90)
		check(world.current_room==room and world.player.state!=Player.State.DEAD and world.player.is_on_floor(),"room %d death has a safe local retry"%n)
		check(guide.index==0 and not guide.moving,"room %d guide returns to first waiting point"%n)
		check(world._checkpoint==checkpoint,"room %d retains entry checkpoint"%n)
		if n==19:break
		var exit: Node2D = world._exit_in(room)
		check(exit!=null,"authored forward exit %d"%n)
		world.player.global_position=exit.global_position
		await frames(70)
	for n in range(19,15,-1):
		var current: Node2D = world.current_room
		world.player.respawn(current.global_position+Vector2(24,178 if n==18 else 194))
		await frames(5)
		Input.action_press("move_left")
		await frames(35)
		Input.action_release("move_left")
		await frames(50)
		check(world.current_room.name==("Prison_Hub" if n==16 else "Act_2_Level_%d"%(n-1)),"backward door from %d"%n)
	check(not Game.completed,"the wall leads to the unfinished farewell, not false completion")
	world.queue_free()
	await frames(3)
	print("CHASE CONNECTIONS: ","ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
