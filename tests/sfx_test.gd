extends Node
## The Sfx autoload (systems/sfx.gd): every cue's variations load, footsteps
## pick the right surface (Act 1 scaffolding read off the actual tile under his
## feet; Act 2 gardens grass; the prison stone), and real input fires the moves
## — footsteps only on scaffolding (and quietly), silence on grass and stone,
## a jump makes a jump; a death plays the deep oom and the respawn is silent. Sfx.muted keeps the run silent; Sfx.history records
## what WOULD have played.
var failures := 0


func _ready() -> void:
	SaveGame.slot = -1
	Sfx.muted = true
	for cue: StringName in Sfx.CUES:
		check(Sfx._streams[cue].size() == int(Sfx.CUES[cue][0]), "%s: all %d variations load" % [cue, Sfx.CUES[cue][0]])

	LdtkWorld.debug_start_room = "Act_2_Level_3"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	for i in 30: await get_tree().physics_frame
	var world := Screen.current as LdtkWorld
	var player := world.player
	check(Sfx.surface_cue(player) == &"", "garden grass makes no footstep")

	Sfx.history.clear()
	Input.action_press("move_right")
	for i in 40: await get_tree().physics_frame
	Input.action_release("move_right")
	check(Sfx.history.is_empty(), "running on grass is silent: %s" % [Sfx.history])
	for i in 30: await get_tree().physics_frame
	Sfx.history.clear()
	Input.action_press("jump")
	for i in 90:
		await get_tree().physics_frame
		if i > 10 and player.is_on_floor(): break
	Input.action_release("jump")
	check(&"jump" in Sfx.history, "a jump makes the jump sound")

	Sfx.history.clear()
	player.die()
	for i in 90:
		await get_tree().physics_frame
		if player.state != Player.State.DEAD: break
	check(Sfx.history == [&"death"], "a death plays the oom, once, and the respawn is silent: %s" % [Sfx.history])

	for room in world.rooms:
		if str(room.name) == "Prison_Hub":
			world._enter_room(room, true)
			player.respawn(world.spawn_point_for(room))
			for i in 20: await get_tree().physics_frame
			check(Sfx.surface_cue(player) == &"", "the prison stone floor makes no footstep")

	LdtkWorld.debug_start_room = "Level_15"
	Screen.load_scene("res://ldtk/Act1World.tscn")
	for i in 30: await get_tree().physics_frame
	world = Screen.current as LdtkWorld
	player = world.player
	# Stand him on a cell LDTK itself marks scaffolding (IntGrid 5) with open
	# air above — not one found by the same tile rule Sfx uses.
	var project: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/hooshang_act1.ldtk"))
	var found := false
	for level: Dictionary in project.levels:
		if level.identifier != "Level_15": continue
		for li: Dictionary in level.layerInstances:
			if li.__identifier != "Collisions": continue
			var w: int = li.__cWid
			var csv: Array = li.intGridCsv
			for i in csv.size():
				if found: break
				if int(csv[i]) != 5 or i < 2 * w or int(csv[i - w]) != 0 or int(csv[i - 2 * w]) != 0: continue
				player.global_position = world.current_room.global_position + Vector2((i % w) * 8 + 4, (i / w) * 8 - 7)
				for f in 10: await get_tree().physics_frame
				if player.is_on_floor():
					found = true
					check(Sfx.surface_cue(player) == &"step_scaffold", "Darkshang scaffolding is read off the tile under his feet")
					Sfx.history.clear()
					Input.action_press("move_right")
					for f in 30: await get_tree().physics_frame
					Input.action_release("move_right")
					check(&"step_scaffold" in Sfx.history, "running on scaffolding makes footsteps")
					var p: Array = Sfx.CUES[&"step_scaffold"]
					check(float(p[1]) <= -22.0, "scaffold footsteps sit well under everything else")
					for cue in [&"crumble_warn", &"crumble_break"]:
						check(float(Sfx.CUES[cue][1]) <= -28.0, "%s is muted like the footsteps" % cue)
	check(found, "found a scaffold deck to stand on in Level_15")
	print("SFX: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
