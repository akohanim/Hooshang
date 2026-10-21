extends Node
## Natural landing with a deterministic warning clock; no warning-state grants.
var failures := 0
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png("res://output/prison_precision/warnings/"+label+".png")
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_R02"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	var room=world.current_room
	var shelves=world.props.filter(func(p):return p.kind=="CrumblingShelf" and p.get_parent().get_parent()==world.current_room)
	if shelves.is_empty():
		push_error("Imported prison contains no CrumblingShelf; refresh Act2 import")
		get_tree().quit(1)
		return
	var shelf=shelves[0]
	var block=shelf._visual.get_child(0)
	check(block.texture==CrumblingPlatform.FRAMES_CHILDHOOD[0],"intact shelf wears Act 2's crumble art")
	# Exercise the complete warning cycle independently of this room's authored
	# instant-drop timing. The lifecycle test preserves the real imported timing.
	shelf.crumble_time=0.6
	shelf.set_process(false) # Headless idle delta need not match physics frames.
	world.player.respawn(shelf.global_position+Vector2(0,-22))
	var seen: Array[int]=[]
	for i in 120:
		await frames(1)
		shelf._process(1.0/60.0)
		if shelf._falling:break
		if not shelf._spent:continue
		var frame=CrumblingPlatform.FRAMES_CHILDHOOD.find(block.texture)
		if not seen.has(frame):
			seen.append(frame)
			check(shelf.get_collision_layer_value(1),"warning preserves solid collision")
			await capture("warning_%d" % frame)
	check(seen==[0,1,2],"contact progresses through all three warning stages")
	check(shelf._falling and not shelf.get_collision_layer_value(1),"warning ends in real collapse")
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	await frames(30)
	await capture("collapsed")
	var gate=world.timed_reference(shelf.fields.get("Gate",""))
	world.timers.start(str(gate.fields.get("PuzzleId","")))
	check(shelf._falling and not shelf.get_collision_layer_value(1),"lever leaves the shelf collapsed")
	world.player.die()
	for i in 120:
		await frames(1)
		if world.player.state!=Player.State.DEAD and not shelf._falling:break
	check(not shelf._spent and shelf.get_collision_layer_value(1),"respawn restores collision")
	check(block.texture==CrumblingPlatform.FRAMES_CHILDHOOD[0],"respawn restores the intact Act 2 crumble artwork")
	await capture("restored")
	print("CRUMBLE WARNING: ",failures," failures; seen=",seen)
	get_tree().quit(1 if failures else 0)
