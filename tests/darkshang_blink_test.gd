extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_14"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 20: await get_tree().physics_frame
	var shadow: Darkshang = get_tree().get_first_node_in_group("darkshang")
	var trigger: DarkshangTrigger
	for node in get_tree().get_nodes_in_group("darkshang_trigger"):
		if world.current_room.is_ancestor_of(node): trigger = node
	world.player.global_position = trigger.global_position + Vector2(-12, 0)
	trigger._on_body_entered(world.player)
	for i in 100: await get_tree().physics_frame
	var visual: DarkshangVisual = shadow._visual
	var sprite: AnimatedSprite2D = visual._sprite
	var eyes: Node2D = sprite.get_node("IdleEyes")
	eyes.set_process(false)
	eyes.age = 0.0
	eyes._process(0.0)
	check(Dialogue.visible and world.player.input_locked, "actual opening dialogue is active")
	check(eyes.is_visible_in_tree() and eyes.openness == 1.0 and sprite.modulate.a == 1.0,
		"enlarged encounter idle has visible open eyes")
	check(visual.scale == Vector2.ONE * 1.5, "eyes inherit the 250 percent encounter size")
	check(eyes.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED,
		"eyes stay readable in the dark room")
	if OS.get_cmdline_user_args().has("--capture"):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		DirAccess.make_dir_recursive_absolute("res://output/darkshang")
		Screen.viewport.get_texture().get_image().save_png("res://output/darkshang/encounter_eyes.png")
	eyes.age = eyes.blink_interval - eyes.blink_duration * 0.9
	eyes._process(0)
	check(eyes.openness == 0.5, "blink begins half closed")
	eyes._process(eyes.blink_duration * 0.4)
	check(eyes.openness == 0.0, "blink closes")
	eyes._process(eyes.blink_duration * 0.3)
	check(eyes.openness == 0.5, "blink reopens halfway")
	eyes._process(eyes.blink_duration * 0.3)
	check(eyes.openness == 1.0, "eyes reopen while dialogue remains active")
	sprite.frame = 1
	eyes._process(0)
	check(eyes.position.y == -1, "eyes follow the breathing pose")
	visual.set_motion(1, Vector2(-55, 0))
	eyes._process(0)
	check(not eyes.visible, "moving sprite keeps its own eyes without an overlay")
	print("DARKSHANG BLINK: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
