extends Node
func _ready() -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = load("res://ldtk/tilesets/tileset_8px_hooshang_act1.res")
	add_child(layer)
	for x in range(24): layer.set_cell(Vector2i(x,0),32,Vector2i(15,0))
	for y in range(1,12): layer.set_cell(Vector2i(0,y),32,Vector2i(16,0))
	preload("res://scripts/scaffolding_variation.gd").apply(layer)
	var variants := {}
	for x in range(1,23):
		var cell := Vector2i(x,0)
		var a := layer.get_cell_atlas_coords(cell)
		assert(a.x == 10, "Horizontal rail must join east and west")
		variants[a.y] = true
		assert(layer.get_cell_tile_data(cell).get_collision_polygons_count(0) == 1)
	assert(variants.size() >= 3)
	for y in range(1,11): assert(layer.get_cell_atlas_coords(Vector2i(0,y)).x == 5)
	assert(layer.get_cell_atlas_coords(Vector2i.ZERO).x == 6)
	assert(layer.get_cell_atlas_coords(Vector2i.ZERO).y >= 4)
	assert(layer.get_cell_atlas_coords(Vector2i(23,0)).y >= 4)
	var rule = preload("res://scripts/scaffolding_variation.gd")
	for mask in range(16):
		if mask not in [5,10]: assert(rule.reinforced(mask,Vector2i.ZERO,"test"))
	for mask in [5,10]:
		var last := -999
		var count := 0
		for along in range(-60,60):
			var cell := Vector2i(along,0) if mask == 10 else Vector2i(0,along)
			if rule.reinforced(mask,cell,"test"):
				assert(along-last >= 4)
				last = along
				count += 1
		assert(count == 20)
	var before := layer.get_cell_atlas_coords(Vector2i(4,0))
	preload("res://scripts/scaffolding_variation.gd").apply(layer)
	assert(layer.get_cell_atlas_coords(Vector2i(4,0)) == before)
	print("PASS: scaffold joins, corners, variants, collision and repeat application")
	get_tree().quit()
