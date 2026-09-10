extends Node
func _ready() -> void:
	var ts: TileSet = load("res://ldtk/tilesets/tileset_8px_hooshang_act1.res")
	var source: TileSetAtlasSource = ts.get_source(32)
	var image := source.texture.get_image()
	for x in range(14, 18):
		assert(source.has_tile(Vector2i(x, 0)))
		assert(source.get_tile_data(Vector2i(x, 0), 0).get_collision_polygons_count(0) == 1)
		var clear := 0
		for y in range(8):
			for u in range(8):
				if image.get_pixel(x * 8 + u, y).a == 0:
					clear += 1
		assert(clear >= 14, "Godot must load the transparent scaffold art")
	print("SCAFFOLDING: PASS — imported alpha, atlas cells and collision")
	get_tree().quit()
