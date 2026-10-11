extends Node
## Staged visual states only; not earned route evidence.
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func capture(name: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	Screen.viewport.get_texture().get_image().save_png("res://output/prison_challenge/visual_cleanup/"+name+".png")
	get_tree().root.get_texture().get_image().save_png("res://output/prison_challenge/visual_cleanup/"+name+"_ui.png")
func _ready() -> void:
	SaveGame.unbind()
	for room_name in ["Prison_G01","Prison_G02","Prison_G03","Prison_R03","Prison_B03","Prison_Y03"]:
		LdtkWorld.debug_start_room=room_name
		Screen.load_scene("res://ldtk/Act2World.tscn")
		await frames(20)
		var world=Screen.current
		await capture(room_name+"_closed")
		for prop in world.props:
			if prop.get_parent().get_parent()!=world.current_room:continue
			if prop.kind=="TimedGate":
				world.timers.start(prop.puzzle_id)
				world.timers.bank(prop.puzzle_id)
			elif prop.kind in ["CircuitNode","FloodValve"]:world.circuits.touch(prop.circuit_id,prop.entity_iid)
		await frames(4)
		await capture(room_name+"_open")
	Screen.current.queue_free()
	await frames(3)
	get_tree().quit()
