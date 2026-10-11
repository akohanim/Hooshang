extends Node
## Imported-room mechanism fixture; direct ledger activation is not a route playtest.
var failures := 0
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room = "Prison_G01"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world = Screen.current
	# G03 now uses ordered musical notes, whose contact/reset contract is
	# exercised by prison_music_import_test and precision_library_music_test.
	for name in ["Prison_G01","Prison_G02"]:
		var room = world.rooms.filter(func(r): return str(r.name)==name)[0]
		world._enter_room(room,true)
		world.player.respawn(world.spawn_point_for(room))
		await frames(15)
		var gate = world.props.filter(func(p): return p.kind=="CircuitGate" and p.get_parent().get_parent()==room)[0]
		var members: Array = world.props.filter(func(p): return p.kind=="CircuitNode" and p.get_parent().get_parent()==room)
		var test_at := Vector2(252,34) if name=="Prison_G01" else Vector2(300,48) if name=="Prison_G02" else Vector2(252,146)
		var motion := Vector2(0,-40) if name=="Prison_G01" else Vector2(40,0)
		var result := KinematicCollision2D.new()
		var collided: bool = world.player.test_move(Transform2D(0,room.global_position+test_at),motion,result)
		print("GATE PROBE ",name," from=",test_at," collided=",collided," collider=",result.get_collider() if collided else null," gate=",gate.get_node("Barrier")," gatepos=",gate.global_position," shape=",gate.barrier.disabled)
		check(collided and result.get_collider()==gate.get_node("Barrier"), name+": closed gate physically intercepts required aperture")
		for count in range(1,members.size()):
			for i in count: world.circuits.touch(gate.circuit_id,members[i].entity_iid)
			world.player.die()
			await frames(90)
			check(world.current_room==room and world.player.is_on_floor(),name+": safe room retry after stage %d" % count)
			for member in members: check(not member._lit,name+": partial nodes reset after death")
			check(not gate.barrier.disabled,name+": partial attempt never opens gate")
		world.circuits.touch(gate.circuit_id,members[0].entity_iid)
		world._enter_room(world.rooms.filter(func(r): return str(r.name)=="Prison_Hub")[0],true)
		world._enter_room(room,true)
		world.player.respawn(world.spawn_point_for(room))
		await frames(5)
		check(not members[0]._lit,name+": leaving incomplete room resets circuit")
		for member in members: world.circuits.touch(gate.circuit_id,member.entity_iid)
		await frames(3)
		check(gate.barrier.disabled,name+": completed passage physically opens")
		world.player.die()
		await frames(90)
		check(gate.barrier.disabled and world.circuits.solved(gate.circuit_id),name+": completed passage survives retry")
	print("LIBRARY RETRY FIXTURE: ",failures," failures")
	get_tree().quit(1 if failures else 0)
