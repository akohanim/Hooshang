extends Node
## Safe initial landing and imported showcase entities. Optional raster capture.
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act3_Level_0"
	var world: LdtkWorld = load("res://ldtk/Act3World.tscn").instantiate()
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
	for entity in world.current_room.get_node("Entities").get_children():
		if entity is DarkThought:
			counts.thoughts += 1
			assert(entity.palette == DarkThought.Palette.PSYCHEDELIC)
		elif entity is Ladder:
			counts.ladders += 1
			assert(entity.height == 56 and entity.psychedelic_palette)
		elif entity is ConeSpikes:
			counts.spikes += 1
			assert(entity.psychedelic_palette)
	assert(counts == {"thoughts":2, "ladders":1, "spikes":1})
	if "--capture" in OS.get_cmdline_user_args():
		# A hidden/occluded macOS game window may stop automatic draw signals.
		# Force this review frame instead of waiting indefinitely for one.
		RenderingServer.force_draw()
		var shot := Screen.viewport.get_texture().get_image()
		shot.resize(1280,720,Image.INTERPOLATE_NEAREST)
		shot.save_png("res://assets/act3/showcase_room.png")
	print("PASS: Act 3 showcase loads, spawn stays safe, themed entities are imported")
	get_tree().quit()
