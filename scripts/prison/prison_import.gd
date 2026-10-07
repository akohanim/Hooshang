@tool
extends RefCounted
## Scope prison entities and semantic collision to the authored prison levels.
static func apply(level: LDTKLevel) -> LDTKLevel:
	var entities := level.get_node("Entities") as LDTKEntityLayer
	for child in entities.get_children():
		if child.name == &"NodePathResolver": continue
		entities.remove_child(child)
		child.free()
	for child in level.find_children("*", "TileMapLayer", true, false):
		if child is TileMapLayer:
			child.collision_enabled = false
			if str(child.name).ends_with("-values"):
				child.visible = false
			if child.name == &"Decor": child.z_index = -2
	var geometry := preload("res://scenes/props/prison/PrisonRoom.tscn").instantiate()
	level.add_child(geometry)
	geometry.owner = level
	for data: Dictionary in entities.entities:
		var node: Node2D
		match str(data.identifier):
			"PlayerSpawn":
				node = Marker2D.new()
				node.name = "PlayerStart"
			"Key", "Cage", "ShortcutDoor", "PrisonSign", "Checkpoint":
				node = preload("res://scenes/props/prison/PrisonProp.tscn").instantiate()
				node.kind = str(data.identifier)
				node.entity_iid = str(data.iid)
				node.fields = data.fields.duplicate(true)
				node.prop_size = Vector2(data.size)
			"Jamshid":
				node = preload("res://scenes/characters/jamshid/Jamshid.tscn").instantiate()
				node.name = "PrisonJamshid"
			"DarkThought":
				node = preload("res://scenes/props/prison/PrisonProp.tscn").instantiate()
				node.kind = "Patrol"
				node.fields = data.fields.duplicate(true)
			_:
				continue
		node.position = Vector2(data.position)
		entities.add_child(node)
		node.owner = level
		preload("res://addons/ldtk-importer/src/util/util.gd").update_instance_reference(str(data.iid),node)
	return level
