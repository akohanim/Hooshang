extends Node
## Exhaustive progression graph, authored fields, and physical shutters.
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	var world = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_Hub"
	add_child(world)
	for i in 12: await get_tree().physics_frame
	world.player.set_physics_process(false)
	world.set_physics_process(false)
	var hub = world.current_room
	for mask in 16:
		world.collected.clear()
		for i in 4:
			if mask & (1 << i): world.collected.append(world.IDS[i])
		world._refresh()
		await get_tree().physics_frame
		await get_tree().physics_frame
		var reached := {"Prison_Hub":true}
		var queue: Array = [hub]
		while not queue.is_empty():
			var room = queue.pop_front()
			for portal in world.portals:
				if portal.from != room or portal.gate != "" and not world.collected.has(portal.gate): continue
				if not reached.has(str(portal.to.name)):
					reached[str(portal.to.name)] = true
					queue.append(portal.to)
		for pair in [["R","Red"],["G","Green"],["B","Blue"],["Y","Gold"]]:
			check(reached.has("Prison_%s03" % pair[0]),"key reachable for subset %d" % mask)
			check(reached.has("Prison_%s04" % pair[0]) == world.collected.has(pair[1]),"return gating subset %d" % mask)
		for prop in world.props:
			if prop.kind == "ShortcutDoor": check(prop.barrier.disabled == world.collected.has(prop.key_id),"physical shutter matches state")
	check(world._cage.lock_ids().size()==4,"four distinct authored cage slots")
	var orders := permutations(["Red","Green","Blue","Gold"])
	for order in orders:
		world.collected.clear()
		world.inserted.clear()
		world.rescued = false
		world.rescue_started = false
		for id in order:
			world.collect_key(id,world.player.global_position)
			world.collect_key(id,world.player.global_position)
		check(world.collected.size()==4,"duplicate pickup idempotent in every order")
		var saved: Dictionary = world.save_state().prison
		check(saved.collected==world.collected and saved.inserted.is_empty(),"saved mission is independent of pickup order")
	world.queue_free()
	for i in 3: await get_tree().physics_frame
	print("PRISON GRAPH: 16 subsets, 24 orders; ",failures," failures")
	get_tree().quit(1 if failures else 0)
func permutations(items: Array) -> Array:
	if items.is_empty(): return [[]]
	var result := []
	for value in items:
		var rest := items.duplicate()
		rest.erase(value)
		for tail in permutations(rest): result.append([value]+tail)
	return result
