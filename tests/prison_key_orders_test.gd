extends Node
## Exhaustive key/state fixtures, not 24 earned gameplay traversals.
var failures := 0
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool,label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func permutations(values: Array) -> Array:
	if values.is_empty():return [[]]
	var result: Array=[]
	for value in values:
		var rest=values.duplicate()
		rest.erase(value)
		for tail in permutations(rest):result.append([value]+tail)
	return result
func _ready() -> void:
	SaveGame.unbind()
	var orders=permutations(["Red","Green","Blue","Gold"])
	check(orders.size()==24,"all 24 distinct orders generated")
	for order in orders:
		var world=load("res://ldtk/Act2World.tscn").instantiate()
		world.debug_start_room="Prison_Hub"
		world.get_node("CellReunion").free()
		add_child(world)
		await frames(10)
		var cage=world.props.filter(func(p):return p.kind=="Cage")[0]
		for i in order.size():
			world.collect_key(order[i],world.player.global_position)
			await frames(3)
			check(world.collected.size()==i+1,"exact pickup count "+str(order))
			for prop in world.props:
				if prop.kind=="ShortcutDoor":check(prop.barrier.disabled==world.collected.has(prop.key_id),"only collected key opens shortcut "+str(order))
			await world.insert_keys(cage)
			check(world.inserted.size()==i+1,"each owned lock inserted once "+str(order))
			if i==1:
				world.player.die()
				await frames(90)
				check(world.collected.size()==2 and world.inserted.size()==2,"partial keys/locks survive death "+str(order))
			check(world.rescued==(i==3),"rescue requires exactly four keys "+str(order))
		check(world.circuits.save_completed().is_empty() and world.timers.save_completed().is_empty(),"keys never implicitly solve local puzzles")
		check(world.rescued and cage.barrier.disabled,"four keys open physical cage")
		world.queue_free()
		await frames(3)
	print("PRISON KEY ORDERS: ",orders.size()," state permutations; ",failures," failures")
	get_tree().quit(1 if failures else 0)
