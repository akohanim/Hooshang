extends Node2D
## Run directly to try the two placeable attacks. R resets through player death.
var player: Player
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("121521"))
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(320,16)
	collider.shape = shape
	floor_body.position = Vector2(160,168)
	floor_body.add_child(collider)
	add_child(floor_body)
	player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	player.position = Vector2(30,145)
	player.has_dash = true
	add_child(player)
	player.set_camera_limits(Rect2(0,0,320,180))
	player.died.connect(_reset)
	var shadow = preload("res://scenes/props/chase/Darkshang.tscn").instantiate()
	shadow.position = Vector2(0,145)
	shadow.auto_start = false
	shadow.follow_delay = 3.2
	shadow.respawn_gap = 80
	shadow.route_direction = Vector2.RIGHT
	shadow.entry_room_bounds = Rect2(0,0,320,180)
	shadow.entry_hold_distance = 24
	add_child(shadow)
	shadow._player = player
	shadow.start_chase()
	shadow.reset_to_checkpoint(player.global_position)
	var trigger = preload("res://scenes/props/chase/powers/DarkshangChargeTrigger.tscn").instantiate()
	trigger.position = Vector2(95,130)
	trigger.size = Vector2(16,60)
	trigger.distance = 250
	trigger.warning_time = 1
	add_child(trigger)
	var eruption = preload("res://scenes/props/chase/powers/ShadowEruptionTrigger.tscn").instantiate()
	eruption.position = Vector2(150,130)
	eruption.size = Vector2(16,60)
	add_child(eruption)
	for i in 3:
		var strip = preload("res://scenes/props/chase/powers/ShadowEruption.tscn").instantiate()
		strip.position = Vector2(180+i*40,156)
		strip.size = Vector2(24,8)
		strip.sequence = i
		add_child(strip)
		if "--shot" in OS.get_cmdline_user_args():
			strip.player = player
			strip.set_physics_process(false)
			strip.activate()
			strip.elapsed = .3 if i < 2 else .9
	if "--shot" in OS.get_cmdline_user_args():
		shadow.set_physics_process(false)
		shadow.buffer.set_physics_process(false)
		shadow.global_position = Vector2(280,110)
		shadow._locked_charge.begin(Vector2.LEFT,1,240,160,.7)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/darkshang_powers/preview.png")
		get_tree().quit()

func _reset() -> void:
	await get_tree().create_timer(.4).timeout
	player.respawn(Vector2(30,145))

func _draw() -> void:
	draw_rect(Rect2(0,160,320,20),Color("303747"))
	for x in range(0,320,8): draw_line(Vector2(x,160),Vector2(x+6,160),Color("798293"),1)
	var font = preload("res://assets/fonts/pixel5x7.fnt")
	draw_string(font,Vector2(12,20),"DARKSHANG / POWER GYM",HORIZONTAL_ALIGNMENT_LEFT,-1,8)
	draw_string(font,Vector2(12,35),"95: CHARGE    150: ERUPTION",HORIZONTAL_ALIGNMENT_LEFT,-1,7)
