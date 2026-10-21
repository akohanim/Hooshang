@tool
extends RefCounted
## Act III's level import step, run from ldtk_level_post_import.gd for every
## `Act3_` room AFTER the generic pass (so the ordinary entities — PlayerStart,
## Lemon, Checkpoint, the red-rimmed spikes and thoughts, CrumblingPlatform,
## RumiTrigger — are already built by ldtk_entities_post_import.gd).
##
## What it adds: the room's SeaRoom (geometry, water, backdrop and colour, built
## at runtime from the semantic `Collision` grid), the room's metadata from
## resources/levels/act3_rooms.json (written by tools/build_act3_world.py from
## the same table that draws the rooms), and the sea's own entities.

const ROOMS_JSON := "res://resources/levels/act3_rooms.json"


static func apply(level: LDTKLevel) -> LDTKLevel:
	var meta := _room_meta(str(level.name))
	level.set_meta("fixed_depth", float(meta.get("fixed_depth", -1.0)))
	level.set_meta("horizon", float(meta.get("horizon", -1.0)))
	level.set_meta("title", str(meta.get("title", "")))
	level.set_meta("chapter", int(meta.get("chapter", 0)))
	level.set_meta("mode", str(meta.get("mode", "")))
	# The way home ('land' rooms): their own terrain colours and painted backdrop.
	for key in ["terrain_fill", "terrain_line"]:
		if meta.has(key):
			var c: Array = meta[key]
			level.set_meta(key, Vector3(float(c[0]), float(c[1]), float(c[2])))
	if meta.has("backdrop"):
		level.set_meta("backdrop", str(meta["backdrop"]))
	var entities := level.get_node("Entities") as LDTKEntityLayer
	for data: Dictionary in entities.entities:
		var node := _build(data, str(level.name))
		if node == null:
			continue
		node.position = Vector2(data.position)
		if node is InkFlood:
			node.position -= (node as InkFlood).size * 0.5
		entities.add_child(node)
		node.owner = level
	_clip_rumi_pillars(level, entities)
	var room := preload("res://scenes/props/sea/SeaRoom.tscn").instantiate()
	level.add_child(room)
	room.owner = level
	return level


## A Rumi trigger is a 320px PILLAR (ldtk_entities_post_import.gd), so jumping
## over him cannot skip the beat. That assumes rooms sit side by side. The sea
## STACKS them, and a pillar centred near a room's top reaches up into the room
## above: room 4's gift fired while he was still swimming down through room 3,
## and played there. Each pillar is cut to its own room. It still spans that
## room top to bottom.
static func _clip_rumi_pillars(level: LDTKLevel, entities: Node) -> void:
	var height := float(Vector2(level.size).y)
	for trigger in entities.get_children():
		if not str(trigger.name).begins_with("RumiTrigger"):
			continue
		for shape in trigger.get_children():
			var rect := (shape as CollisionShape2D).shape as RectangleShape2D if shape is CollisionShape2D else null
			if rect == null:
				continue
			var centre := (trigger as Node2D).position.y + (shape as Node2D).position.y
			var top := maxf(centre - rect.size.y * 0.5, 0.0)
			var bottom := minf(centre + rect.size.y * 0.5, height)
			rect.size.y = maxf(bottom - top, 1.0)
			(shape as Node2D).position.y = (top + bottom) * 0.5 - (trigger as Node2D).position.y


static func _room_meta(room_name: String) -> Dictionary:
	if not FileAccess.file_exists(ROOMS_JSON):
		return {}
	var all: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOMS_JSON))
	if all is Dictionary and (all as Dictionary).has(room_name):
		return all[room_name]
	return {}


static func _build(data: Dictionary, room_name: String) -> Node2D:
	var f: Dictionary = data.fields
	match str(data.identifier):
		"Current":
			var current := SeaCurrent.new()
			current.name = "Current"
			current.size = Vector2(data.size)
			current.flow = Vector2(_num(f, "FlowX", 0.0), _num(f, "FlowY", 0.0))
			return current
		"AirBubble":
			var bubble := AirBubble.new()
			bubble.name = "AirBubble"
			return bubble
		"Jellyfish":
			var jelly: Jellyfish = preload("res://scenes/props/sea/Jellyfish.tscn").instantiate()
			match _enum(f, "Motion"):
				"Horizontal": jelly.motion = DarkThought.Motion.HORIZONTAL
				"Circle": jelly.motion = DarkThought.Motion.CIRCLE
				"Linear": jelly.motion = DarkThought.Motion.LINEAR
				_: jelly.motion = DarkThought.Motion.VERTICAL
			jelly.amplitude = absf(_num(f, "Amplitude", 16.0))
			jelly.speed = _num(f, "Speed", 0.5)
			jelly.phase = _num(f, "Phase", 0.0)
			jelly.angle = _num(f, "Angle", 0.0)
			jelly.clockwise = _num(f, "Clockwise", 1.0) > 0.0
			jelly.z_index = 3
			return jelly
		"Memory":
			var memory := SeaMemory.new()
			memory.name = "Memory"
			memory.kind = _str(f, "Kind", "nameplate")
			memory.lines = _str(f, "Lines", "")
			memory.memory_id = "%s:%s" % [room_name, memory.kind]
			return memory
		"InkFlood":
			var ink := InkFlood.new()
			ink.name = "InkFlood"
			ink.size = Vector2(data.size)
			ink.speed = _num(f, "Speed", 34.0)
			ink.acceleration = _num(f, "Acceleration", 0.0)
			ink.start_depth = _num(f, "StartDepth", 4.0)
			# Placed by its centre like every entity; the flood draws from its
			# top-left corner.
			ink.set_meta("centred", true)
			return ink
		"SeaDecor":
			var decor := SeaDecor.new()
			decor.name = "Decor"
			decor.kind = _str(f, "Kind", "rock")
			decor.height = int(_num(f, "Height", 1.0))
			decor.flip = _num(f, "Flip", 0.0) > 0.0
			return decor
		"Marker":
			var mark := Marker2D.new()
			mark.name = _str(f, "Name", "Marker")
			return mark
	return null


static func _str(f: Dictionary, key: String, fallback: String) -> String:
	var raw = f.get(key)
	return raw if raw is String and raw != "" else fallback


static func _num(f: Dictionary, key: String, fallback: float) -> float:
	var raw = f.get(key)
	return float(raw) if raw is float or raw is int else fallback


## An LDtk enum arrives QUALIFIED ("ThoughtMotion.Circle") — see
## ldtk_entities_post_import.gd's _field_enum for the bug this prevents.
static func _enum(f: Dictionary, key: String) -> String:
	var raw = f.get(key)
	if not (raw is String):
		return ""
	var dot := (raw as String).rfind(".")
	return (raw as String).substr(dot + 1) if dot >= 0 else raw
