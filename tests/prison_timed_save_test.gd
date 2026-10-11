extends Node
## Imported-world safety and persistence fixtures, not an earned room playthrough.
var failures := 0
func frames(n: int=3) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _ready() -> void:
	SaveGame.dir="user://prison_timed_acceptance_saves"
	SaveGame.unbind()
	SaveGame.erase(0)
	SaveGame._bind(0)
	LdtkWorld.debug_start_room="Prison_R01"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	var room=world.current_room
	var gate=world.props.filter(func(p): return p.kind=="TimedGate")[0]
	world.timers.start("cafeteria_intro")
	world.player.die()
	await frames(90)
	check(not world.timers.active("cafeteria_intro") and not gate.barrier.disabled,"death clears unbanked timer")
	world.timers.start("cafeteria_intro")
	var other=world.rooms.filter(func(r): return str(r.name)=="Prison_R02")[0]
	world._enter_room(other,true)
	check(not world.timers.active("cafeteria_intro"),"room exit clears unbanked timer")
	world._enter_room(room,true)
	world.player.respawn(world.spawn_point_for(room))
	world.timers.start("cafeteria_intro")
	await frames()
	world.player.respawn(room.global_position+Vector2(84,154))
	await frames()
	world.timers.tick(20)
	await frames(10)
	check(gate.barrier.disabled and absf(world.player.global_position.x-room.global_position.x-84)<1,"expiry does not close through or depenetrate the actual player")
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	await frames(10)
	check(not gate.barrier.disabled and world.player.global_position.x>room.global_position.x+94,"player leaves safely before gate closes")
	check(not world.timers.solved("cafeteria_intro"),"closure grace does not bank puzzle")
	# Establish the failed-attempt far side, then operate the return lever by input.
	world.player.respawn(room.global_position+Vector2(40,154))
	await frames(5)
	Input.action_press("move_up")
	await frames(2)
	Input.action_release("move_up")
	check(world.timers.active("cafeteria_intro"),"return lever opens shutter with Up")
	Input.action_press("move_right")
	await frames(65)
	Input.action_release("move_right")
	await frames(10)
	check(world.player.global_position.x>room.global_position.x+94,"return lever permits physical retreat")
	check(not world.timers.solved("cafeteria_intro"),"passing relay on return cannot bypass challenge")
	world.timers.start("cafeteria_intro")
	check(world.timers.bank("cafeteria_intro"),"completion can bank after restarting main control")
	for prop in world.props:
		if prop.kind=="TimedGate":
			world.timers.start(prop.puzzle_id)
			world.timers.bank(prop.puzzle_id)
	world.collect_key("Green",world.player.global_position)
	check(SaveGame.save_now(),"timer completion and keys saved")
	SaveGame.unbind()
	check(SaveGame.resume(0),"timer save resumed from disk")
	await frames(30)
	world=Screen.current
	gate=world.props.filter(func(p): return p.kind=="TimedGate")[0]
	check(world.timers.solved("cafeteria_intro") and gate.barrier.disabled,"banked shutter restores physically open")
	check(world.collected==["Green"],"key progress preserved")
	for prop in world.props:
		if prop.kind in ["TimedGate","TimedShutter"]:
			check(prop.barrier.disabled,"every linked shutter restores from its controller completion")
	world.player.die()
	await frames(90)
	check(world.timers.solved("cafeteria_intro") and gate.barrier.disabled,"banked shutter survives another death")
	SaveGame.unbind()
	SaveGame.erase(0)
	print("PRISON TIMED SAVE/RECOVERY: ",failures," failures")
	get_tree().quit(1 if failures else 0)
