extends Node
## Controlled death/respawn fixtures, separate from the earned swimming route.
var failures := 0
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_B02"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	var room=world.current_room
	var gate=world.props.filter(func(p):return p.kind=="FloodGate" and p.get_parent().get_parent()==room)[0]
	var deaths: Array=[]
	world.player.died.connect(func():deaths.append(true))
	world.player.respawn(room.global_position+Vector2(184,174))
	world.player.invulnerable_timer=0.0
	await frames(90)
	check(deaths.size()==1,"visible deep-water hazard kills once")
	check(world.player.is_on_floor() and not world.player.swimming(),"death returns to stable dry entrance")
	check(not world.circuits.solved("basement_stores") and not gate.barrier.disabled,"unoperated valve stays closed after death")
	var valve=world.props.filter(func(p):return p.kind=="FloodValve" and p.get_parent().get_parent()==room)[0]
	world.player.respawn(valve.global_position+Vector2(0,2))
	await frames(20)
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	check(world.circuits.solved("basement_stores"),"actual dry-pocket input opens sluice")
	world.player.respawn(room.global_position+Vector2(184,174))
	world.player.invulnerable_timer=0.0
	await frames(90)
	check(deaths.size()==2 and gate.barrier.disabled,"second hazard death preserves opened passage")
	check(world.player.is_on_floor() and not world.player.swimming(),"second respawn restores ordinary movement")
	check(world.collected.is_empty(),"retry fixtures grant no key")
	print("FLOODED STORES RETRY: ",failures," failures")
	world.queue_free()
	world=null
	await frames(3)
	get_tree().quit(1 if failures else 0)
