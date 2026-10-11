extends Node
## Imported control fixtures; movement route is a separate rendered test.
var failures := 0
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_B01"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	var valve=world.props.filter(func(p):return p.kind=="FloodValve")[0]
	valve.fields.Touch=false
	Input.action_press("move_up")
	await frames(4)
	world.player.respawn(valve.global_position)
	await frames(4)
	check(not world.circuits.solved("basement_landing"),"held Up before arriving does not operate valve")
	Input.action_release("move_up")
	await frames(2)
	valve.fields.RequireDry=true
	Input.action_press("move_up")
	await frames(4)
	check(world.player.swimming() and not world.circuits.solved("basement_landing"),"dry control refuses underwater interaction")
	Input.action_release("move_up")
	await frames(2)
	valve.fields.RequireDry=false
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	check(world.circuits.solved("basement_landing"),"fresh Up operates a submerged valve")
	world.player.die()
	await frames(90)
	check(world.circuits.solved("basement_landing") and valve.gate.barrier.disabled,"opened sluice survives death")
	LdtkWorld.debug_start_room="Prison_B01"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	world=Screen.current
	valve=world.props.filter(func(p):return p.kind=="FloodValve")[0]
	valve.fields.Touch=false
	valve.fields.RequireDry=true
	valve.position=Vector2(48,152)
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	check(world.player.is_on_floor() and not world.player.swimming() and world.circuits.solved("basement_landing"),"dry valve operates from actual stable footing")
	print("FLOOD VALVE FIXTURES: ",failures," failures")
	world.queue_free()
	world=null
	valve=null
	await frames(3)
	get_tree().quit(1 if failures else 0)
