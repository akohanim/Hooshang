extends Node
var failures:=0
var world:LdtkWorld
var seq:NoteSequence
func frames(n:int)->void:
	for i in n:await get_tree().physics_frame
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _ready()->void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_8"
	world=load("res://ldtk/Act1World.tscn").instantiate();add_child(world)
	await frames(12)
	seq=world.get_node("NoteSequence")
	for name in ["Level_7","Level_8","Level_9","Level_13","Level_18"]:
		var room:Node2D
		for r in world.rooms:
			if r.name==name:room=r
		check(room!=null,"%s is restored to the route" % name)
		if room==null:continue
		world._enter_room(room,true)
		await frames(3)
		world.player.respawn(world.spawn_point_for(room))
		world.player.input_locked=true
		world.player.set_physics_process(false)
		world.set_physics_process(false)
		var portal=seq._exits[room]
		check(portal.gate is SecurityGate and portal.gate.barrier.shape.size==Vector2(32,32),"%s uses the shared doorway shutter" % name)
		check(room.get_meta("exit_locked") and not portal.gate.barrier.disabled,"%s starts locked" % name)
		check(seq.total==5,"%s has a local five-note sequence" % name)
		world._on_exit_reached(world.player,world._exit_in(room))
		check(not world._transitioning,"%s cannot bypass the locked gate" % name)
		var pads={}
		for t in seq._room_tiles:pads[t.note_index]=t
		seq._on_tile_stepped(pads[1]);seq._on_tile_stepped(pads[3])
		check(seq.progress==0 and not portal.gate.authorized and not world.player.has_glow,"%s wrong order grants neither glow nor exit" % name)
		seq.reset()
		for i in range(1,5):seq._on_tile_stepped(pads[i])
		check(not portal.gate.authorized and portal.gate.completed==4,"%s four notes are insufficient" % name)
		for t in get_tree().get_nodes_in_group("note_tile"):
			if not room.is_ancestor_of(t) and t.note_index==5:
				seq._on_tile_stepped(t);break
		check(seq.progress==4,"%s another room cannot finish its melody" % name)
		seq._on_tile_stepped(pads[5])
		await frames(90)
		check(portal.gate.authorized and portal.gate.barrier.disabled and not room.get_meta("exit_locked"),"%s full melody opens the exit" % name)
		check(world.player.has_glow,"%s full melody grants player glow" % name)
		check(world.get_node("CanvasModulate").color.is_equal_approx(world._ambient_color) and portal.spill.energy>1,"%s open door lights the room and spills light" % name)
		world.player.invulnerable_timer=0
		world.player.die();await frames(2)
		check(not world.player.has_glow and not portal.gate.authorized,"%s death rearms both rewards" % name)
		await frames(70)
		world.player.input_locked=false
	print("MUSIC EXIT: %d failures" % failures)
	get_tree().quit(failures)
