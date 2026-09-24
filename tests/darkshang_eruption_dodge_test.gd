extends Node
var world: LdtkWorld
var died := false
var failures := 0
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func release() -> void:
	Input.action_release("move_left")
	Input.action_release("jump")
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_15"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(12)
	var player := world.player
	player.died.disconnect(world._on_player_died)
	player.died.connect(func(): died=true)
	var shadow: Darkshang = get_tree().get_first_node_in_group("darkshang")
	shadow.set_physics_process(false)
	shadow.buffer.set_physics_process(false)
	# Keep the original authored-pattern dodge controls; reactive targeting and
	# its dodge window are exercised by darkshang_targeted_eruption_test.
	for strip in get_tree().get_nodes_in_group("shadow_eruption"):
		strip.targeting_radius = 0
	for name in ["Level_15","Level_17"]:
		var room: Node2D
		for candidate in world.rooms:
			if str(candidate.name)==name: room=candidate
		world._enter_room(room,true)
		await frames(4)
		room.get_node("DarknessRoom").set_physics_process(false)
		for dodge in [false,true]:
			release()
			for item in room.get_node("Entities").get_children():
				if item.has_method("reset") and (item.is_in_group("shadow_eruption") or item.is_in_group("darkshang_power_trigger")): item.reset()
			player.respawn(room.global_position+(Vector2(290,90) if name=="Level_15" else Vector2(428,30)))
			player.input_locked=false
			await frames(4)
			shadow._holding_entry=false
			shadow.visible=true
			shadow.global_position=room.global_position+Vector2(32,48)
			shadow._tick_power_entry(.5)
			died=false
			Input.action_press("move_left")
			for frame in 115:
				if dodge and frame==(44 if name=="Level_15" else 66): Input.action_press("jump")
				if dodge and frame==(60 if name=="Level_15" else 80): Input.action_release("jump")
				await frames(1)
				if died:break
				if player.global_position.x-room.global_position.x < (184 if name=="Level_15" else 304):break
			release()
			print(name," dodge=",dodge," died=",died," position=",player.global_position-room.global_position)
			check(not died if dodge else died,"%s %s" % [name,"jump clears eruption" if dodge else "ignoring warning is dangerous"])
	# The upper climbing landing has a real 16px refuge between its two strips.
	var climb_room: Node2D
	for candidate in world.rooms:
		if str(candidate.name)=="Level_16": climb_room=candidate
	world._enter_room(climb_room,true)
	await frames(4)
	for dodge in [false,true]:
		release()
		var trigger: Node2D
		for item in climb_room.get_node("Entities").get_children():
			if item.is_in_group("shadow_eruption"): item.reset()
			if item.is_in_group("darkshang_power_trigger") and item.encounter_id=="L16_Climb": trigger=item
		player.respawn(climb_room.global_position+Vector2(184,162))
		player.input_locked=false
		await frames(6)
		shadow._holding_entry=false
		shadow.visible=true
		shadow.global_position=climb_room.global_position+Vector2(32,48)
		shadow._tick_power_entry(.5)
		died=false
		trigger.activate()
		for frame in 145:
			if dodge and frame==75:
				Input.action_press("jump")
				Input.action_press("move_left")
			if dodge and frame==89: release()
			await frames(1)
			if died: break
		print("Level_16 dodge=",dodge," died=",died," position=",player.global_position-climb_room.global_position)
		check(not died and player.is_on_floor() if dodge else died,"Level_16 %s" % ("jump reaches safe gap" if dodge else "standing on second strip is dangerous"))
	release()
	print("ERUPTION DODGES: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
