extends Node
var failures := 0
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_15"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(12)
	var player := world.player
	player.set_physics_process(false)
	var shadow: Darkshang = get_tree().get_first_node_in_group("darkshang")
	var visited := 0
	for i in range(15,25):
		var room: Node2D
		for candidate in world.rooms:
			if str(candidate.name)=="Level_%d" % i: room=candidate
		check(room != null,"Level_%d exists" % i)
		if room==null: continue
		visited += 1
		world._enter_room(room,true)
		await frames(3)
		var chamber := room.get_node("DarknessRoom")
		check(chamber.chaser==shadow and shadow.state==Darkshang.State.FOLLOWING,"%s binds physical pursuing boss" % room.name)
		check(shadow._holding_entry,"%s retains safe entry grace" % room.name)
		player.global_position.x -= 24
		await frames(4)
		check(not shadow._holding_entry and shadow.visible and shadow._visual != null,"%s physical body appears on departure" % room.name)
		var before := shadow.global_position
		player.global_position.x -= 24
		await frames(25)
		check(shadow.global_position.distance_to(before)>1,"%s baseline pursuit moves" % room.name)
		shadow.reset_to_checkpoint(world.spawn_point_for(room))
		check(shadow.state==Darkshang.State.FOLLOWING and shadow._holding_entry,"%s retry keeps pursuit armed" % room.name)
	check(visited==10,"all ten escape rooms tested")
	for room in world.rooms:
		if str(room.name)=="Level_25":
			world._enter_room(room,true)
			await frames(2)
			check(shadow.state==Darkshang.State.FOLLOWING and shadow._holding_entry,"final room retains pursuing actor and entrance grace")
			player.global_position.x -= 24
			await frames(4)
			check(shadow.visible and not shadow._holding_entry,"Darkshang follows player visibly into final room")
			var before := shadow.global_position
			player.global_position.x -= 16
			await frames(25)
			check(shadow.global_position.distance_to(before)>1,"pursuit continues toward cubicle")
			player.invulnerable_timer = 0
			player.die()
			for retry_frame in 180:
				await frames(1)
				if player.state != Player.State.DEAD: break
			await frames(4)
			player.set_physics_process(false)
			check(shadow.state==Darkshang.State.FOLLOWING and shadow._holding_entry,"death in final room rearms pursuit")
			player.global_position.x -= 24
			await frames(4)
			check(shadow.visible,"retry lets Darkshang enter again")
			var beats := world.get_node("Act1Beats")
			# Walk across the ending line; a large teleport intentionally rearms
			# the entry hold and is not how the cubicle is reached in play.
			while player.global_position.x > beats.chase_ends_past_x:
				player.global_position.x -= 2
				await frames(1)
			await frames(3)
			check(shadow.state==Darkshang.State.DORMANT and shadow.visible and player.input_locked,"cubicle ending stops visible pursuer for dissolve")
			await frames(110)
			check(not shadow.visible,"ending dissolves Darkshang after following player home")
	print("BASELINE PURSUIT: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
