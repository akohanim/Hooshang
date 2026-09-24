extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	var player: Player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(100,0)
	var shadow: Darkshang = preload("res://scenes/props/chase/Darkshang.tscn").instantiate()
	shadow.auto_start = false
	add_child(shadow)
	shadow.set_physics_process(false)
	shadow.buffer.set_physics_process(false)
	shadow._player = player
	shadow.start_chase()
	shadow.global_position = Vector2.ZERO
	shadow.visible = true
	shadow._tick_power_entry(.5)
	check(shadow.locked_charge(.3,200,120,.4),"charge starts")
	var charge = shadow._locked_charge
	charge.tick(.2,shadow,player)
	check(shadow.position == Vector2.ZERO and player.state != Player.State.DEAD,"warning safe and stationary")
	player.position = Vector2(100,100)
	charge.tick(.11,shadow,player)
	player.position = Vector2(100,200)
	charge.tick(.1,shadow,player)
	check(shadow.position.is_equal_approx(Vector2(20,100)),"horizontal lane stays locked after player moves")
	var wall := StaticBody2D.new()
	wall.position = Vector2(50,0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8,80)
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	charge.tick(2,shadow,player)
	check(shadow.position.x >= 260 and charge.phase == 3,"spectral charge crosses wall and reaches beyond target")
	var stopped := shadow.position
	charge.tick(.2,shadow,player)
	check(shadow.position == stopped,"recovery stays still")
	shadow.reset_to_checkpoint(Vector2.ZERO)
	check(charge.phase == 0,"checkpoint cancels charge")
	shadow._holding_entry = false
	shadow.global_position = Vector2.ZERO
	shadow.visible = true
	shadow._tick_power_entry(.5)
	player.position = Vector2(20,0)
	check(shadow.locked_charge(.15,1000,100,.4),"second charge starts")
	charge.tick(.16,shadow,player)
	charge.tick(.1,shadow,player)
	check(shadow.state == Darkshang.State.CAUGHT and player.input_locked,"fast charge consumes player without tunnelling")
	shadow._resolve_catch()
	check(player.state == Player.State.DEAD,"consumption resolves to death")
	player.respawn(Vector2(100,100))
	player.invulnerable_timer = 0
	charge.cancel()
	shadow.global_position = Vector2(0,100)
	player.position = Vector2(0,130)
	charge.begin(Vector2(1,1),.15,1000,40,.4)
	charge.tick(.16,shadow,player)
	charge.tick(.1,shadow,player)
	check(player.state != Player.State.DEAD,"diagonal bounding-box corner is safe")
	charge.cancel()
	player.position = Vector2(100,100)
	var hook = load("res://scripts/ldtk_entities_post_import.gd").new()
	var strip = hook._build_darkshang_power({"identifier":"ShadowEruption","position":Vector2(100,100),"size":Vector2(32,8),"fields":{"WarningTime":.3,"ActiveTime":.2,"Sequence":2.0,"EncounterID":"test"}})
	add_child(strip)
	strip.set_physics_process(false)
	strip.player = player
	player.died.connect(strip.reset)
	check(strip.sequence == 2 and strip.encounter_id == "test","imported fields survive")
	strip.activate(.4)
	strip._physics_process(.39)
	check(not strip.is_lethal() and player.state != Player.State.DEAD,"sequence waits safely")
	strip._physics_process(.3)
	check(not strip.is_lethal() and player.state != Player.State.DEAD,"warning safe")
	strip._physics_process(.02)
	check(player.state == Player.State.DEAD and strip.elapsed < 0,"active eruption kills and death clears it")
	player.respawn(Vector2(200,100))
	strip.activate()
	strip._physics_process(.31)
	check(player.state != Player.State.DEAD,"outside strip remains safe")
	strip._physics_process(.3)
	check(strip.elapsed < 0,"eruption retracts")
	var trigger = hook._build_darkshang_power({"identifier":"ShadowEruptionTrigger","position":Vector2(200,100),"size":Vector2(16,48),"fields":{"EncounterID":"test","SequenceDelay":.25}})
	add_child(trigger)
	trigger.set_physics_process(false)
	trigger._physics_process(.01)
	check(not trigger.spent,"spawn inside trigger does not fire")
	player.position.x = 240
	trigger._physics_process(.01)
	player.position.x = 200
	trigger._physics_process(.01)
	check(trigger.spent and is_equal_approx(strip.delay,.5),"crossing triggers linked sequence")
	var other := Node2D.new()
	add_child(other)
	var foreign = preload("res://scenes/props/chase/powers/ShadowEruption.tscn").instantiate()
	foreign.encounter_id = "test"
	other.add_child(foreign)
	strip.reset()
	trigger.activate()
	check(strip.elapsed >= 0 and foreign.elapsed < 0,"other-room strip untouched")
	var packed := PackedScene.new()
	check(packed.pack(trigger) == OK,"trigger packs")
	var copy = packed.instantiate()
	check(copy.encounter_id == "test" and copy.sequence_delay == .25,"trigger fields survive packing")
	copy.free()
	print("DARKSHANG POWERS: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
