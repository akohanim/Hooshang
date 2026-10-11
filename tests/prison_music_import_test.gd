extends Node
## Staged contact fixture; these are not earned room routes.
var failures:=0
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_G03"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	for name in ["Prison_G03","Prison_Y03"]:
		var room=world.rooms.filter(func(r):return str(r.name)==name)[0]
		world._enter_room(room,true);await frames(10)
		var pads=world.props.filter(func(p):return p.kind=="MusicalTile" and p.get_parent().get_parent()==room)
		pads.sort_custom(func(a,b):return a.note_index<b.note_index)
		check(pads.size()==5,name+" has five imported notes")
		var gate=world.props.filter(func(p):return p.kind=="MusicalGate" and p.get_parent().get_parent()==room)[0]
		check(not gate.barrier.disabled,name+" starts physically locked")
		for pad in pads:
			check(not pad.is_in_group("note_tile"),"prison note excluded from Act1 glow/exit manager")
			if name=="Prison_G03":
				# The library's ceiling notes are struck from below. Stage on
				# their actual supporting banks/stones, then use a real jump.
				world.player.respawn(pad.global_position+Vector2(0,26))
				await frames(3)
				Input.action_press("jump");await frames(8)
				Input.action_release("jump");await frames(12)
			else:
				world.player.respawn(pad.global_position+Vector2(0,-28))
				await frames(32)
			check(world.circuits.touched(gate.circuit_id,pad.entity_iid),name+" actual contact note "+str(pad.note_index))
		await frames(4)
		check(world.circuits.solved(gate.circuit_id) and gate.barrier.disabled,name+" melody opens its physical gate")
		await get_tree().process_frame
		RenderingServer.force_draw()
		Screen.viewport.get_texture().get_image().save_png("res://output/prison_precision/music_foundation/"+name+".png")
	print("PRISON MUSIC IMPORT: ",failures," failures; staged contacts, not routes")
	get_tree().quit(1 if failures else 0)
