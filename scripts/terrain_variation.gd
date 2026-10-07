@tool
extends RefCounted
## Stable visual choices for legacy masonry; copied atlas sources retain every
## TileData property (collision, navigation, custom data and alternative IDs).
const TEXTURES := [
	preload("res://ldtk/art/terrain_variant_1.png"),
	preload("res://ldtk/art/terrain_variant_2.png"),
	preload("res://ldtk/art/terrain_variant_3.png"),
]
const COLUMNS := [0, 1, 2, 3, 18, 19, 20, 21, 22, 23, 24, 25]
const VARIANT_META := &"hooshang_terrain_variant"

static func apply(layer: TileMapLayer) -> void:
	if layer.tile_set == null:
		return
	var sources := {}
	var random := RandomNumberGenerator.new()
	for cell in layer.get_used_cells():
		var coord := layer.get_cell_atlas_coords(cell)
		var sid := layer.get_cell_source_id(cell)
		var source := layer.tile_set.get_source(sid) as TileSetAtlasSource
		if source == null or source.has_meta(VARIANT_META) or source.texture == null:
			continue
		if source.texture.resource_path != "res://ldtk/art/bricks_8px.png" \
			or coord.y != 0 or coord.x not in COLUMNS:
			continue
		# Leave the base tile on half the cells; all choices preserve its topology.
		random.seed = hash(str(layer.get_parent().name) + ":" + str(layer.name) + ":" + str(cell))
		var pick := random.randi_range(0, 5)
		if pick < 3:
			continue
		if sources.is_empty():
			layer.tile_set = layer.tile_set.duplicate()
		if not sources.has(sid):
			var variants: Array[int] = []
			for texture in TEXTURES:
				var copy := source.duplicate(true) as TileSetAtlasSource
				copy.texture = texture
				copy.set_meta(VARIANT_META, true)
				variants.append(layer.tile_set.add_source(copy))
			sources[sid] = variants
		layer.set_cell(cell, sources[sid][pick - 3], coord, layer.get_cell_alternative_tile(cell))
