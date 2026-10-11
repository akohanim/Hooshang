extends Node
## UI-state fixture; positions are deliberate setup, not traversal evidence.
var failures: Array[String] = []
func _ready() -> void:
	SaveGame.unbind()
	LdtkWorld.debug_start_room = "Prison_G03"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var world = Screen.current
	var hint: Label = world._shortcut_hint
	check(not hint.visible,"no remote shortcut hint at the room entrance")
	world.player.respawn(world.current_room.global_position+Vector2(216,154))
	await frames(5)
	check(hint.visible and hint.text == "GREEN KEY OPENS THIS SHORTCUT","nearby locked shortcut names its key")
	check(not hint.get_rect().intersects(world._hud.get_rect()),"context hint clears the key-count row")
	if OS.get_cmdline_user_args().has("--capture"):
		RenderingServer.force_draw()
		var out := "res://output/act2_polish/shortcut_labels"
		DirAccess.make_dir_recursive_absolute(out)
		Screen.viewport.get_texture().get_image().save_png(out+"/near_lock_native.png")
		get_tree().root.get_texture().get_image().save_png(out+"/near_lock_ui.png")
	world.player.input_locked = true
	await frames(2)
	check(not hint.visible,"dialogue lock suppresses the contextual hint")
	world.player.input_locked = false
	await frames(2)
	check(hint.visible,"hint returns with player control")
	world.collect_key("Red",Vector2.ZERO)
	check(hint.visible,"unrelated key does not hide the requirement")
	world.collect_key("Green",Vector2.ZERO)
	check(not hint.visible,"matching pickup clears the requirement immediately")
	# Both upper-door positions occurred under the old fixed left HUD.
	for room_id in ["Prison_B01", "Prison_B02", "Prison_B03", "Prison_B04"]:
		var room = world.rooms.filter(func(r): return r.name == room_id)[0]
		world._enter_room(room,true)
		world.player.respawn(world.spawn_point_for(room))
		await frames(20)
		for portal in world.portals:
			if portal.from != room or portal.direction != Vector2.UP: continue
			var marker: Vector2 = portal.center - portal.direction * 20 - room.global_position
			var hud_rect: Rect2 = world._hud.get_rect()
			hud_rect.position *= 0.25
			hud_rect.size *= 0.25
			# Horizontal separation protects the doorway across vertical camera scroll.
			check(hud_rect.end.x < marker.x - 18 or hud_rect.position.x > marker.x + 18,room_id+" upper exit clears the key HUD")
		if OS.get_cmdline_user_args().has("--capture"):
			RenderingServer.force_draw()
			get_tree().root.get_texture().get_image().save_png("res://output/act2_polish/shortcut_labels/"+room_id+"_hud.png")
	var other = world.rooms.filter(func(r): return r.name == "Act_2_Level_15")[0]
	world._enter_room(other,true)
	await frames(2)
	check(not hint.visible and not world._hud.visible,"prison HUD does not leak into the castle")
	print("SHORTCUT HINT: ","ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
