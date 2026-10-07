extends Node
## Native-resolution rendered regression and motion preview. Windowed, no saves.
const OUT := "res://output/dust_preview"
var failures := 0
func _ready() -> void:
	SaveGame.slot = -1
	DirAccess.make_dir_recursive_absolute(OUT)
	var view := SubViewport.new()
	view.size = Vector2i(320, 180)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.transparent_bg = true
	add_child(view)
	var source: Node = load("res://ldtk/levels/hooshang_act1/Level_24.scn").instantiate()
	var original: TileMapLayer = source.get_node("ThoughtHazards")
	var layer := TileMapLayer.new()
	layer.tile_set = original.tile_set
	var id := layer.tile_set.get_source_id(0)
	# Use the thought sheet's source, not another atlas in the shared tileset.
	for cell in original.get_used_cells():
		id = original.get_cell_source_id(cell)
		break
	for x in range(3,37): layer.set_cell(Vector2i(x,17),id,Vector2i.ZERO)
	for y in range(7,13): layer.set_cell(Vector2i(5,y),id,Vector2i.ZERO)
	for x in range(13,21):
		for y in range(7,10): layer.set_cell(Vector2i(x,y),id,Vector2i.ZERO)
	layer.set_cell(Vector2i(30,8),id,Vector2i.ZERO)
	layer.set_script(load("res://scripts/ldtk_dust_hazard_layer.gd"))
	view.add_child(layer)
	source.free()
	layer.dust.set_process(false)
	var first: Image
	var changed := false
	var silhouette_changed := false
	for tick in 24:
		layer.dust._process(0.2 if tick > 0 else 0.0)
		await RenderingServer.frame_post_draw
		var shot := view.get_texture().get_image()
		shot.save_png("%s/frame_%02d.png" % [OUT,tick])
		if tick == 0: first = shot
		elif shot.get_data() != first.get_data():
			changed = true
			var pixels := shot.get_data()
			var original_pixels := first.get_data()
			for i in range(3, pixels.size(), 4):
				if pixels[i] != original_pixels[i]:
					silhouette_changed = true
					break
		# A connected mass must stay filled in its interior across the cycle.
		for x in range(109,163):
			for y in range(61,75):
				var color := shot.get_pixel(x,y)
				if color.a < 0.9: failures += 1
				if color.r > 0.3 and color.g < 0.4: failures += 1
	if not changed or not silhouette_changed: failures += 1
	print("DUST RENDER: %d failures; animated pixels=%s; moving silhouette=%s; frames in %s" % [failures,changed,silhouette_changed,OUT])
	get_tree().quit(1 if failures else 0)
