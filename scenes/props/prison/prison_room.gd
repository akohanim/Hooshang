extends Node2D
## Collision authority is LDtk's semantic IntGrid. Visual atlas never collides.
var grid: TileMapLayer
var geometry: TileMapLayer
var world: Node
var size_cells := Vector2i.ZERO

func _ready() -> void:
	for visual in get_parent().find_children("*", "TileMapLayer", true, false):
		visual.collision_enabled = false
	grid = get_parent().get_node("Collision-values")
	size_cells = Vector2i(get_parent().size) / 8
	var set := TileSet.new()
	set.tile_size = Vector2i(8, 8)
	set.add_physics_layer()
	set.set_physics_layer_collision_layer(0, 1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = preload("res://ldtk/art/prison/school.png")
	atlas.texture_region_size = Vector2i(8, 8)
	set.add_source(atlas, 0)
	for v in [0, 1]:
		atlas.create_tile(Vector2i(v, 0))
		var td := atlas.get_tile_data(Vector2i(v, 0), 0)
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-4,-4),Vector2(4,-4),Vector2(4,4),Vector2(-4,4)]))
		td.set_collision_polygon_one_way(0, 0, v == 1)
	geometry = TileMapLayer.new()
	geometry.name = "Physics"
	geometry.tile_set = set
	geometry.visible = false
	add_child(geometry)
	for cell in grid.get_used_cells():
		var value := value_at(cell)
		if value in [1,2]: geometry.set_cell(cell,0,Vector2i(value-1,0))

func value_at(cell: Vector2i) -> int:
	if grid.get_cell_source_id(cell) == -1: return 0
	return grid.get_cell_atlas_coords(cell).x + 1

func has_water_at(point: Vector2) -> bool:
	return value_at(grid.local_to_map(grid.to_local(point))) == 4

func surface_y_at(point: Vector2) -> float:
	var cell := grid.local_to_map(grid.to_local(point))
	if value_at(cell) != 4: return INF
	while value_at(cell + Vector2i.UP) == 4: cell.y -= 1
	return grid.to_global(Vector2(cell * 8)).y

func hazard_overlaps(rect: Rect2) -> bool:
	var a := grid.local_to_map(grid.to_local(rect.position))
	var b := grid.local_to_map(grid.to_local(rect.end - Vector2.ONE * 0.01))
	for y in range(a.y,b.y+1):
		for x in range(a.x,b.x+1):
			if value_at(Vector2i(x,y)) == 3: return true
	return false
