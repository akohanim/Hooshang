extends Node
## Isolated lighting prototype and full-room overview, at native pixel density.
func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,352)
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var room: Node2D = load("res://ldtk/levels/hooshang_act1/Level_V9.scn").instantiate()
	room.position = Vector2.ZERO
	viewport.add_child(room)
	var ambient := CanvasModulate.new()
	ambient.color = Color(0.05,0.05,0.05)
	viewport.add_child(ambient)
	for i in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.resize(1280,704,Image.INTERPOLATE_NEAREST)
	image.save_png("res://output/level_v9/overview.png")
	viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit()
