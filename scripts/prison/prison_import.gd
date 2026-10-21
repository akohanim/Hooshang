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
			if child.name == &"ThoughtHazards" or child.name == &"InkThoughtHazards":
				child.set_script(preload("res://scripts/ldtk_thought_hazard_layer.gd"))
				var material := CanvasItemMaterial.new()
				material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
				child.material = material
			if child.name == &"Decor": child.z_index = -3
			if child.name == &"CastleBackground": child.z_index = -2
			if child.name == &"CastleDecor": child.z_index = -1
	var geometry := preload("res://scenes/props/prison/PrisonRoom.tscn").instantiate()
	level.add_child(geometry)
	geometry.owner = level
	for data: Dictionary in entities.entities:
		var node: Node2D
		match str(data.identifier):
			"CastlePassage":
				node = preload("res://scenes/props/castle/CastlePassage.tscn").instantiate()
				node.destination = str(data.fields.get("Destination", "Act_2_Level_15"))
			"PlayerSpawn":
				node = Marker2D.new()
				node.name = "PlayerStart"
			"Key", "Cage", "ShortcutDoor", "PrisonSign":
				node = preload("res://scenes/props/prison/PrisonProp.tscn").instantiate()
				node.kind = str(data.identifier)
				node.entity_iid = str(data.iid)
				node.fields = data.fields.duplicate(true)
				node.prop_size = Vector2(data.size)
			"CircuitNode", "CircuitGate", "FloodValve", "FloodGate", "MusicalGate":
				node = preload("res://scenes/props/prison/circuits/PrisonCircuit.tscn").instantiate()
				node.kind = str(data.identifier)
				node.entity_iid = str(data.iid)
				node.fields = data.fields.duplicate(true)
				node.prop_size = Vector2(data.size)
			"TimedLever", "TimedGate", "TimedRelay", "TimedShutter", "PressurePlate":
				node = preload("res://scenes/props/prison/timed/TimedPuzzle.tscn").instantiate()
				node.kind = str(data.identifier)
				node.entity_iid = str(data.iid)
				node.fields = data.fields.duplicate(true)
				node.prop_size = Vector2(data.size)
			"Jamshid":
				node = preload("res://scenes/characters/jamshid/Jamshid.tscn").instantiate()
				node.name = "PrisonJamshid"
			"PrisonNote1", "PrisonNote2", "PrisonNote3", "PrisonNote4", "PrisonNote5":
				node = preload("res://scenes/props/prison/music/PrisonNote.tscn").instantiate()
				node.note_index = int(str(data.identifier).trim_prefix("PrisonNote"))
				node.entity_iid = str(data.iid)
				node.fields = data.fields.duplicate(true)
			"CrumblingShelf":
				node = preload("res://scenes/props/prison/timed/CrumblingShelf.tscn").instantiate()
				node.size = Vector2(data.size)
				node.fields = data.fields.duplicate(true)
			"CrumblingPlatform":
				node = preload("res://scenes/props/platforms/CrumblingPlatform.tscn").instantiate()
				node.size = Vector2(data.size)
			"SwimCrumblingPlatform":
				node = preload("res://scenes/props/prison/timed/SwimCrumblingPlatform.tscn").instantiate()
				node.size = Vector2(data.size)
			# The key wings' precision chains (tools/build_prison_wings.py) use
			# Act 2's ordinary springs, lemons, cone spikes and mid-room checkpoints.
			"SpringPlatform":
				node = preload("res://scenes/props/platforms/SpringPlatform.tscn").instantiate()
				node.size = Vector2(Vector2(data.size).x, Platform.CELL)
				node.refill_dash = true
				match str(data.fields.get("Facing", "")).get_slice(".", 1):
					"Right": node.rotation_degrees = 90.0
					"Left": node.rotation_degrees = -90.0
			"Lemon":
				node = preload("res://scenes/props/Lemon.tscn").instantiate()
			"Checkpoint":
				node = preload("res://scenes/props/Checkpoint.tscn").instantiate()
			"ConeSpikes", "ConeSpikesCeiling", "ConeSpikesLeftWall", "ConeSpikesRightWall":
				node = _cone_spikes(data)
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


## Same sizing rule as the ordinary Act 2 import: a strip stretches only along
## the surface it is stuck to and is one cell deep. Always the childhood palette.
static func _cone_spikes(data: Dictionary) -> Area2D:
	var spikes: Area2D = preload("res://scenes/props/hazards/ConeSpikes.tscn").instantiate()
	spikes.facing = {
		"ConeSpikes": ConeSpikes.Facing.UP, "ConeSpikesCeiling": ConeSpikes.Facing.DOWN,
		"ConeSpikesLeftWall": ConeSpikes.Facing.RIGHT, "ConeSpikesRightWall": ConeSpikes.Facing.LEFT,
	}[str(data.identifier)]
	var drawn := Vector2(data.size)
	var wall: bool = spikes.facing in [ConeSpikes.Facing.RIGHT, ConeSpikes.Facing.LEFT]
	spikes.size = Vector2(ConeSpikes.CELL, drawn.y) if wall else Vector2(drawn.x, ConeSpikes.CELL)
	spikes.palette = ConeSpikes.Palette.CHILDHOOD
	return spikes
