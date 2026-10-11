extends Node
## State integration fixture: directly activates ledger nodes, not a route playtest.
var failures := 0
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	SaveGame.dir = "user://prison_circuit_acceptance_saves"
	SaveGame.unbind()
	SaveGame.erase(0)
	SaveGame._bind(0)
	LdtkWorld.debug_start_room = "Prison_G01"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world = Screen.current
	var members: Array = world.props.filter(func(p): return p.kind=="CircuitNode" and p.get_parent().get_parent()==world.current_room)
	check(members.size()==2, "intro nodes imported")
	if members.size()!=2:
		get_tree().quit(1)
		return
	world.circuits.touch("library_reading", members[0].entity_iid)
	world.player.die()
	await frames(90)
	check(not world.circuits.touched("library_reading",members[0].entity_iid), "death clears unfinished world circuit")
	world.circuits.touch("library_reading",members[0].entity_iid)
	world._enter_room(world.current_room,true)
	check(not world.circuits.touched("library_reading",members[0].entity_iid), "room entry clears unfinished circuit")
	for member in members: world.circuits.touch("library_reading",member.entity_iid)
	# Complete every registered circuit and sluice to cover cross-room restore.
	var expected_circuits: Array = []
	for prop in world.props:
		if prop.kind in ["CircuitGate","FloodGate","MusicalGate"]: expected_circuits.append(prop.circuit_id)
		if prop.kind in ["CircuitNode","FloodValve"]: world.circuits.touch(prop.gate.circuit_id,prop.entity_iid)
	var pads=world.props.filter(func(p):return p.kind=="MusicalTile")
	pads.sort_custom(func(a,b):return a.note_index<b.note_index)
	for pad in pads:world.circuits.touch(pad.gate.circuit_id,pad.entity_iid)
	world.collect_key("Red",world.player.global_position)
	check(SaveGame.save_now(), "completed circuit written with existing key progress")
	SaveGame.unbind()
	check(SaveGame.resume(0), "resume circuit save from disk")
	await frames(30)
	world = Screen.current
	for id in expected_circuits:
		check(world.circuits.solved(id), "completed circuit restored after imported gate registration: "+id)
	check(world.collected==["Red"], "key progress preserved alongside circuit state")
	var gate = world.props.filter(func(p): return p.kind=="CircuitGate")[0]
	check(gate.barrier.disabled, "restored gate is physically open")
	for prop in world.props:
		if prop.kind in ["CircuitGate","FloodGate","MusicalGate"]:
			check(prop.barrier.disabled, "all saved gates and sluices restore physically open")
		if prop.kind in ["CircuitNode","FloodValve"]:
			check(prop._lit, "completed circuit nodes restore lit across rooms")
	world.player.die()
	await frames(90)
	check(world.circuits.solved("library_reading") and gate.barrier.disabled, "completed gate survives another death")
	SaveGame.unbind()
	SaveGame.erase(0)
	print("PRISON CIRCUIT SAVE: ",failures," failures")
	get_tree().quit(1 if failures else 0)
