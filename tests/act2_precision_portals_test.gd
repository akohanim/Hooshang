extends Node
## Integration only: staged threshold crossings, with strict death-count checks.
var failures := 0
var deaths := 0
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	var world = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_Hub"
	# This fixture grants rescue solely to exercise every unlocked portal.
	# The authored reunion otherwise begins and locks input for dialogue.
	# Its real playback/skip contract is covered by cell_reunion_test.
	world.get_node("CellReunion").free()
	add_child(world)
	await frames(12)
	world.player.died.connect(func():
		deaths+=1
		print("PORTAL DEATH ",world.current_room.name," at=",world.player.global_position-world.current_room.global_position," checkpoint=",world._checkpoint-world.current_room.global_position))
	world.collected.assign(world.IDS)
	world.inserted.assign(world.IDS)
	world.rescued = true
	world.rescue_started = true
	world._refresh()
	var expected: Dictionary={}
	for wing in ["R","G","B","Y"]:
		var route=["Prison_Hub","Prison_%s01" % wing,"Prison_%s02" % wing,"Prison_%s03" % wing,"Prison_%s04" % wing,"Prison_Hub"]
		for i in range(route.size()-1):
			for pair in [[route[i],route[i+1]],[route[i+1],route[i]]]:
				expected[pair[0]+">"+pair[1]]=""
	var actual: Dictionary={}
	for portal in world.portals:
		var edge=str(portal.from.name)+">"+str(portal.to.name)
		check(not actual.has(edge),"no duplicate portal "+edge)
		actual[edge]=portal.gate
	check(actual==expected,"exact directed room pairs and key gates match all four loops")
	for prop in world.props:
		if prop.kind=="TimedGate":
			world.timers.start(prop.puzzle_id)
			world.timers.bank(prop.puzzle_id)
		elif prop.kind in ["CircuitNode","FloodValve"]:
			world.circuits.touch(prop.circuit_id,prop.entity_iid)
	var crossings:=0
	for portal in world.portals:
		crossings+=1
		print("PORTAL ",portal.from.name," -> ",portal.to.name)
		world._enter_room(portal.from,true)
		world.player.respawn(world.spawn_point_for(portal.from))
		world._portal_cooldown = 0.0
		await frames(4)
		# Set up just outside the strip, then cross its boundary. Destination and
		# safe landing are resolved exclusively by the mission's physics callback.
		var deaths_before:=deaths
		world.player.global_position = portal.center-portal.direction*16
		await frames(1)
		world.player.global_position = portal.center
		world.player.velocity = Vector2.ZERO
		await frames(65)
		print("ARRIVAL ",world.current_room.name," at=",world.player.global_position-world.current_room.global_position," state=",world.player.state_name())
		check(world.current_room == portal.to,"crossing %s -> %s" % [portal.from.name,portal.to.name])
		check(world.room_rect(portal.to).encloses(world.player.hitbox_rect()),"arrival body clear of world boundary")
		await frames(45)
		check(world.current_room == portal.to,"idle must not bounce through return")
		check(deaths==deaths_before,"arrival and idle cause no unplanned death")
		var checkpoint: Vector2=world._checkpoint
		world.player.die()
		await frames(90)
		check(world.current_room == portal.to and world.player.state != Player.State.DEAD,"death keeps destination checkpoint")
		check(world._checkpoint==checkpoint,"death preserves the room entry checkpoint")
		check(deaths==deaths_before+1,"one requested death causes exactly one death")
	world.queue_free()
	await frames(3)
	print("PRECISION CASTLE PORTALS: ",crossings," expected crossings/idle/death checks; ",failures," failures")
	get_tree().quit(1 if failures else 0)
