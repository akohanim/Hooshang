extends Node
## Blank prison design baseline: sealed rooms, no spikes or routes, cage retained.
var failures: Array[String] = []

func _ready() -> void:
	SaveGame.slot = -1
	SaveGame._pending = {}
	LdtkWorld.debug_start_room = "Prison_Hub"
	var world = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	for i in 12: await get_tree().physics_frame
	check(world.portals.is_empty(), "no generated entrances or exits")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/hooshang_act2.ldtk"))
	var count := 0
	for level: Dictionary in source.levels:
		if level.identifier != "Prison_Hub" and not str(level.identifier).begins_with("Prison_"): continue
		count += 1
		var layers: Dictionary = {}
		for layer: Dictionary in level.layerInstances: layers[layer.__identifier] = layer
		for layer: Dictionary in level.layerInstances:
			if layer.__identifier in ["Collision", "PrisonMasonry", "Decor", "Entities"]: continue
			check(layer.gridTiles.is_empty() and layer.autoLayerTiles.is_empty()
				and not layer.intGridCsv.any(func(value: Variant) -> bool: return int(value) != 0),
				str(level.identifier) + " has no extra painted layer: " + str(layer.__identifier))
		var cells: Array = layers.Collision.intGridCsv
		var width: int = layers.Collision.__cWid
		var height: int = layers.Collision.__cHei
		var imported_room: Node = null
		for candidate: Node in world.rooms:
			if str(candidate.name) == str(level.identifier): imported_room = candidate
		check(imported_room != null, str(level.identifier) + " imports")
		if imported_room != null:
			var imported_masonry := imported_room.get_node("PrisonMasonry") as TileMapLayer
			for cell: Vector2i in imported_masonry.get_used_cells():
				check(cell.x in [0, width - 1] or cell.y in [0, height - 1],
					str(level.identifier) + " imported masonry stays on border")
			if level.identifier != "Prison_Hub":
				check(imported_room.get_node("Entities").get_child_count() <= 1,
					str(level.identifier) + " imports without props or spawn marker")
		check(not cells.has(2) and not cells.has(3) and not cells.has(4),
			str(level.identifier) + " has no platforms, spikes, or water")
		for x in width:
			check(cells[x] == 1 and cells[(height - 1) * width + x] == 1, str(level.identifier) + " top/bottom sealed at " + str(x))
		for y in height:
			check(cells[y * width] == 1 and cells[y * width + width - 1] == 1, str(level.identifier) + " sides sealed at " + str(y))
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				check(int(cells[y * width + x]) == 0, str(level.identifier) + " empty interior at " + str(Vector2i(x, y)))
		var entities: Array = layers.Entities.entityInstances
		check(layers.Tiles.autoLayerTiles.is_empty(), str(level.identifier) + " has no spike or water artwork")
		var solids := 0
		for value: Variant in cells:
			if int(value) == 1: solids += 1
		check(layers.PrisonMasonry.autoLayerTiles.size() == solids,
			str(level.identifier) + " sealed walls have matching masonry art")
		for entity: Dictionary in entities:
			check(entity.__identifier in ["Cage", "Jamshid"], str(level.identifier) + " has no old puzzle entity")
		if level.identifier != "Prison_Hub":
			check(entities.is_empty(), str(level.identifier) + " has no entity markers")
		if level.identifier == "Prison_Hub":
			check(entities.any(func(entity: Dictionary) -> bool: return entity.__identifier == "Cage"), "hub retains Jamshid cage")
			check(entities.any(func(entity: Dictionary) -> bool: return entity.__identifier == "Jamshid"), "Jamshid remains in cage")
	check(count == 17, "all 17 prison rooms checked")
	world.queue_free()
	print("PRISON LAYOUT RESET: ", "ALL PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
