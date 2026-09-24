extends Node
func _ready() -> void:
	var ts: TileSet = load("res://ldtk/tilesets/tileset_8px_hooshang_act1.res")
	var source: TileSetAtlasSource = ts.get_source(32)
	var failed := false
	# Check real authored placements too: a complete texture alone did not stop
	# Level_0 importing with ZERO cells when the saved source had only 26 tiles.
	var world_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/hooshang_act1.ldtk"))
	for level_data in world_data.levels:
		var room = load("res://ldtk/levels/hooshang_act1/%s.scn" % level_data.identifier).instantiate()
		var layer: TileMapLayer = room.get_node("Collisions")
		for layer_data in level_data.layerInstances:
			if layer_data.__identifier != "Collisions":
				continue
			for tile in layer_data.autoLayerTiles:
				if tile.t < 26:
					continue
				var cell := Vector2i(int(tile.px[0]) / 8, int(tile.px[1]) / 8)
				if layer.get_cell_atlas_coords(cell) != Vector2i(int(tile.src[0]) / 8, int(tile.src[1]) / 8):
					push_error("Masonry placement lost in %s at %s" % [level_data.identifier, cell])
					failed = true
		room.free()
	for x in range(26,416):
		if not source.has_tile(Vector2i(x,0)):
			push_error("Missing masonry atlas tile %d" % x)
			failed = true
		elif source.get_tile_data(Vector2i(x,0),0).get_collision_polygons_count(0) != 1:
			push_error("Missing masonry collision %d" % x)
			failed = true
	print("MASONRY TILES: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
