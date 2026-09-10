extends RefCounted
## Visual topology uses the original scaffold cells, never surrounding masonry.
## A separate source preserves LDtk IDs and retains full-cell physics.
static func apply(layer: TileMapLayer) -> void:
	var cells := {}
	for cell in layer.get_used_cells():
		var a := layer.get_cell_atlas_coords(cell)
		if layer.get_cell_source_id(cell) == 32 and a.y == 0 and a.x >= 14 and a.x <= 17:
			cells[cell] = true
	if cells.is_empty(): return
	layer.tile_set = layer.tile_set.duplicate()
	var source := TileSetAtlasSource.new()
	source.texture = preload("res://ldtk/art/scaffolding_connected.png")
	source.texture_region_size = Vector2i(8,8)
	var sid := layer.tile_set.add_source(source)
	for mask in range(16):
		for v in range(8):
			var a := Vector2i(mask,v)
			source.create_tile(a)
			var data := source.get_tile_data(a,0)
			data.set_collision_polygons_count(0,1)
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-4,-4),Vector2(4,-4),Vector2(4,4),Vector2(-4,4)]))
	for cell: Vector2i in cells:
		var mask := 0
		var dirs := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
		for i in range(4):
			if cells.has(cell+dirs[i]): mask |= 1<<i
		var variant := posmod(hash(str(layer.get_parent().name) + ":" + str(cell)),4)
		if reinforced(mask, cell, str(layer.get_parent().name)):
			variant += 4
		layer.set_cell(cell,sid,Vector2i(mask,variant))

## Ends, turns and junctions use boxed couplers. Straight runs get one coupler
## per six-cell section, jittered by up to two cells: at least four cells apart.
## The room seed keeps the layout stable across reloads and distinct per room.
static func reinforced(mask: int, cell: Vector2i, room: String) -> bool:
	if mask != 5 and mask != 10:
		return true
	var along := cell.x if mask == 10 else cell.y
	var across := cell.y if mask == 10 else cell.x
	var section := floori(float(along) / 6.0)
	var offset := 1 + posmod(hash(room + ":" + str(across) + ":" + str(section) + ":" + str(mask)), 3)
	return posmod(along, 6) == offset
