extends Node
## Staged unlocked portal fixtures, followed by real jump/walk inputs both ways.
const OUT="res://output/prison_precision/entrance_ledges"
var failures:=0
var deaths:=0
var results: Array=[]
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room="Prison_Hub"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world=Screen.current
	world.player.died.connect(func():deaths+=1)
	# Isolate aperture geometry from progression, explicitly staged.
	world.collected.assign(world.IDS);world.rescue_started=true
	for prop in world.props:
		if prop.kind=="TimedGate":world.timers.start(prop.puzzle_id);world.timers.bank(prop.puzzle_id)
	for id in world.circuits._requirements:
		for member in world.circuits._requirements[id]:world.circuits.touch(id,member)
	world._refresh();await frames(4)
	var placements=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/placements.json"))
	for entry in placements:
		var upper=world.rooms.filter(func(r):return str(r.name)==entry.room)[0]
		var x: float=entry.ledge[0]
		var portal=world.portals.filter(func(p):return p.from==upper and p.direction==Vector2.DOWN and absf(p.center.x-upper.global_position.x-x-20)<1)[0]
		var lower=portal.to
		world._enter_room(lower,true);await frames(8)
		world.player.respawn(Vector2(upper.global_position.x+x+12,lower.global_position.y+18))
		await frames(50)
		Input.action_press("jump")
		for i in 120:
			await frames(1)
			if world.current_room==upper:break
		Input.action_release("jump");await frames(50)
		var at: Vector2=world.player.global_position-upper.global_position
		var landed: bool=world.current_room==upper and world.player.is_on_floor() and absf(at.y-(float(entry.ledge[1])-6))<2 and at.x>=x and at.x<x+16
		check(landed,entry.room+" catches upward entry on partial ledge")
		await get_tree().process_frame
		RenderingServer.force_draw()
		Screen.viewport.get_texture().get_image().save_png(OUT+"/"+entry.room+"_%d.png" % int(x))
		Input.action_press("move_right")
		for i in 120:
			await frames(1)
			if world.current_room==lower:break
			# Step into the open half, then let gravity carry the return.
			# Holding right throughout the fall tests running across the hole.
			if world.player.global_position.x-upper.global_position.x>=x+24:
				Input.action_release("move_right")
		Input.action_release("move_right");await frames(35)
		var descended: bool=world.current_room==lower
		check(descended,entry.room+" side gap allows natural downward return")
		results.append({"upper":entry.room,"lower":str(lower.name),"landed":landed,"descended":descended,"landing":str(at),"end_room":str(world.current_room.name),"end_at":str(world.player.global_position-world.current_room.global_position)})
	check(deaths==0,"portal fixtures have no deaths")
	FileAccess.open(OUT+"/routes.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"deaths":deaths,"staged":true,"routes":results},"\t"))
	print("PARTIAL ENTRANCE LEDGES: ",failures," failures; deaths=",deaths)
	get_tree().quit(1 if failures else 0)
