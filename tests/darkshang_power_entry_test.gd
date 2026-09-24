extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func _ready() -> void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_15"
	var world: LdtkWorld=load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(12)
	var player:=world.player
	player.set_physics_process(false)
	var shadow: Darkshang=get_tree().get_first_node_in_group("darkshang")
	for i in range(15,25):
		var room: Node2D
		for candidate in world.rooms:
			if str(candidate.name)=="Level_%d" % i: room=candidate
		world._enter_room(room,true)
		await frames(4)
		player.input_locked=false
		var spawn:=player.global_position
		var trigger=preload("res://scenes/props/chase/powers/ShadowEruptionTrigger.tscn").instantiate()
		var strip=preload("res://scenes/props/chase/powers/ShadowEruption.tscn").instantiate()
		trigger.encounter_id="entry_test"
		strip.encounter_id="entry_test"
		room.get_node("Entities").add_child(trigger)
		room.get_node("Entities").add_child(strip)
		trigger.set_physics_process(false)
		strip.set_physics_process(false)
		trigger.player=player
		check(not trigger.activate() and not strip.activate(),"%s blocks trigger and direct eruption before entrance" % room.name)
		shadow.surge(.3,.2)
		check(not shadow.warning(),"%s blocks legacy surge before entrance" % room.name)
		check(not shadow.locked_charge(.8,200,100,.8),"%s blocks charge before entrance" % room.name)
		await frames(25)
		check(not shadow.visible and not shadow.powers_available(),"%s standing still never unlocks powers" % room.name)
		player.global_position=spawn+Vector2(-16,0)
		await frames(2)
		check(not shadow.visible,"%s waits for three tiles of forward steps" % room.name)
		player.global_position=spawn+Vector2(-24,0)
		await frames(2)
		check(shadow.visible and world.room_rect(room).has_point(shadow.global_position),"%s body actually enters room" % room.name)
		check(not shadow.powers_available() and not trigger.activate(),"%s entrance precedes attacks" % room.name)
		await frames(24)
		check(shadow.powers_available() and trigger.activate(),"%s permits eruption after entrance beat" % room.name)
		shadow.reset_to_checkpoint(spawn)
		check(not shadow.powers_available() and not trigger.activate(),"%s retry closes attack gate" % room.name)
		trigger.queue_free();strip.queue_free()
	print("POWER ENTRY RULE: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
