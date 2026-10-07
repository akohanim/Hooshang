extends Node
## Render the actual scale with nearest filtering: a source-only audit missed
## the one-source-pixel outline disappearing during the 0.375 reduction.
func _ready() -> void:
	var frames := load("res://assets/characters/hooshang_child/act2_frames.tres") as SpriteFrames
	var vp := SubViewport.new()
	vp.size = Vector2i(768, 640)
	vp.transparent_bg = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var count := 0
	for animation in frames.get_animation_names():
		for frame in frames.get_frame_count(animation):
			for mirrored in [false, true]:
				var sprite := Sprite2D.new()
				sprite.texture = frames.get_frame_texture(animation, frame)
				sprite.scale = Vector2.ONE * frames.get_meta("visual_scale")
				sprite.offset = frames.get_meta("visual_offset")
				sprite.flip_h = mirrored
				sprite.position = Vector2(24 + (count % 16) * 48, 24 + (count / 16) * 48)
				vp.add_child(sprite)
				count += 1
	await RenderingServer.frame_post_draw
	var im := vp.get_texture().get_image()
	var exposed := 0
	for y in range(1, im.get_height()-1):
		for x in range(1, im.get_width()-1):
			var c := im.get_pixel(x,y)
			# Only the three authored hair shades and black ink are exempt.
			if c.a == 0.0 or c == Color.BLACK or c in [Color8(22,22,30), Color8(79,77,92), Color8(43,42,56)]: continue
			for dy in range(-1,2):
				for dx in range(-1,2):
					if im.get_pixel(x+dx,y+dy).a == 0.0: exposed += 1
	im.save_png("res://output/act2_visibility/rendered_frames.png")
	print("CHILD OUTLINE RENDER: ", count, " poses/facings, ", exposed, " exposed colored edges")
	get_tree().quit(0 if exposed == 0 else 1)
