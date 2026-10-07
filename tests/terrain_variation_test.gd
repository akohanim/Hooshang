extends Node
const RULE := preload("res://scripts/terrain_variation.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	var layer := TileMapLayer.new()
	layer.name = "Collisions"
	layer.tile_set = load("res://ldtk/tilesets/tileset_8px_hooshang_act1.res")
	add_child(layer)
	var original := layer.tile_set
	var original_sources := original.get_source_count()
	for x in 60:
		layer.set_cell(Vector2i(x, 0), 32, Vector2i(1, 0))
	layer.set_cell(Vector2i(0, 1), 32, Vector2i(5, 0)) # glowing panel
	layer.set_cell(Vector2i(1, 1), 32, Vector2i(14, 0)) # scaffold
	RULE.apply(layer)
	var variants := {}
	var snapshot := {}
	for cell in layer.get_used_cells():
		var source := layer.get_cell_source_id(cell)
		snapshot[cell] = source
		if cell.y == 0:
			variants[source] = true
			check(layer.get_cell_atlas_coords(cell) == Vector2i(1, 0), "Variant preserves edge topology")
			var before := (original.get_source(32) as TileSetAtlasSource).get_tile_data(Vector2i(1, 0), 0)
			var after := layer.get_cell_tile_data(cell)
			check(after.get_collision_polygon_points(0, 0) == before.get_collision_polygon_points(0, 0), "Variant preserves collision geometry")
	print("Variant sources: ", variants, " source texture: ", (original.get_source(32) as TileSetAtlasSource).texture.resource_path)
	check(variants.size() == 4, "Same topology must use all four visual choices")
	check(original.get_source_count() == original_sources, "Shared imported tileset must remain untouched")
	check(layer.get_cell_source_id(Vector2i(0, 1)) == 32, "Lighting panel must stay unchanged")
	check(layer.get_cell_source_id(Vector2i(1, 1)) == 32, "Scaffold keeps its specialized variant system")
	var count := layer.tile_set.get_source_count()
	RULE.apply(layer)
	check(layer.tile_set.get_source_count() == count, "Repeat application must not accumulate atlases")
	for cell in snapshot:
		check(layer.get_cell_source_id(cell) == snapshot[cell], "Repeat application must not reshuffle tiles")
	# Saved imports retain variant metadata and texture/collision properties.
	layer.owner = self
	var packed := PackedScene.new()
	packed.pack(self)
	var copy := packed.instantiate()
	var restored := copy.get_node("Collisions") as TileMapLayer
	RULE.apply(restored)
	check(restored.tile_set.get_source_count() == count, "Packed import remains idempotent")
	copy.free()
	print("TERRAIN VARIATION: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
