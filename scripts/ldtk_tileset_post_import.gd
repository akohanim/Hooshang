@tool
## LDtk tileset post-import hook (see STYLE_GUIDE.md §9), wired as this .ldtk
## project's `tileset_post_import`. Runs on EVERY import, after all tile
## sources are built but before the TileSet is saved.
##
## The importer's auto-generated TileSet only carries visual atlas data —
## it never adds a physics layer or per-tile collision shapes on its own.
## Doing this by hand once (via a one-off script driving the TileSet API)
## worked, but got silently wiped the next time the tileset needed a full
## rebuild (e.g. after adding new tiles in LDtk). Running it here instead
## means collision is regenerated automatically every reimport — nothing to
## redo, ever.
##
## This project's tiles are all simple full-square solids (a greybox
## side-scroller platformer, no slopes) — see tools/gen_level*.py, which use
## the same "every placed tile is fully solid" convention — so every tile in
## every source just gets a full 16x16 collision square.

func post_import(tilesets: Dictionary) -> Dictionary:
	for tile_set: TileSet in tilesets.values():
		_ensure_full_tile_collision(tile_set)
	return tilesets


func _ensure_full_tile_collision(tile_set: TileSet) -> void:
	if tile_set.get_physics_layers_count() == 0:
		tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(0, 1)  # world layer, matches project convention
		tile_set.set_physics_layer_collision_mask(0, 0)

	var half := Vector2(tile_set.tile_size) * 0.5
	var full_square := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])

	for i in tile_set.get_source_count():
		var source_id := tile_set.get_source_id(i)
		var raw_source := tile_set.get_source(source_id)
		if raw_source is not TileSetAtlasSource:
			continue
		var source: TileSetAtlasSource = raw_source
		for t in source.get_tiles_count():
			var coord := source.get_tile_id(t)
			for a in source.get_alternative_tiles_count(coord):
				var alt_id := source.get_alternative_tile_id(coord, a)
				var data: TileData = source.get_tile_data(coord, alt_id)
				if data.get_collision_polygons_count(0) == 0:
					data.set_collision_polygons_count(0, 1)
					data.set_collision_polygon_points(0, 0, full_square)
