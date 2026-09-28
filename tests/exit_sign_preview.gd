extends Node
## Native-resolution art check; run windowed to render the two shared prefabs.
func _ready() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(160, 80)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	var backing := ColorRect.new()
	backing.size = Vector2(160, 80)
	backing.color = Color("202b33")
	view.add_child(backing)
	for i in 2:
		var path := "res://scenes/props/ExitSign.tscn" if i == 0 else "res://scenes/props/ExitSignCeiling.tscn"
		var sign := load(path).instantiate() as Node2D
		sign.position = Vector2(42 + i * 76, 38 if i == 0 else 28)
		view.add_child(sign)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture := view.get_texture().get_image()
	picture.resize(960, 480, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute("res://output/exit_sign")
	picture.save_png("res://output/exit_sign/preview.png")
	get_tree().quit()
