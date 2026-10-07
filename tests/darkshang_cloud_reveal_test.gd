extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_18"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	for i in 12: await get_tree().physics_frame
	world.player.set_physics_process(false)
	var boss: Darkshang = get_tree().get_first_node_in_group("darkshang")
	boss.set_physics_process(false)
	boss.buffer.set_physics_process(false)
	var art = boss._visual
	art.set_process(false)
	check(boss.cloud_reveal_on_entry and boss._holding_entry, "Level18 arms reveal behind entry hold")
	world.player.global_position = boss._hold_from + boss._route() * 25
	boss._tick_entry_hold()
	check(boss.visible and is_equal_approx(art.cloud_transition_left,1.25), "first reveal begins only when visible and lasts1.25s")
	check(art._sprite.modulate.a == 1 and not art.get_node("Body/Cloud").visible, "first appearance holds humanoid silhouette")
	art._process(.65)
	check(art.get_node("Body/ChargeMorph").visible and art._cloud_weight > .2 and art._cloud_weight < .8, "humanoid expands through reverse morph")
	check(not boss.powers_available(), "first transformation cannot be interrupted by an attack")
	art._process(.7)
	check(art.get_node("Body/Cloud").visible and art._sprite.modulate.a == 0, "reveal settles into cloud")
	boss.reset_to_checkpoint(world.player.global_position)
	world.player.global_position = boss._hold_from + boss._route() * 25
	boss._tick_entry_hold()
	check(is_equal_approx(art.cloud_transition_left,.65), "repeat reveal is shorter")
	for room in world.rooms:
		if room.name == "Level_16":
			world._enter_room(room,true)
			break
	check(art.cloud_transition_left == 0 and not boss.cloud_reveal_on_entry, "Level16 has no reveal and leaving mid-reveal clears the attack gate")
	get_tree().quit(1 if failures else 0)
