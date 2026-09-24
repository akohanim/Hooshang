extends Node

func _ready() -> void:
	var ts: TileSet = load("res://ldtk/tilesets/tileset_8px_hooshang_act2.res")
	assert(ts != null)
	var atlas: TileSetAtlasSource = ts.get_source(206)
	assert(atlas.texture.resource_path.ends_with("act2_materials/terrain.png"))
	assert(atlas.texture.get_width() == 7472)
	for i in range(26,934):
		assert(atlas.has_tile(Vector2i(i,0)), "Missing imported material tile %d" % i)
		var data := atlas.get_tile_data(Vector2i(i,0),0)
		assert(data.get_collision_polygons_count(0) == 1)
		assert(data.get_collision_polygon_points(0,0).size() == 4)
	var pixels := atlas.texture.get_image()
	var core := pixels.get_region(Rect2i(220*8, 0, 8, 8))
	for tile in [415,738,933]:
		for y in range(8):
			for x in range(8):
				assert(pixels.get_pixel(tile*8+x,y) == core.get_pixel(x,y), "All terrain shares the same earth interior")
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://output/act2_materials/fixture.json"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(440,280)
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var bg := ColorRect.new()
	bg.size = Vector2(440,280)
	bg.color = Color("3f6578")
	viewport.add_child(bg)
	var map := TileMapLayer.new()
	map.tile_set = ts
	viewport.add_child(map)
	for cell in fixture:
		map.set_cell(Vector2i(cell[0],cell[1]),206,Vector2i(cell[2],0))
	for i in range(4):
		var label := Label.new()
		label.text = ["GRASS", "CORAL BRICK", "HONEY STONE", "GREY STONE"][i]
		label.position = Vector2(16+i*104,15)
		label.add_theme_font_size_override("font_size",10)
		viewport.add_child(label)
	var caption := Label.new()
	caption.text = "SHARED INTERIOR / MIXED MATERIALS"
	caption.position = Vector2(16,174)
	caption.add_theme_font_size_override("font_size",10)
	viewport.add_child(caption)
	print("ACT 2 MATERIALS: PASS — 908 imported tiles, full collision, fixture populated")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.resize(1760,1120,Image.INTERPOLATE_NEAREST)
		shot.save_png("res://output/act2_materials/godot_preview.png")
	get_tree().quit()
