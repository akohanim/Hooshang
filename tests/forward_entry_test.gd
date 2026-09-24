extends Node
## Regression: Act 2's Level_2 overwrote Act 1's packed room, removing its
## PlayerStart and floor. Exercise the imported assets AND the real exit Area.
var failures := 0

func _ready() -> void:
	_check_imports()
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	# This test owns input; dialogue and tutorial directors are tested separately.
	for child in world.get_children():
		if child.get_script() != null and child.get_script().resource_path in [
			"res://scripts/act1_beats.gd", "res://scripts/dash_tutorial.gd",
			"res://scripts/jump_tutorial.gd"]:
			world.remove_child(child)
			child.free()
	add_child(world)
	for i in 10:
		await get_tree().physics_frame
	var one: Node2D
	var two: Node2D
	for room in world.rooms:
		if room.name == "Level_1": one = room
		if room.name == "Level_2": two = room
	_check(one != null and two != null, "both opening rooms exist")
	if one != null and two != null:
		var deaths: Array[int] = [0]
		world.player.died.connect(func(): deaths[0] += 1)
		world._enter_room(one, true)
		world.player.velocity = Vector2.ZERO
		world.player.global_position = world._exit_in(one).global_position
		for i in 180:
			await get_tree().physics_frame
			if world.current_room == two and not world._transitioning:
				break
		_check(world.current_room == two, "Level_1 exit enters Level_2")
		_check(not world.player.input_locked, "arrival releases controls")
		for i in 180:
			await get_tree().physics_frame
		_check(deaths[0] == 0, "arrival and three seconds idle cause no death")
		_check(world.player.is_on_floor(), "arrival settles on a solid floor")
		_check(world.player.global_position.distance_to(two.global_position + Vector2(24, 170)) < 4.0,
			"arrival uses Act 1's authored entrance, not a room-center fallback")
		world.player.die()
		for i in 240:
			await get_tree().physics_frame
		_check(deaths[0] == 1, "one deliberate death never becomes a respawn death loop")
		_check(world.current_room == two and world.player.is_on_floor(),
			"respawn remains safely on Level_2's entrance floor")
	world.queue_free()
	await get_tree().process_frame
	print("FORWARD ENTRY: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func _check_imports() -> void:
	var paths := {}
	for project in ["hooshang_act1", "hooshang_act2", "hooshang_act3"]:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/%s.ldtk" % project))
		var imported: Node = load("res://ldtk/%s.ldtk" % project).instantiate()
		var config := ConfigFile.new()
		config.load("res://ldtk/%s.ldtk.import" % project)
		var packed_rooms: bool = config.get_value("params", "pack_levels", true)
		var valid := true
		for definition: Dictionary in source.levels:
			var room := imported.get_node_or_null(NodePath(definition.identifier)) as LDTKLevel
			if room == null:
				valid = false
				_check(false, "%s/%s exists" % [project, definition.identifier])
				continue
			var expected := "res://ldtk/levels/%s/%s.scn" % [project, definition.identifier]
			if packed_rooms and (room.scene_file_path != expected or paths.has(room.scene_file_path)):
				valid = false
				_check(false, "%s/%s has an isolated packed scene" % [project, definition.identifier])
			if packed_rooms:
				paths[room.scene_file_path] = true
			# The world can override the root IID even when the linked scene is
			# wrong. Check the standalone asset, whose children actually get used.
			var standalone: LDTKLevel = room
			if packed_rooms:
				var packed := load(room.scene_file_path) as PackedScene
				if packed == null:
					_check(false, "packed room loads: " + expected)
					continue
				standalone = packed.instantiate()
			if standalone.iid != definition.iid:
				valid = false
				_check(false, "%s/%s packed IID matches its own source" % [project, definition.identifier])
			for layer: Dictionary in definition.layerInstances:
				for entity: Dictionary in layer.entityInstances:
					if entity.__identifier == "PlayerStart":
						var start := standalone.get_node_or_null("Entities/PlayerStart") as Node2D
						if start == null:
							valid = false
							_check(false, "%s/%s preserves PlayerStart" % [project, definition.identifier])
			if packed_rooms:
				standalone.free()
		_check(valid, "%s packed rooms match the source and cannot overwrite another act" % project)
		imported.free()

func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
