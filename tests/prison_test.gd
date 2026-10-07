extends Node
var failures := 0
var world: Node
func check(ok: bool, label: String) -> void:
	print("  PASS " if ok else "  FAIL ",label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func _ready() -> void:
	SaveGame.unbind()
	world = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_Hub"
	add_child(world)
	var completed := [0]
	world.prison_completed.connect(func(): completed[0] += 1)
	await frames(15)
	check(world.rooms.filter(func(r): return world.is_prison(r)).size()==17,"17 prison rooms imported")
	check(world.portals.size()==40,"20 reciprocal adjacency links")
	check(world.props.filter(func(p): return p.kind=="Key").size()==4,"four keys")
	check(world.props.filter(func(p): return p.kind=="ShortcutDoor" and p.key_id in world.IDS).size()==8,"all eight reference-driven shutters resolve")
	check(world.player.is_on_floor(),"hub spawn has solid footing")
	check(world.player.childhood_momentum,"real Act 2 movement applied")
	for room in world.rooms:
		if not world.is_prison(room): continue
		world._enter_room(room,true)
		world.player.respawn(world.spawn_point_for(room))
		await frames(25)
		check(world.current_room == room and world.player.state != Player.State.DEAD,"safe spawn "+str(room.name))
	# Every directed doorway has a clear arrival outside its reciprocal strip.
	for portal in world.portals:
		var at: Vector2 = world._safe_landing(portal.to,portal.center+portal.direction*24)
		check(world.room_rect(portal.to).encloses(Rect2(at-Vector2(4.5,6),Vector2(9,12))),"arrival fits "+str(portal.to.name))
	# Exercise actual contact pickup, then death and checkpoint respawn.
	for prop in world.props:
		if prop.kind != "Key": continue
		world._enter_room(prop.get_parent().get_parent(),false)
		world.player.respawn(prop.global_position)
		world._portal_cooldown = 5.0
		await frames(8)
		check(world.collected.has(prop.key_id),"contact banks "+prop.key_id)
		world.player.die()
		await frames(55)
		check(world.collected.has(prop.key_id) and not prop.visible,"death retains "+prop.key_id)
	check(not world.rescued,"four pickups alone do not rescue")
	var state: Dictionary = world.save_state()
	check(state.prison.collected.size()==4,"save includes keys")
	world._enter_room(world._cage.get_parent().get_parent(),true)
	world.player.respawn(world._cage.global_position+Vector2(-38,14))
	await frames(220)
	check(world.rescued and world.inserted.size()==4,"cage contact opens all locks and rescues")
	check(not world.player.input_locked,"rescue restores controls")
	world.finish_rescue()
	check(completed[0]==1,"level-complete event fires exactly once")
	var actor = world._cage.get_parent().get_node("PrisonJamshid")
	check(actor.position.x > world._cage.position.x+32,"Jamshid walks out past the cage")
	check(world._hud.get_parent().custom_viewport == get_tree().root and world._hud.get_parent().scale == Vector2(0.25,0.25),"HUD uses the separate UI surface at the project scale")
	world.queue_free()
	await frames(3)
	print("PRISON TEST: ",failures," failures")
	get_tree().quit(1 if failures else 0)
