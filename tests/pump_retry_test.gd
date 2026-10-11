extends Node
## Staged partial circuits and hazard positions, separate from the earned route.
var failures := 0
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_B03"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	var room=world.current_room
	var key_gate=world.props.filter(func(p):return p.kind=="CircuitGate" and p.get_parent().get_parent()==room)[0]
	var sluice=world.props.filter(func(p):return p.kind=="FloodGate" and p.get_parent().get_parent()==room)[0]
	var nodes=world.props.filter(func(p):return p.kind=="CircuitNode" and p.get_parent().get_parent()==room)
	var collision:=KinematicCollision2D.new()
	check(world.player.test_move(Transform2D(0,room.global_position+Vector2(184,160)),Vector2(-48,0),collision) and collision.get_collider()==sluice.get_node("Barrier"),"closed sluice prevents swimming to deep seal")
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	check(world.circuits.solved("basement_pump_valve") and sluice.barrier.disabled,"dry lever permanently opens swim chamber")
	world.player.respawn(room.global_position+nodes.filter(func(p):return p.position.y>96)[0].position)
	await frames(12)
	check(nodes.any(func(p):return p._lit) and not key_gate.barrier.disabled,"one actual seal contact does not open key")
	var deaths: Array=[]
	world.player.died.connect(func():deaths.append(true))
	world.player.respawn(room.global_position+Vector2(100,174))
	world.player.invulnerable_timer=0.0
	await frames(90)
	check(deaths.size()==1,"deep-water hazard produces one death")
	check(world.player.is_on_floor() and not world.player.swimming(),"hazard respawn is dry and stable")
	check(sluice.barrier.disabled and nodes.all(func(p):return not p._lit),"death keeps valve and resets partial seals")
	world.player.respawn(room.global_position+Vector2(184,34))
	await frames(12)
	check(nodes.any(func(p):return p._lit) and not key_gate.barrier.disabled,"high seal can be first without bypassing deep seal")
	world.player.die()
	await frames(90)
	check(nodes.all(func(p):return not p._lit) and sluice.barrier.disabled,"high-first interrupted attempt resets correctly")
	for at in [nodes.filter(func(p):return p.position.y>96)[0].position,Vector2(184,34)]:
		world.player.respawn(room.global_position+at)
		await frames(12)
	check(key_gate.barrier.disabled,"both physical contacts open key gate")
	world.player.die()
	await frames(90)
	check(key_gate.barrier.disabled and sluice.barrier.disabled,"completed route remains open after death")
	Input.action_press("move_right")
	await frames(50)
	Input.action_release("move_right")
	check(world.collected==["Blue"],"actual input reaches Blue after completed-route respawn")
	print("PUMP RETRY: ",failures," failures")
	world.queue_free()
	world=null
	await frames(3)
	get_tree().quit(1 if failures else 0)
