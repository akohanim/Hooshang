extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func _ready() -> void:
	var player: Player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	var boss: Darkshang = preload("res://scenes/props/chase/Darkshang.tscn").instantiate()
	boss.auto_start = false
	add_child(boss)
	boss.set_physics_process(false)
	boss.buffer.set_physics_process(false)
	boss._player = player
	boss._visual.cloud_form = true
	boss.start_chase()
	for height in [60.0,180.0]:
		boss.position = Vector2(400,100)
		player.position = Vector2(80,height)
		boss._tick_power_entry(.5)
		check(boss.locked_charge(.3,1000,60,.4),"horizontal charge starts")
		boss._physics_process(.1)
		check(boss.position.y == player.position.y,"pre-charge aligns with player height")
		player.position.y += 20
		boss._physics_process(.1)
		check(boss.position.y == player.position.y,"pre-charge follows vertical player movement")
		boss._physics_process(.11)
		var origin := boss.position
		check(boss._locked_charge.direction == Vector2.LEFT,"launch direction has zero vertical component")
		check(boss._locked_charge.distance_left >= 480,"charge reaches beyond player's locked x")
		player.position.y += 100
		boss._physics_process(.1)
		check(boss.position == origin+Vector2(-100,0),"charge does not follow height changes after lock")
		boss._physics_process(1)
		check(boss._locked_charge.phase == 3,"miss reaches recovery")
		boss._physics_process(.41)
		check(boss.position.is_equal_approx(origin),"cloud recovery returns to charge launch position")
		var returned := boss.position
		boss._physics_process(.016)
		check(boss.position.distance_to(returned)<.1,"pursuit resumes without snapping")
	boss.position = Vector2(400,50)
	player.position = Vector2(80,120)
	player.invulnerable_timer = 0
	boss._tick_power_entry(.5)
	check(boss.locked_charge(.15,1000,60,.4),"contact trial starts")
	boss._physics_process(.16)
	boss._physics_process(.4)
	check(boss.state == Darkshang.State.CAUGHT and player.input_locked,"horizontal contact consumes player")
	await get_tree().create_timer(boss.ingest_time+.1).timeout
	check(player.state == Player.State.DEAD,"consumption ends in death")
	boss.reset_to_checkpoint(player.position)
	check(boss._locked_charge.phase == 0 and boss._holding_entry,"reset cancels attack and restores entrance gate")
	print("DYNAMIC CHARGE: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
