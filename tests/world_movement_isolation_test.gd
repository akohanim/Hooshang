extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func load_world(act: int) -> LdtkWorld:
	LdtkWorld.debug_start_room = "Act_2_Level_3" if act == 2 else ""
	var world: LdtkWorld = Screen.load_scene("res://ldtk/Act%dWorld.tscn" % act)
	for i in 12: await get_tree().physics_frame
	return world
func values(player: Player) -> Array:
	return [player.childhood_momentum, player.max_run_speed, player.ground_accel,
		player.ground_decel, player.air_accel_mult, player.air_decel_mult,
		player.dash_speed, player.dash_time, player.dash_end_speed,
		player.jump_speed, player.use_jump_hold, player.jump_cut_multiplier,
		player.rise_gravity, player.fall_gravity, player.max_fall_speed,
		player.spring_impulse_scale, player.juice.jump_squash_scale,
		player.juice.land_squash_scale, player.juice.squash_ease_time]
func _ready() -> void:
	SaveGame.slot = -1
	var one := await load_world(1)
	var baseline_one := values(one.player)
	check(not one.player.childhood_momentum and one.player.use_jump_hold and one.player.max_run_speed == 72,
		"World 1 retains the original movement model")
	var three := await load_world(3)
	var baseline_three := values(three.player)
	check(not three.player.childhood_momentum and three.player.use_jump_hold and three.player.max_run_speed == 72,
		"World 3 retains the original movement model")
	var two := await load_world(2)
	check(two.player.childhood_momentum and not two.player.use_jump_hold and two.player.max_run_speed == 67.5,
		"only World 2 enables the new momentum and gravity model")
	check(two.player.dash_end_speed == 64.0 and two.player.dash_speed == 260.0,
		"World 2 reduces post-dash carry-over by 60% without slowing the dash")
	two._enter_room(two.rooms.back(), true)
	check(two.player.childhood_momentum, "World 2 model survives its room transitions")
	one = await load_world(1)
	check(values(one.player) == baseline_one, "returning from World 2 changes no World 1 movement or animation values")
	three = await load_world(3)
	check(values(three.player) == baseline_three, "World 3 values remain identical after World 2")
	print("WORLD MOVEMENT ISOLATION: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
