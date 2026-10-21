extends Node
## Act III's story, end to end, with the beats ON (scripts/act3/act3_beats.gd):
## every scene in SCRIPT.md's ACT THREE is reached the way a player reaches it —
## a room entered, a trigger walked into, a memory touched — and has to finish
## and bank its flag (SeaWorld.story["scene:<name>"]). Conversations are held
## through with `skip_dialogue`, the same hold a player uses, so this exercises
## every line's code path without waiting on the typewriter.
##
## Checked along the way: the opening plays on a fresh arrival, Rumi's gift
## grants the Dive, the dark floor is dark, the stillness finale passes only
## while he is still, the real sea no longer ends the act, the tiger chases him
## from behind, the vine scene has its second tiger and its two mice, and the
## act ends on the vine at the results.
##
## Headless:  Godot --headless --path . --fixed-fps 60 res://tests/act3_story_test.tscn

var world: SeaWorld
var player: Player
var failures := 0
var _skip_frames := 0


func _ready() -> void:
	get_tree().create_timer(900.0, true, false, true).timeout.connect(func():
		print("ACT3_STORY: TIMEOUT"); get_tree().quit(3))
	SaveGame.unbind()
	Sfx.muted = true
	LdtkWorld.debug_start_room = ""
	world = load("res://ldtk/Act3World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(10)
	player = world.player
	check(not player.has_swim_dash, "a fresh arrival starts without the Dive")

	await until_flag("tide", 1500)
	await walk_into_rumi("Act3_Level_0")
	await until_flag("meeting", 1500)

	await enter("Act3_Level_4")
	await walk_into_rumi("Act3_Level_4")
	await until_flag("gift", 1500)
	check(player.has_swim_dash, "Rumi's gift grants the Dive")

	await enter("Act3_Level_6")
	# Into the river along the bottom: the current that carries him out.
	player.respawn(room("Act3_Level_6").global_position + Vector2(200, 140))
	await until_flag("currents", 600)

	await enter("Act3_Level_9")
	await walk_into_rumi("Act3_Level_9")
	await until_flag("lobby", 900)

	await enter("Act3_Level_12")
	await frames(5)
	var dark := room("Act3_Level_12").get_node_or_null("Darkness") as CanvasItem
	check(dark != null and dark.visible, "the dark floor is dark")
	await until_flag("dark", 900)

	await enter("Act3_Level_13")
	await touch_memory("Act3_Level_13", "can")
	await until_flag("kept", 1200)

	await enter("Act3_Level_14")
	await walk_into_rumi("Act3_Level_14")
	await until_flag("reef", 900)

	await enter("Act3_Level_18")
	await walk_into_rumi("Act3_Level_18")
	await until_flag("edge", 900)

	await enter("Act3_Level_21")
	await stillness()
	await until_flag("floor", 2400)

	await enter("Act3_Level_22")
	player.respawn(mark("Act3_Level_22", "Jamshid") + Vector2(20, 0))
	await until_flag("pond", 2400)

	await enter("Act3_Level_23")
	player.respawn(room("Act3_Level_23").global_position + Vector2(160, 30))
	await until_flag("ascent", 600)
	await until_flag("office", 1800)
	check(str(world.current_room.name) == "Act3_Level_24", "the ascent wakes him in the office")
	# Out through the door.
	player.respawn(mark("Act3_Level_24", "Door") + Vector2(4, 0))
	await until_room("Act3_Level_25", 1200)
	player.respawn(mark("Act3_Level_25", "Water") + Vector2(2, -6))
	await until_flag("sea", 2400)
	check(_results_screen() == null, "the real sea no longer ends the act: he walks on")

	# THE WAY HOME: the tiger steps out of the tall grass behind him...
	await enter("Act3_Level_28")
	player.respawn(room("Act3_Level_28").global_position + Vector2(13 * 8 + 6, 15 * 8 - Player.HALF_HEIGHT))
	await until_flag("tiger", 1800)
	var tiger := world.get_node_or_null("Tiger") as ChaseTiger
	check(tiger != null and tiger.chasing, "the tiger chases him once it has roared")
	check(tiger != null and tiger.global_position.x < player.global_position.x, "...from behind him")
	# ...and he runs to the edge, falls, and hangs from the vine.
	await enter("Act3_Level_31")
	player.respawn(mark("Act3_Level_31", "Edge") + Vector2(2, -2))
	await until_flag("vine", 4800)
	check(room("Act3_Level_31").get_node_or_null("TigerBelow") != null, "a second tiger waits below")
	check(room("Act3_Level_31").get_node_or_null("MouseBlack") != null
		and room("Act3_Level_31").get_node_or_null("MouseWhite") != null, "a black mouse and a white one gnaw the vine")
	check(player.visual.animation in [&"hang_content", &"hang_eat"], "he ends on the vine, the lemon eaten")
	var results := false
	for i in 600:
		results = _results_screen() != null
		if results:
			break
		await frames(1)
	check(results, "the end of the act reaches the results screen")
	print("ACT3_STORY: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


# -------------------------------------------------------------- helpers ----

func _results_screen() -> Node:
	for child in get_tree().root.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("act_results.gd"):
			return child
	return null


func room(name: String) -> Node2D:
	for r in world.rooms:
		if str(r.name) == name:
			return r
	return null


func mark(room_name: String, mark_name: String) -> Vector2:
	var node := room(room_name).get_node_or_null("Entities/" + mark_name) as Node2D
	return node.global_position if node != null else world.room_rect(room(room_name)).get_center()


func enter(name: String) -> void:
	await settle()
	world._enter_room(room(name), true)
	await frames(3)


func walk_into_rumi(room_name: String) -> void:
	await settle()
	for node in room(room_name).find_children("*", "Area2D", true, false):
		if node is LdtkRumiTrigger:
			player.respawn((node as Node2D).global_position + Vector2(-2, 0))
			return
	check(false, "%s has a Rumi trigger" % room_name)


func touch_memory(room_name: String, kind: String) -> void:
	await settle()
	for m in get_tree().get_nodes_in_group("sea_memory"):
		var memory := m as SeaMemory
		if room(room_name).is_ancestor_of(memory) and memory.kind == kind:
			player.respawn(memory.global_position)
			return
	check(false, "%s has its %s" % [room_name, kind])


## The finale: hold still and let every thought pass.
func stillness() -> void:
	await settle()


## Wait for a scene's flag, holding `skip_dialogue` through any conversation
## (press ~1.2s, release a moment, again — DialogueBox wants a fresh press per
## conversation that opened while it was already held).
func until_flag(scene: String, max_frames: int) -> void:
	for i in max_frames:
		if bool(world.story.get("scene:" + scene, false)):
			release_skip()
			print("  ok   scene %s after %d frames" % [scene, i])
			return
		pump_skip()
		await frames(1)
	release_skip()
	check(false, "scene '%s' never finished (room %s)" % [scene, world.current_room.name])


func until_room(name: String, max_frames: int) -> void:
	for i in max_frames:
		if str(world.current_room.name) == name and not world._transitioning:
			release_skip()
			return
		pump_skip()
		await frames(1)
	release_skip()
	check(false, "never reached %s" % name)


func pump_skip() -> void:
	_skip_frames += 1
	if _skip_frames % 80 < 74:
		Input.action_press("skip_dialogue")
	else:
		Input.action_release("skip_dialogue")


func release_skip() -> void:
	Input.action_release("skip_dialogue")
	_skip_frames = 0


func settle() -> void:
	for i in 600:
		if not world._transitioning and player.state != Player.State.DEAD:
			return
		await frames(1)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL ", message)
