extends "res://tests/darkness_contract_test.gd"
## Contract tests use real imported collision and floor contacts. Full traversal
## remains in darkness_playthrough_test, with all moving thoughts active.
func _ready()->void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_1"
	world=load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(8)
	player=world.player
	player.input_locked=false
	var reference:Color=world.get_node("CanvasModulate").color
	for name in ["Level_V10","Level_V11","Level_V12","Level_V13","Level_V14"]:
		var c:=await open(name)
		check(c.e.mode=="security","%s imports security puzzle" % name)
		if c.e.mode!="security":continue
		check(c.phase_door==null and c.bridges.is_empty(),"%s has no barrier across the room" % name)
		check(c.gate_shape.shape.size==Vector2(32,32),"%s gate covers only the doorway" % name)
		check(c.gate.position==Vector2(c.recipe.width-32 if c.recipe.direction>0 else 0,c.recipe.route.back()[1]-32),"%s gate is on the exit deck" % name)
		var middle:Vector2=c.gate.global_position+Vector2(0,16)
		var ray:=PhysicsRayQueryParameters2D.create(middle-Vector2(12,0),middle+Vector2(44,0),1)
		var hit:=world.get_world_2d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==c.gate,"%s closed shutter physically blocks passage" % name)
		for offset in [-24,28]:
			ray.from=middle+Vector2(-12,offset);ray.to=middle+Vector2(44,offset)
			hit=world.get_world_2d().direct_space_state.intersect_ray(ray)
			check(hit.is_empty() or hit.collider!=c.gate,"%s space outside the doorway remains clear (%d)" % [name,offset])
		for phase in 4:
			c._set_phase(phase)
			c._physics_process(.016)
			check(world.get_node("CanvasModulate").color==reference,"%s phase %d matches Level_1 brightness" % [name,phase])
		# A physically bounded gate must not make a jump around its top a bypass.
		var exit:Node2D=room(name).get_node("Entities").get_children().filter(func(n):return n.is_in_group("exit"))[0]
		world._on_exit_reached(player,exit)
		await frames(1)
		check(not world._transitioning and world.current_room==room(name),"%s locked exit rejects bypass" % name)
		c.set_physics_process(false)
		# Charge does not care about the manifestation phase, and touching a
		# future terminal cannot erase previous progress.
		for i in c.e.terminals.size():
			var point:Array=c.e.terminals[i]
			var local:=Vector2(point[0],point[1]-6)
			player.respawn(room(name).global_position+local)
			await frames(8)
			check(player.is_on_floor(),"%s terminal %d stands on a real deck" % [name,i+1])
			c._set_phase(i%4)
			c._puzzle(local,float(c.e.charge_seconds)*.5)
			check(c.step==i and c.terminals[i].progress>0 and c.terminals[i].progress<1,"%s terminal %d shows partial charge" % [name,i+1])
			c._puzzle(local,float(c.e.charge_seconds)*.51)
			check(c.step==i+1 and c.terminals[i].charged,"%s terminal %d lights its completion check" % [name,i+1])
			if i==0:
				var next:Array=c.e.terminals.back() if c.e.terminals.size()>2 else c.e.terminals[0]
				c._puzzle(Vector2(next[0],next[1]-6),2)
				check(c.step==1,"%s wrong terminal does not reset progress" % name)
				# Use the real death/reset signal; no checkpoint is needed to bank power.
				world._checkpoint=world.spawn_point_for(room(name))
				player.die()
				await frames(90)
				check(c.step==1,"%s death preserves charged terminal" % name)
				c.set_physics_process(false)
		await frames(3)
		check(c.solved and c.gate_shape.disabled and not room(name).get_meta("exit_locked"),"%s complete circuit opens and authorizes exit" % name)
		c.security_gate._process(1)
		check(c.security_gate.slide==1,"%s shutters visibly retract" % name)
	print("SECURITY GATE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
