extends Node
var failures := 0

func check(ok: bool, message: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _ready() -> void:
	SaveGame.slot = -1
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/hooshang_act1.ldtk"))
	var target := Node2D.new()
	target.add_to_group("player")
	add_child(target)
	var painted := 0
	var converted_counts := {"Level_25": 60, "Level_24": 109, "Level_23": 60, "Level_22": 70, "Level_21": 94, "TEST": 9, "Level_19": 310}
	for room: Dictionary in data.levels:
		var packed: PackedScene = load("res://ldtk/levels/hooshang_act1/%s.scn" % room.identifier)
		var instance := packed.instantiate()
		add_child(instance)
		var layer: TileMapLayer = instance.get_node("ThoughtHazards")
		check(not layer.collision_enabled, "%s is pass-through" % room.identifier)
		check(layer.get_script().resource_path.ends_with("ldtk_dust_hazard_layer.gd"), "%s uses office dust" % room.identifier)
		for source: Dictionary in room.layerInstances:
			for entity: Dictionary in source.entityInstances:
				if "Spikes" in str(entity.__identifier): check(false, "spike entity remains")
			if source.__identifier == "ThoughtHazards":
				var count := 0
				for i in source.intGridCsv.size():
					if source.intGridCsv[i] != 0:
						count += 1
						if layer.get_cell_source_id(Vector2i(i % int(source.__cWid), i / int(source.__cWid))) == -1:
							check(false, "painted source cell missing from import")
				check(layer.get_used_cells().size() == count, "%s exact paint count" % room.identifier)
				painted += count
				if converted_counts.has(room.identifier):
					check(count == converted_counts[room.identifier], "%s retains converted spike footprint" % room.identifier)
		if layer.dust != null:
			var dust: Node2D = layer.dust
			dust.set_process(false)
			var cells := layer.get_used_cells()
			dust._process(0.5)
			check(is_equal_approx(dust.elapsed, 0.5), "dust clock advances")
			check(layer.get_used_cells() == cells, "animation leaves hazard footprint fixed")
			if not dust.eyes.is_empty():
				var eye: Dictionary = dust.eyes[0]
				eye.follow = true
				eye.direction = Vector2.DOWN
				target.global_position = dust.to_global(Vector2(eye.position) + Vector2(100, 0))
				dust._process(0.05)
				check(Vector2(eye.direction).distance_to(Vector2.RIGHT) < Vector2.DOWN.distance_to(Vector2.RIGHT), "eyes turn toward player independently")
				dust.elapsed = float(eye.period) - 0.25 - float(eye.lag) * 0.5 - float(eye.phase)
				check(dust.eye_visibility(eye) == Vector2i(0, 1), "left eye closes before right")
				dust.elapsed += float(eye.lag)
				check(dust.eye_visibility(eye) == Vector2i.ZERO, "both eyes shut during blink")
				dust.elapsed += 0.26
				check(dust.eye_visibility(eye) == Vector2i.ONE, "eyes reopen after blink")
		instance.free()
	check(painted >= 712, "all converted cells present")
	# Other Acts retain their original driver and atlas animations.
	for act in ["hooshang_act3"]:
		var files := DirAccess.get_files_at("res://ldtk/levels/%s" % act)
		var instance: Node = load("res://ldtk/levels/%s/%s" % [act, files[0]]).instantiate()
		var layer := instance.get_node_or_null("ThoughtHazards")
		if layer: check(layer.get_script() == load("res://scripts/ldtk_thought_hazard_layer.gd"), "%s presentation unchanged" % act)
		instance.free()
	print("ACT1 DUST: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
