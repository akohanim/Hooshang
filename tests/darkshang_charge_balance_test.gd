extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
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
	boss.start_chase()
	boss._tick_power_entry(.5)
	var trigger = preload("res://scenes/props/chase/powers/power_trigger.gd").new()
	add_child(trigger)
	trigger.set_physics_process(false)
	trigger.recovery_time = 1.2
	trigger.warning_time = 1.05
	trigger.speed = 1000
	trigger.player = player
	boss.position = Vector2(400,100)
	player.position = Vector2(80,100)
	trigger.position = player.position
	trigger.armed = true
	trigger._physics_process(.016)
	check(trigger.spent and trigger.repeating, "first crossing owns one continuing charge sequence")
	check(is_equal_approx(boss._locked_charge.recovery,.6), "Level19 recovery halves from 1.2 to 0.6 seconds")
	check(is_equal_approx(boss._locked_charge.remaining,1.05), "full original warning preserved")
	boss._physics_process(1.06)
	player.position.y += 100
	boss._physics_process(1)
	check(boss._locked_charge.phase == 3, "miss enters recovery")
	boss._physics_process(.59)
	trigger._physics_process(.59)
	check(boss._locked_charge.phase == 3, "repeat cannot interrupt recovery")
	boss._physics_process(.02)
	trigger._physics_process(.02)
	check(boss._locked_charge.phase == 0, "post-return pause keeps cloud readable")
	boss._tick_power_entry(.18)
	trigger._physics_process(.18)
	check(boss._locked_charge.phase == 1, "next charge starts outside trigger after shortened recovery")
	trigger.reset()
	boss._locked_charge.cancel()
	trigger._physics_process(2)
	check(not trigger.repeating and boss._locked_charge.phase == 0, "reset stops sequence without firing at respawn")
	var inactive_world := LdtkWorld.new()
	trigger.world = inactive_world
	trigger.repeating = true
	trigger._physics_process(.016)
	check(not trigger.repeating and boss._locked_charge.phase == 0, "inactive room cancels its recurring sequence")
	trigger.world = null
	inactive_world.free()
	# A rising dash clears the body; clipping its head/shoulder no longer does.
	boss.position = Vector2(200,100)
	player.position = Vector2(100,100)
	player.has_dash = true
	player.dash_available = true
	player.dash_cooldown_timer = 0
	check(player._try_dash(Vector2.UP, true), "upward dodge uses the real player dash")
	player.set_physics_process(true)
	for i in 18: await get_tree().physics_frame
	player.set_physics_process(false)
	check(player.hitbox_rect().end.y < 64, "real upward dash clears charge body's upper edge")
	check(not boss._locked_charge.catch_along(boss,player,Vector2(-200,0)), "upward dash dodges charging silhouette")
	check(not player.input_locked, "successful dodge leaves control intact")
	player.position = Vector2(100,70)
	check(boss._locked_charge.catch_along(boss,player,Vector2(-200,0)), "head and shoulder contact catches across a fast sweep")
	check(boss.state == Darkshang.State.CAUGHT and player.input_locked, "expanded body still uses ingestion")
	await get_tree().create_timer(boss.ingest_time+.1).timeout
	check(player.state == Player.State.DEAD, "ingestion still pays one death")
	print("CHARGE BALANCE: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
