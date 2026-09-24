extends Node
## Proves Act 3 field defaults select the new runtime art through the actual
## import builders, while old projects without the field keep their art.

func _ready() -> void:
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()
	var project: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/hooshang_act3.ldtk"))
	for definition: Dictionary in project.defs.entities:
		var identifier: String = definition.identifier
		if identifier not in ["DarkThought", "LightThought", "GreyThought", "Ladder"] and not identifier.begins_with("ConeSpikes") and not identifier.begins_with("GlassSpikes"):
			continue
		var fields := {}
		for field: Dictionary in definition.fieldDefs:
			if field.defaultOverride != null:
				fields[field.identifier] = field.defaultOverride.params[0]
		var data := {"identifier": identifier, "position": Vector2.ZERO,
			"size": Vector2(definition.width, definition.height), "fields": fields}
		if identifier.begins_with("ConeSpikes") or identifier.begins_with("GlassSpikes"):
			var facing := 1 if identifier.ends_with("Ceiling") else 2 if identifier.ends_with("LeftWall") else 3 if identifier.ends_with("RightWall") else 0
			var spikes: Area2D = importer._build_cone_spikes(data, facing) if identifier.begins_with("ConeSpikes") else importer._build_glass_spikes(data, facing)
			add_child(spikes)
			assert(spikes.psychedelic_palette)
			var tile: AtlasTexture = spikes._tile(0)
			assert(tile.atlas.resource_path.begins_with("res://assets/act3/"))
			var pixels: Image = tile.atlas.get_image()
			var red_count := 0
			for y in pixels.get_height():
				for x in pixels.get_width():
					var pixel := pixels.get_pixel(x, y)
					if pixel.r > 0.9 and pixel.g < 0.3 and pixel.a == 1.0:
						red_count += 1
			assert(red_count >= 20, "Each spike facing keeps a visible red outline")
			spikes.free()
		elif identifier == "Ladder":
			var ladder: Ladder = importer._build_ladder(data)
			add_child(ladder)
			assert(ladder.psychedelic_palette)
			assert(ladder._rungs.get_child(0).texture.resource_path == "res://assets/act3/ladder.png")
			assert(ladder._shape.shape.size.x == 8.0)
			ladder.free()
		else:
			var thought: DarkThought = importer._build_thought(data)
			add_child(thought)
			assert(thought.palette == DarkThought.Palette.PSYCHEDELIC)
			assert(thought._sheets()[thought.tone].resource_path.begins_with("res://assets/act3/"))
			assert(thought.light_color.r > 0.9 and thought.light_color.g < 0.3)
			var pixels: Image = thought._sheets()[thought.tone].get_image()
			for frame in 4:
				var rim := pixels.get_pixel(frame * 16 + 6, 2)
				assert(rim.r > 0.9 and rim.g < 0.3 and rim.a == 1.0)
			thought.free()
	var legacy := {"identifier":"DarkThought", "position":Vector2.ZERO,
		"size":Vector2(16,16), "fields":{}}
	var old: DarkThought = importer._build_thought(legacy)
	assert(old.palette == DarkThought.Palette.OFFICE)
	old.free()
	var packed: PackedScene = load("res://ldtk/hooshang_act3.ldtk")
	assert(packed != null)
	var imported := packed.instantiate()
	assert(imported.get_child_count() > 0)
	var collisions := imported.find_child("Collisions", true, false) as TileMapLayer
	assert(collisions != null)
	var found_terrain := false
	for index in collisions.tile_set.get_source_count():
		var source := collisions.tile_set.get_source(collisions.tile_set.get_source_id(index)) as TileSetAtlasSource
		if source != null and source.texture.resource_path == "res://assets/act3/terrain.png":
			assert(source.get_tiles_count() == 696)
			found_terrain = true
	assert(found_terrain, "The saved imported tileset must contain the new Act 3 atlas")
	imported.free()
	print("PASS: Act 3 imported world/atlas, thought palettes/red rims, eight red spike variants, ladder art/collider, legacy defaults")
	get_tree().quit()
