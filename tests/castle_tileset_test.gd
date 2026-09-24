extends Node
## Check saved LDtk imports, then paint a real tile on each kind of layer and
## query physics: masonry is solid, background walls and decorations are not.
var failures := 0

func _ready() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/hooshang_act2.ldtk"))
	var imported: Node = load("res://ldtk/hooshang_act2.ldtk").instantiate()
	var sheets := {}
	for definition: Dictionary in source.defs.tilesets:
		if definition.identifier in ["Act2CastleMasonry", "Act2CastleDecor"]:
			sheets[definition.identifier] = definition
	check(sheets.size() == 2, "both castle sheets are registered")
	var layer_names := ["CastleTerrain", "CastleBackground", "CastleDecor"]
	for definition: Dictionary in source.levels:
		var room := imported.get_node(NodePath(definition.identifier))
		for layer_name: String in layer_names:
			var layer := room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
			check(layer != null, definition.identifier + " has " + layer_name)
			if layer == null: continue
			check(layer.tile_set.tile_size == Vector2i(8, 8), "castle layer uses the 8px grid")
			check(layer.collision_enabled == (layer_name == "CastleTerrain"), "correct solid/scenery collision")
			if layer_name != "CastleTerrain":
				check(layer.z_index < 0, "castle scenery draws behind the player")
	var first_room := imported.get_node(NodePath(source.levels[0].identifier))
	for i in layer_names.size():
		var template := first_room.get_node(NodePath(layer_names[i])) as TileMapLayer
		var sheet: Dictionary = sheets["Act2CastleDecor" if i == 2 else "Act2CastleMasonry"]
		var atlas := template.tile_set.get_source(int(sheet.uid)) as TileSetAtlasSource
		check(atlas.texture.get_size() == Vector2(sheet.pxWid, sheet.pxHei), "original sheet dimensions preserved")
		check(atlas.get_tiles_count() > 0, "atlas contains paintable tiles")
		var layer := TileMapLayer.new()
		layer.tile_set = template.tile_set
		layer.collision_enabled = template.collision_enabled
		layer.position = Vector2(10000 + i * 32, 10000)
		add_child(layer)
		layer.set_cell(Vector2i.ZERO, int(sheet.uid), atlas.get_tile_id(0))
		layer.update_internals()
		for frame in 3: await get_tree().physics_frame
		var query := PhysicsPointQueryParameters2D.new()
		query.position = layer.global_position + Vector2(4, 4)
		query.collision_mask = 1
		var hits := layer.get_world_2d().direct_space_state.intersect_point(query)
		check(not hits.is_empty() if i == 0 else hits.is_empty(), "painted " + layer_names[i] + " has correct physics")
		layer.queue_free()
	imported.free()
	print("CASTLE TILESET: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		failures += 1
