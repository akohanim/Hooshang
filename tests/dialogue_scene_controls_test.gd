extends Node
## Real dialogue callers entered with an active dash. Player physics must stay
## stopped through speech AND staging, including an external input unlock.
var failures: Array[String] = []
var world: LdtkWorld
var player: Player
var beats: Act1Beats

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_5"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(15)
	player = world.player
	beats = world.get_node("Act1Beats")
	await check_music_dash_crossing()
	for room_name in [beats.music_room_name, beats.v1_room_name, beats.v2_room_name, beats.v3_room_name]:
		await check_room(room_name, true)
	# The reported music room also has to unlock after normal reading.
	await check_room(beats.music_room_name, false)
	await check_generic_rumi()
	await check_dash_gift()
	await check_darkshang()
	await check_jamshid()
	Dialogue.end_conversation()
	Screen.clear()
	await frames(3)
	print("DIALOGUE SCENE CONTROLS: ", "ALL PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)

func start_dash() -> void:
	player.unfreeze()
	player.input_locked = false
	player.state = Player.State.FALL
	player.has_dash = true
	player.dash_available = true
	player.dash_cooldown_timer = 0.0
	Input.action_press("move_right")
	check(player._try_dash(), "test enters with a real active dash")
	player._update_visual()

func check_music_dash_crossing() -> void:
	var room := beats._find_room(beats.music_room_name)
	world._enter_room(room, true)
	var trigger := beats._find_trigger(room)
	var shape: CollisionShape2D
	for child in trigger.get_children():
		if child is CollisionShape2D:
			shape = child
	check(shape != null, "music trigger has a real collision shape")
	if shape == null:
		return
	player.freeze()
	player.global_position.x = shape.global_position.x - (shape.shape as RectangleShape2D).size.x * 0.5 - 14.0
	await frames(3) # physics overlap cache must see him outside first
	trigger._fired = false
	start_dash()
	for i in 30:
		await frames(1)
		if trigger._fired:
			break
	check(trigger._fired and player.state == Player.State.DASH, "actual dash crossing fires the music scene before dash ends")
	await check_hold_and_finish("music room physical dash crossing")

func check_room(room_name: String, skip: bool) -> void:
	var room := beats._find_room(room_name)
	check(room != null, "room exists: " + room_name)
	if room == null:
		return
	world._enter_room(room, true)
	var trigger := beats._find_trigger(room)
	check(trigger != null, "authored trigger exists: " + room_name)
	if trigger == null:
		return
	start_dash()
	trigger._fired = false
	trigger._on_body_entered(player)
	await check_hold_and_finish(room_name, skip)
	check(trigger.get_node("Rumi").modulate.a == 0.0, "Rumi departs after " + room_name)
	check(trigger.get_node("RumiLight").energy == 0.0, "Rumi light clears after " + room_name)

func check_hold_and_finish(label: String, skip: bool = true) -> void:
	var at := player.global_position
	check(player._frozen and not player.is_physics_processing(), "immediate hard freeze: " + label)
	check(player.velocity == Vector2.ZERO, "arrival momentum cleared: " + label)
	check(player.visual.animation == &"idle", "arrival animation switches to idle: " + label)
	# Reproduce a room transition completing while dialogue is open.
	player.input_locked = false
	Input.action_press("jump")
	Input.action_press("dash")
	for i in 360:
		await frames(1)
		if Dialogue._active:
			break
	check(Dialogue._active and Dialogue._conversation_skippable, "speech supports skip: " + label)
	await frames(12)
	check(player.global_position.distance_to(at) < 0.01, "held walk/jump/dash cannot move player: " + label)
	check(player.input_locked and player._frozen, "external unlock cannot release dialogue: " + label)
	check(player.visual.animation == &"idle", "held movement cannot animate running during dialogue: " + label)
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("move_right")
	if skip:
		Input.action_press("skip_dialogue")
		Dialogue._process(Dialogue.skip_hold_time + 0.1)
		Input.action_release("skip_dialogue")
	for i in (40 if skip else 1500):
		if not skip and Dialogue._active:
			Dialogue._finish_reveal_instantly()
			Dialogue.line_finished.emit()
		await frames(1)
		if not player._frozen:
			break
		check(player.global_position.distance_to(at) < 0.01, "stays fixed through scene staging: " + label)
	check(not player._frozen and not player.input_locked and player.is_physics_processing(), "controls return: " + label)
	check(not Dialogue._skip_armed(), "skip cleared at scene end: " + label)
	# Stop old dash resuming during setup for the next case.
	player.state = Player.State.FALL
	player.velocity = Vector2.ZERO

func check_generic_rumi() -> void:
	world._enter_room(beats._find_room("Level_5"), true)
	var trigger := LdtkRumiTrigger.make()
	trigger.dialogue_line = "A single greeting."
	trigger.global_position = player.global_position + Vector2(30, 0)
	world.add_child(trigger)
	start_dash()
	trigger._on_body_entered(player)
	await check_hold_and_finish("generic one-line Rumi")
	trigger.queue_free()

func check_dash_gift() -> void:
	world._enter_room(beats._find_room(DashTutorial.ROOM), true)
	var tutorial: DashTutorial = world.get_node("DashTutorial")
	player.has_dash = false
	player.input_locked = true
	tutorial.gift_lines = ["Take this gift."]
	tutorial._locked = true
	tutorial._held = true
	tutorial._hang = player.global_position
	# Starts the real speech/gift/prompt sequence from the catch point.
	tutorial._begin()
	await check_hold_and_finish("dash gift and tutorial")
	check(player.has_dash, "skipping gift still grants dash")
	check(is_instance_valid(tutorial._prompt), "skipping speech leaves the gameplay lesson prompt")
	tutorial._teardown()

func check_darkshang() -> void:
	var room := beats._find_room(beats.chase_room_name)
	world._enter_room(room, true)
	var trigger := beats._find_chase_trigger(room)
	check(trigger != null, "real Darkshang trigger exists")
	if trigger == null:
		return
	var started: Array[bool] = []
	trigger.chase_begun.connect(func(): started.append(true), CONNECT_ONE_SHOT)
	start_dash()
	trigger.spent = false
	trigger._on_body_entered(player)
	await check_hold_and_finish("Darkshang reveal")
	check(started.size() == 1, "skipped reveal starts the chase exactly once")

func check_jamshid() -> void:
	LdtkWorld.debug_start_room = "Act_2_Level_0"
	world = Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(15)
	player = world.player
	var npc: JamshidNpc = load("res://scenes/characters/jamshid/JamshidNpc.tscn").instantiate()
	npc.dialogue_line = "A short greeting."
	npc._greeted = true
	world.add_child(npc)
	start_dash()
	npc._greet(player)
	await check_hold_and_finish("one-line Jamshid greeting")
	npc.queue_free()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)
