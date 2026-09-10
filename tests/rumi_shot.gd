extends Node
## Render the replacement through the real 320x180 game surface.
## Run windowed: Godot --path . res://tests/rumi_shot.tscn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_3"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	print("RUMI RENDER: world loaded")
	for i in 80:
		await get_tree().physics_frame
	print("RUMI RENDER: settled")
	var player := world.player
	player.input_locked = true
	(player.get_node("Camera2D") as Camera2D).position_smoothing_enabled = false
	var rumi := LdtkRumiTrigger.staged(player.global_position + Vector2(24, 0))
	world.add_child(rumi)
	await rumi.appear()
	print("RUMI RENDER: appeared")
	var sprite: AnimatedSprite2D = rumi.get_node("Rumi")
	sprite.flip_h = true
	for clip: StringName in [&"idle", &"walk", &"give_glow"]:
		sprite.play(clip)
		sprite.pause()
		sprite.frame = 3 if clip == &"give_glow" else 0
		await RenderingServer.frame_post_draw
		var img := Screen.viewport.get_texture().get_image()
		img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		img.save_png("res://output/imagegen/rumi-animations/game_%s.png" % clip)
	print("RUMI RENDER: captured idle, walk and give_glow")
	get_tree().quit()
