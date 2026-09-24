extends Node
var world: LdtkWorld
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_15"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(12)
	var player := world.player
	player.set_physics_process(false)
	var shadow: Darkshang = get_tree().get_first_node_in_group("darkshang")
	shadow.set_physics_process(false)
	shadow.buffer.set_physics_process(false)
	for node in get_tree().get_nodes_in_group("darkshang_power_trigger") + get_tree().get_nodes_in_group("shadow_eruption"):
		node.set_physics_process(false)
	var counts := {"Level_15":1,"Level_16":3,"Level_17":4,"Level_18":0}
	for room in world.rooms:
		if not counts.has(str(room.name)): continue
		world._enter_room(room,true)
		await frames(3)
		var strips: Array = []
		var triggers: Array = []
		for node in room.get_node("Entities").get_children():
			if node.is_in_group("shadow_eruption"): strips.append(node)
			if node.is_in_group("darkshang_power_trigger"): triggers.append(node)
		check(strips.size()==counts[str(room.name)],"%s eruption count" % room.name)
		for strip in strips:
			var bottom: Vector2 = strip.global_position+Vector2(0,strip.size.y/2)
			var query := PhysicsRayQueryParameters2D.create(bottom+Vector2(0,-1),bottom+Vector2(0,2),1)
			check(not world.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"%s strip rests on existing platform %s" % [room.name,strip.position])
			var shape := RectangleShape2D.new()
			shape.size = strip.size-Vector2(.2,.2)
			var probe := PhysicsShapeQueryParameters2D.new()
			probe.shape = shape
			probe.transform = Transform2D(0,strip.global_position)
			probe.collision_mask = 1
			check(world.get_world_2d().direct_space_state.intersect_shape(probe).is_empty(),"%s eruption volume above ground" % room.name)
		for trigger in triggers:
			trigger.reset()
			player.input_locked = false
			player.global_position = trigger.global_position+Vector2(trigger.size.x/2+16,0)
			trigger._physics_process(.016)
			check(trigger.armed,"%s approach arms trigger" % room.name)
			shadow._holding_entry = false
			shadow.visible = true
			shadow.state = Darkshang.State.FOLLOWING
			shadow._player = player
			shadow.global_position = trigger.global_position+Vector2(80,-24) if trigger.power==0 else room.global_position+Vector2(32,48)
			shadow._tick_power_entry(.5)
			shadow._locked_charge.cancel()
			var pursuit_position := shadow.global_position
			player.global_position = trigger.global_position
			trigger._physics_process(.016)
			check(trigger.spent,"%s crossing activates %s" % [room.name,trigger.name])
			if trigger.power == 0:
				check(not room.is_ancestor_of(shadow) and shadow._locked_charge.phase in [1,4],"Level_18 uses shared Darkshang from another room")
				check(shadow.global_position.is_equal_approx(pursuit_position),"charge launches from pursuit, ignoring old fixed fields")
				var expected_direction := Vector2(signf(player.global_position.x-pursuit_position.x),0)
				check(shadow._locked_charge.direction.is_equal_approx(expected_direction),"charge prepares a horizontal direction")
				if shadow._locked_charge.phase == 4:
					shadow._locked_charge.tick(.46,shadow,player)
				shadow._locked_charge.tick(trigger.warning_time+.01,shadow,player)
				var reach: float = shadow._locked_charge.distance_left
				var origin := shadow.global_position
				expected_direction = shadow._locked_charge.direction
				player.global_position = origin+Vector2(0,1000)
				shadow._locked_charge.tick(2,shadow,player)
				var travelled := origin.distance_to(shadow.global_position)
				print("charge travel ",trigger.position," = ",travelled)
				check(travelled > 0 and travelled <= reach+.01,"live charge travels along extended range")
				check(absf((shadow.global_position-origin).cross(expected_direction))<.01,"charge remains on locked line")
				shadow._locked_charge.cancel()
			else:
				var matched := 0
				for strip in strips:
					if strip.encounter_id == trigger.encounter_id:
						matched += 1
						check(strip.elapsed==0 and is_equal_approx(strip.delay,strip.sequence*trigger.sequence_delay),"linked eruption sequence scheduled")
						strip.reset()
				check(matched>0,"trigger has linked strips")
			trigger.reset()
			check(not trigger.spent and not trigger.armed,"retry rearms safely")
		if room.name=="Level_18": check(triggers.size()==3,"three charge encounters across Level_18")
	print("DARKSHANG 15–18: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
