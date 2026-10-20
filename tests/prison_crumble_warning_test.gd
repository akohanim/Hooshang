extends Node
## Staged landing, then natural contact/countdown/collapse. No warning-state grants.
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
	LdtkWorld.debug_start_room="Prison_R03"
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
	world.player.respawn(shelf.global_position+Vector2(0,-22))
	var seen: Array[int]=[]
	for i in 120:
		await frames(1)
		if shelf._falling:break
		if not shelf._spent:continue
		var frame=CrumblingPlatform.FRAMES_CHILDHOOD.find(block.texture)
		if not seen.has(frame):
			seen.append(frame)
			check(shelf.get_collision_layer_value(1),"warning preserves solid collision")
			await capture("warning_%d" % frame)
	check(seen==[0,1,2],"contact progresses through all three warning stages")
	check(shelf._falling and not shelf.get_collision_layer_value(1),"warning ends in real collapse")
	await frames(30)
	await capture("collapsed")
	world.player.respawn(room.global_position+Vector2(40,154))
	await frames(5)
	Input.action_press("move_up")
	await frames(4)
	Input.action_release("move_up")
	check(not shelf._spent and shelf.get_collision_layer_value(1),"lever restores collision")
	check(block.texture==CrumblingPlatform.FRAMES_CHILDHOOD[0],"lever restores the intact Act 2 crumble artwork")
	await capture("restored")
	print("CRUMBLE WARNING: ",failures," failures; seen=",seen)
	get_tree().quit(1 if failures else 0)
