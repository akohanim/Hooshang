extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_20"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(12)
	var room := world.current_room
	var player := world.player
	player.set_physics_process(false)
	player.input_locked = false
	var shadow: Darkshang = get_tree().get_first_node_in_group("darkshang")
	shadow.set_physics_process(false)
	shadow.buffer.set_physics_process(false)
	var trigger: Node2D
	var strips: Array = []
	for node in get_tree().get_nodes_in_group("darkshang_power_trigger") + get_tree().get_nodes_in_group("shadow_eruption"):
		node.set_physics_process(false)
		if not room.is_ancestor_of(node): continue
		if node.is_in_group("darkshang_power_trigger") and node.encounter_id == "L19_LadderBottom": trigger = node
		if node.is_in_group("shadow_eruption"): strips.append(node)
	check(trigger != null and strips.size() == 4, "imported ladder trigger and four strips")
	if trigger == null or strips.size() != 4:
		get_tree().quit(1)
		return
	strips.sort_custom(func(a, b): return a.position.x > b.position.x)
	check(trigger.position == Vector2(724,352) and trigger.size == Vector2(32,16), "trigger covers ladder bottom")
	var positions := [Vector2(604,332),Vector2(532,356),Vector2(460,324),Vector2(116,324)]
	var sequences := [0,1,2,7]
	for i in strips.size():
		check(strips[i].position == positions[i] and strips[i].sequence == sequences[i], "existing strip placement and sequence %d" % i)
		strips[i]._physics_process(0)
	trigger.reset()
	player.global_position = trigger.global_position + Vector2(0,-32)
	trigger._physics_process(.016)
	check(trigger.armed and not trigger.spent, "descending above ladder bottom does not fire")
	shadow._holding_entry = true
	player.global_position = trigger.global_position + Vector2(0,-6)
	trigger._physics_process(.016)
	check(not trigger.spent, "entrance gate prevents early casting")
	shadow._holding_entry = false
	shadow.visible = true
	shadow.state = Darkshang.State.FOLLOWING
	shadow._player = player
	shadow.global_position = room.global_position + Vector2(740,300)
	shadow._tick_power_entry(.5)
	trigger._physics_process(.016)
	check(trigger.spent, "reaching ladder bottom starts series after boss enters")
	player.global_position = room.global_position + Vector2(724,300)
	for i in strips.size():
		var strip = strips[i]
		check(strip.elapsed == 0 and strip.delay == sequences[i], "linked strip scheduled %d" % i)
		strip._physics_process(float(sequences[i]) + 1.49)
		check(not strip.is_lethal(), "warning stays safe %d" % i)
		strip._physics_process(.02)
		check(strip.is_lethal(), "spikes rise on schedule %d" % i)
		strip._physics_process(.8)
		check(strip.elapsed < 0, "spikes expire %d" % i)
	trigger._physics_process(.016)
	player.global_position = trigger.global_position
	trigger._physics_process(.016)
	check(strips.all(func(s): return s.elapsed < 0), "series does not repeat in same life")
	# Exercise the real death signal without invoking the world's respawn timer.
	player.died.disconnect(world._on_player_died)
	player.died.emit()
	check(not trigger.spent and not trigger.armed and strips.all(func(s): return s.elapsed < 0), "death resets encounter")
	print("DARKSHANG LEVEL 19: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
