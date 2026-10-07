extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_19"
	var world: LdtkWorld = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(20)
	var room := world.current_room
	var player := world.player
	var boss := get_tree().get_first_node_in_group("darkshang") as Darkshang
	check(room.name == "Level_19", "new room imports and starts")
	check(world._room_before(room).name == "Level_18" and world._room_after(room).name == "Level_20", "new room sits between old course and old ladder room")
	var belts: Array[ConveyorBelt] = []
	var triggers: Array[Node] = []
	for node in room.get_node("Entities").get_children():
		if node is ConveyorBelt: belts.append(node)
		if node.is_in_group("darkshang_power_trigger"): triggers.append(node)
	check(belts.size() == 16 and belts.all(func(b): return b.drift() == 36 and b.solid and b.size.x == 120), "sixteen long solid opposing belts")
	check(triggers.size() == 5 and triggers.all(func(t): return t.power == 0), "five charge attacks, no eruptions")
	check(boss._visual.cloud_form, "cloud form enabled in this room")
	boss.stand_by()
	for t in triggers: t.set_physics_process(false)
	belts.sort_custom(func(a,b): return a.position.x > b.position.x)
	# Walk against a real belt, then jump every gap with the actual controller.
	player.respawn(belts[0].global_position + Vector2(8,-14))
	await frames(15)
	var before := player.global_position.x
	Input.action_press("move_left")
	await frames(12)
	var travel := before-player.global_position.x
	check(travel > 2 and travel < 18, "opposing belt permits leftward progress at reduced speed")
	Input.action_release("move_left")
	for i in belts.size()-1:
		player.respawn(belts[i].global_position + Vector2(-belts[i].size.x/2+8,-14))
		await frames(8)
		Input.action_press("move_left")
		Input.action_press("jump")
		await frames(15)
		Input.action_release("jump")
		Input.action_press("dash")
		await frames(1)
		Input.action_release("dash")
		var landed := false
		for tick in 55:
			await frames(1)
			if absf(player.global_position.x-belts[i+1].global_position.x) < belts[i+1].size.x/2 and player.is_on_floor():
				landed = absf(player.global_position.y - (belts[i+1].global_position.y-14)) < 4
				break
		Input.action_release("move_left")
		check(landed,"leftward jump/dash transfer %d" % (i+1))
	# A charge condenses to the existing humanoid; recovery returns to cloud.
	var visual: Node2D = boss._visual
	visual.set_humanoid(false)
	visual._process(.2)
	check(visual.get_node("Body/Cloud").visible and visual._cloud_weight == 1,"resting form is cloud")
	var cloud := visual.get_node("Body/Cloud")
	check(cloud.SHEET.get_size() == Vector2(2172,724), "supplied three-frame sheet is loaded")
	var sequence: Array[int] = []
	for progress in [0.0, 0.1, 0.5, 0.9, 1.01]:
		cloud.age = cloud.blink_interval-cloud.blink_duration + progress*cloud.blink_duration
		if progress == 0.0: cloud.age = 0.0
		cloud._process(0.0)
		sequence.append(cloud.frame)
	check(sequence == [0,1,2,1,0], "blink plays open, half, closed, half, open")
	check(not cloud.blinking, "eyes stay open between blinks")
	visual.set_humanoid(true)
	var morph := visual.get_node("Body/ChargeMorph")
	var morph_frames: Array[int] = []
	visual._process(0.0)
	for i in 8:
		morph_frames.append(morph.frame)
		check(morph.visible and (not cloud.visible or i < 2), "transformation uses supplied sheet frame %d" % i)
		visual._process(visual.form_transition_time/8.0)
	check(morph_frames == [0,1,2,3,4,5,6,7], "all eight transformation frames play in sequence")
	visual._process(.01)
	check(not cloud.visible and visual._sprite.modulate.a == 1,"charge form is fully humanoid")
	var migrated: Dictionary = SaveGame._shift_conveyor_room_names({"room":"Level_19","way_back":{"Level_25":"Level_24"},"id":"Level_19_landing_3"})
	check(migrated.room == "Level_20" and migrated.way_back.get("Level_26") == "Level_25" and migrated.id == "Level_19_landing_3", "old save rooms migrate while checkpoint identities remain")
	print("CONVEYOR CHARGE ROOM: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
