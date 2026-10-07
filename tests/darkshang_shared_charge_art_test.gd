extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_18"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(12)
	var player := world.player
	player.set_physics_process(false)
	var boss: Darkshang = get_tree().get_first_node_in_group("darkshang")
	boss.set_physics_process(false)
	boss.buffer.set_physics_process(false)
	boss._visual.set_process(false)
	for trigger in get_tree().get_nodes_in_group("darkshang_power_trigger"):
		trigger.set_physics_process(false)
	var tested: Array[String] = []
	for room in world.rooms:
		var charges: Array = []
		for trigger in get_tree().get_nodes_in_group("darkshang_power_trigger"):
			if room.is_ancestor_of(trigger) and trigger.power == 0: charges.append(trigger)
		if charges.is_empty(): continue
		world._enter_room(room, true)
		await frames(3)
		check(boss._visual.cloud_form, "%s starts with shared cloud art" % room.name)
		boss._holding_entry = false
		boss._player = player
		boss.visible = true
		boss.state = Darkshang.State.FOLLOWING
		boss._locked_charge.cancel()
		player.input_locked = false
		player.state = Player.State.FALL
		boss.global_position = world.room_rect(room).get_center()
		boss._tick_power_entry(.5)
		check(boss.locked_charge(.8, 240, 240, .7), "%s accepts charge" % room.name)
		check(boss._locked_charge.return_to_launch, "%s shares cloud return cycle" % room.name)
		if boss._locked_charge.phase == 4: boss._locked_charge.tick(.46, boss, player)
		boss._locked_charge.tick(.3, boss, player)
		boss._push_visual()
		boss._visual._process(.275)
		var morph: Node2D = boss._visual.get_node("Body/ChargeMorph")
		check(morph.visible and morph.progress > .4 and morph.progress < .6, "%s shows supplied morph during warning" % room.name)
		boss._locked_charge.tick(.51, boss, player)
		boss._push_visual()
		boss._visual._process(.3)
		check(not morph.visible and boss._visual._sprite.modulate.a == 1.0, "%s resolves to humanoid charge" % room.name)
		player.global_position.y += 1000
		boss._locked_charge.tick(10, boss, player)
		boss._push_visual()
		check(not boss._visual.visible, "%s disappears on missed charge" % room.name)
		boss._locked_charge.tick(1, boss, player)
		boss._push_visual()
		boss._visual._process(0)
		check(boss._visual.visible and boss._visual.get_node("Body/Cloud").visible, "%s returns in cloud form" % room.name)
		tested.append(str(room.name))
	check(tested.has("Level_18") and tested.has("Level_19") and tested.size() >= 7, "covers Level 18, 19 and all later authored charge rooms")
	print("SHARED CHARGE ART: %d failures in %s" % [failures, tested])
	get_tree().quit(1 if failures else 0)
