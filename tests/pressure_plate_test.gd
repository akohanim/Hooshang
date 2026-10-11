extends Node
## Staged contact/retry fixtures; input-only traversal is tested separately.
var failures := 0
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_Y01"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	var room=world.current_room
	var id="gym_plate_intro"
	var starts: Array=[]
	world.timers.attempt_started.connect(func(puzzle):
		if puzzle==id:starts.append(puzzle))
	world.player.respawn(room.global_position+Vector2(81,154))
	await frames(10)
	check(not world.timers.active(id),"side of body touching plate does not press it")
	world.player.respawn(room.global_position+Vector2(96,140))
	await frames(1)
	check(not world.timers.active(id),"airborne above plate does not press it")
	await frames(30)
	check(world.timers.active(id),"gravity landing presses plate")
	await frames(540)
	check(world.timers.remaining(id)>7.8 and starts.size()==1,"held plate refreshes without repeated attempt events")
	world.player.respawn(room.global_position+Vector2(48,154))
	await frames(500)
	check(not world.timers.active(id),"release expires")
	world.player.respawn(room.global_position+Vector2(96,154))
	await frames(8)
	check(world.timers.active(id) and starts.size()==2,"expired plate rearms on landing")
	world.player.die()
	await frames(90)
	check(not world.timers.active(id) and world.player.global_position.distance_to(room.global_position+Vector2(48,154))<3,"death resets attempt at safe room entrance")
	world.player.respawn(room.global_position+Vector2(304,154))
	await frames(5)
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	check(world.timers.active(id),"far-side return lever opens escape")
	world.player.respawn(room.global_position+Vector2(288,154))
	await frames(5)
	check(not world.timers.solved(id),"return lever cannot bypass main plate challenge")
	world.player.respawn(room.global_position+Vector2(96,154))
	await frames(5)
	world.player.respawn(room.global_position+Vector2(288,154))
	await frames(5)
	check(world.timers.solved(id),"plate attempt banks at real seal contact")
	world.player.die()
	await frames(90)
	check(world.timers.solved(id),"completion survives death")
	var gate=world.props.filter(func(p):return p.kind=="TimedGate" and p.puzzle_id==id)[0]
	check(gate.barrier.disabled,"completed shutter stays physically open")
	check(world.collected.is_empty(),"plate fixtures grant no keys")
	world.queue_free()
	await frames(3)
	print("PRESSURE PLATE: ",failures," failures")
	get_tree().quit(1 if failures else 0)
