extends Node
## Transition integration with deliberate test positioning; not a movement proof.
var failures: Array[String] = []
var world: LdtkWorld
var deaths := 0

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act_2_Level_15"
	world = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await frames(20)
	world.player.died.connect(func(): deaths += 1)
	var gatehouse := world.current_room
	var approach := world._room_before(gatehouse)
	# Door integration starts after the approach story. Its playback/skip/save
	# contract is covered by school_story_test, not this transition fixture.
	world.story_flags.merge({"wall":true,"palace":true},true)
	for story in approach.get_node("Entities").get_children():
		if story.has_method("_restore"): story._restore()
	check(str(approach.name) == "Act_2_Level_14", "gatehouse follows the approach")
	# Walk through the actual Area2D from just outside it.
	world.player.global_position = gatehouse.global_position + Vector2(432,194)
	Input.action_press("move_right")
	await frames(60)
	Input.action_release("move_right")
	await frames(50)
	check(str(world.current_room.name) == "Prison_Hub", "gatehouse doorway reaches the hub")
	check(not world.player.input_locked, "door fade releases controls")
	# Use the hub door's real Up interaction, then keep travelling backward.
	world.player.global_position = world.current_room.global_position + Vector2(64,346)
	await frames(5)
	Input.action_press("move_up")
	await frames(2)
	Input.action_release("move_up")
	await frames(60)
	check(world.current_room == gatehouse, "courtyard interaction returns to gatehouse")
	check(world._return_room == approach, "backward arrival restores the garden return route")
	var checkpoint := world._checkpoint
	world.player.die()
	await frames(100)
	check(world.current_room == gatehouse, "death after courtyard return stays in gatehouse")
	check(world.player.is_on_floor() and absf(world.player.global_position.x-checkpoint.x) < 2
		and world._checkpoint == checkpoint and deaths == 1,
		"return checkpoint settles on safe ground without a death loop")
	world.player.global_position = gatehouse.global_position + Vector2(24,194)
	await frames(5)
	Input.action_press("move_left")
	await frames(35)
	Input.action_release("move_left")
	await frames(50)
	check(world.current_room == approach, "left edge continues to approach")
	check(not world.player.input_locked, "backtracking restores control")
	print("CASTLE CONNECTIONS: ", "ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)
