extends Node
func _ready() -> void:
	var p = preload("res://scenes/props/platforms/CrumblingPlatform.tscn").instantiate()
	p.size = Vector2(40,8)
	add_child(p)
	assert(p._visual.get_child_count() == 5)
	var player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(0,p.top_y()-Player.HALF_HEIGHT)
	player.velocity = Vector2.ZERO
	p._try_arm(player)
	assert(p._spent and p._timer == 0.0)
	for block in p._visual.get_children():
		assert(block.position != block.get_meta("rest"), "Warning must be visible at time zero")
		assert(block.modulate.r < 1.0)
	player.global_position = Vector2(-10000,-10000)
	player.queue_free()
	p.reset()
	var activity := [0, 0, 0]
	for i in range(5):
		for tick in range(300):
			var offset: Vector2 = p._warning_offset(i, tick / 300.0)
			assert(offset.length() <= 1.0)
			assert(offset == offset.round())
			if offset != Vector2.ZERO: activity[tick / 100] += 1
	assert(activity[0] < activity[1] and activity[1] < activity[2],
		"Each third must become more unstable: " + str(activity))
	assert(activity[2] < 350, "Final warning still needs brief rests")
	assert(p.FRAMES[0].get_image().get_data() != p.FRAMES[2].get_image().get_data(),
		"Late warning must show deeper cracks")
	p.give_way(0)
	p._process(0.01)
	assert(p._falling and not p.get_collision_layer_value(1))
	await get_tree().create_timer(0.55).timeout
	for block in p._visual.get_children(): assert(block.modulate.a < 0.01)
	p._process(60.0)
	assert(p._falling and not p.get_collision_layer_value(1))
	for block in p._visual.get_children(): assert(block.modulate.a < 0.01)
	CrumblingPlatform.reset_all(get_tree())
	assert(not p._falling and p.get_collision_layer_value(1))
	for block in p._visual.get_children():
		assert(block.position == block.get_meta("rest"))
		assert(block.modulate.a == 1 and block.scale == Vector2.ONE)
	p.give_way(0)
	p._process(0.01)
	p.reset()
	await get_tree().create_timer(0.6).timeout
	assert(not p._spent and not p._falling)
	for block in p._visual.get_children(): assert(block.position == block.get_meta("rest"))
	print("PASS: individual blocks, collapse, persistent collapse and reset during fall")
	get_tree().quit()
