extends Node
var failures := 0
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	# Dedicated disposable directory; never writes a player's real save slot.
	SaveGame.dir = "user://prison_acceptance_saves"
	SaveGame.erase(0)
	SaveGame.unbind()
	SaveGame._bind(0)
	LdtkWorld.debug_start_room = "Prison_B03"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(15)
	var world = Screen.current
	var key = world.props.filter(func(p): return p.kind=="Key" and p.key_id=="Blue")[0]
	world.collect_key("Red",key.global_position)
	world.collect_key("Blue",key.global_position)
	world.inserted.append("Red")
	check(SaveGame.save_now(),"prison save written")
	SaveGame.unbind()
	check(SaveGame.resume(0),"prison save resumed from disk")
	await frames(30)
	world = Screen.current
	check(str(world.current_room.name)=="Prison_B03","saved room restored")
	check(world.collected.size()==2 and world.collected.has("Red") and world.collected.has("Blue"),"collected keys restored")
	check(world.inserted==["Red"],"inserted lock restored separately")
	check(world.player.is_on_floor() and not world.player.swimming(),"dry post-key checkpoint restored with full footing")
	for prop in world.props:
		if prop.kind=="ShortcutDoor": check(prop.barrier.disabled == (prop.key_id in ["Red","Blue"]),"shutter state restored")
	world.player.die()
	await frames(90)
	check(world.collected.size()==2 and str(world.current_room.name)=="Prison_B03","resumed keys and checkpoint survive another death")
	SaveGame.unbind()
	SaveGame.erase(0)
	print("PRISON SAVE: ",failures," failures")
	get_tree().quit(1 if failures else 0)
