extends Node
func _ready() -> void:
	for room_name in ["Level_15","Level_16","Level_17","Level_18"]:
		var vp := SubViewport.new()
		var sizes := {"Level_15":Vector2i(344,512),"Level_16":Vector2i(400,384),"Level_17":Vector2i(576,256),"Level_18":Vector2i(1416,240)}
		vp.size = sizes[room_name]
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var room: Node2D = load("res://ldtk/levels/hooshang_act1/%s.scn" % room_name).instantiate()
		room.position = Vector2.ZERO
		vp.add_child(room)
		for item in room.get_node("Entities").get_children():
			if item.is_in_group("shadow_eruption"):
				item.set_physics_process(false)
				item.activate()
				item.elapsed = item.warning_time+.1 if item.sequence%2 else .3
				item.queue_redraw()
			if item.is_in_group("darkshang_power_trigger") and item.power==0:
				var visual = preload("res://scenes/characters/darkshang/DarkshangVisual.tscn").instantiate()
				visual.position = item.position+Vector2(72,-24) # example pursuit position
				visual.scale = Vector2(.9,.9)
				room.add_child(visual)
				var tell = preload("res://scenes/props/chase/powers/LockedCharge.tscn").instantiate()
				tell.position = visual.position
				room.add_child(tell)
				tell.begin((item.position-visual.position).normalized(),item.warning_time,item.speed,item.distance,item.recovery_time)
		for i in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot := vp.get_texture().get_image()
		shot.save_png("res://output/darkshang_15_18/%s.png" % room_name)
		vp.queue_free()
		await get_tree().process_frame
	get_tree().quit()
