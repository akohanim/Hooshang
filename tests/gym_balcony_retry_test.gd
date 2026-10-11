extends Node
## Collision probes are staged; pit death below is driven by held movement input.
var failures := 0
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool,label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_Y02"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	var room=world.current_room
	var id="gym_balcony"
	var exit_gate=world.props.filter(func(p):return p.kind=="TimedShutter" and p.puzzle_id==id and p.fields.get("RequireBank",false))[0]
	check(world.timers.active(id) and not exit_gate.barrier.disabled,"standing entrance plate opens crossing but not exit")
	# Probe the open side of the partial entrance ledge: x252 touches its
	# edge as well as the shutter, making collider ordering ambiguous.
	var hit:=KinematicCollision2D.new()
	check(world.player.test_move(Transform2D(0,room.global_position+Vector2(260,152)),Vector2(0,35),hit) and hit.get_collider()==exit_gate.get_node("Barrier"),"unbanked exit physically blocks downward skip")
	var deaths: Array=[]
	world.player.died.connect(func():deaths.append(true))
	Input.action_press("move_right")
	for frame in 240:
		await frames(1)
		if not deaths.is_empty():break
	Input.action_release("move_right")
	await frames(90)
	check(deaths.size()==1,"walking off launch bank meets actual pit hazard")
	check(world.player.global_position.distance_to(room.global_position+Vector2(48,154))<3 and world.player.is_on_floor(),"pit death returns to safe launch plate")
	check(not world.timers.solved(id) and not exit_gate.barrier.disabled,"death never grants completion")
	world.player.respawn(room.global_position+Vector2(304,154))
	await frames(5)
	world.timers.reset_attempts()
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	check(world.timers.active(id),"far bank lever provides retreat after expiry")
	world.player.respawn(room.global_position+Vector2(288,154))
	await frames(5)
	check(not world.timers.solved(id),"far return lever cannot solve seal")
	check(world.collected.is_empty(),"fixtures grant no keys")
	world.queue_free()
	await frames(3)
	print("GYM BALCONY RETRY: ",failures," failures")
	get_tree().quit(1 if failures else 0)
