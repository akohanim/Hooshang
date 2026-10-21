extends Node
## Safe initial landing in Act III's first room, and the act's themed hazards
## imported with the Act 3 art. Optional raster capture.
##
## This used to pin the old single showcase room's exact contents; Act III's
## rooms are now drawn by tools/build_act3_world.py, so the entity checks look
## across the whole act. Beats are off: the opening holds him for its cutscene.
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act3_Level_0"
	var world: LdtkWorld = load("res://ldtk/Act3World.tscn").instantiate()
	world.set_meta("no_beats", true)
	Screen.set_scene(world)
	for i in 10:
		await get_tree().physics_frame
	assert(world.current_room != null and world.current_room.name == "Act3_Level_0")
	var deaths := [0]
	world.player.died.connect(func(): deaths[0] += 1)
	for i in 120:
		await get_tree().physics_frame
	assert(deaths[0] == 0 and world.player.is_on_floor(), "Starter room must have a safe, stable spawn")
	var counts := {"thoughts":0, "ladders":0, "spikes":0}
	for room in world.rooms:
		for entity in room.get_node("Entities").get_children():
			if entity is Jellyfish:
				continue
			if entity is DarkThought:
				counts.thoughts += 1
				assert(entity.palette == DarkThought.Palette.PSYCHEDELIC)
			elif entity is Ladder:
				counts.ladders += 1
				assert(entity.psychedelic_palette)
			elif entity is ConeSpikes:
				counts.spikes += 1
				assert(entity.psychedelic_palette)
	assert(counts.thoughts > 0 and counts.ladders > 0 and counts.spikes > 0)
	if "--capture" in OS.get_cmdline_user_args():
		# A hidden/occluded macOS game window may stop automatic draw signals.
		# Force this review frame instead of waiting indefinitely for one.
		RenderingServer.force_draw()
		var shot := Screen.viewport.get_texture().get_image()
		shot.resize(1280,720,Image.INTERPOLATE_NEAREST)
		shot.save_png("res://assets/act3/showcase_room.png")
	print("PASS: Act III opens on a safe spawn; every thought, ladder and spike strip wears the Act 3 art")
	get_tree().quit()
