extends Node
## The Act 2 Jamshid encounter (scripts/act2_beats.gd): swimming up to Jamshid on
## Act_2_Level_1's bank stages the whole cutscene — meeting, the sun setting, a
## fire, the night-long talk, dawn, and Jamshid riding off on a spring and a
## carpet. Drives it end to end and asserts the milestones that make it that
## scene and not a stray one-liner:
##   - the NPC's own greeting is deferred to the cutscene
##   - reaching him locks the player's controls
##   - both Jamshid and Hooshang speak
##   - the sky reaches full NIGHT and the stars come out
##   - it ends at DAWN with the stars gone
##   - Jamshid leaves (goes invisible) and control returns
##
## Loaded as a real Act2World (same as tests/intro_test.gd loads Act1World),
## started in Level_1 via LdtkWorld.debug_start_room. Engine.time_scale is
## raised so the minutes of tweened day/night collapse to a few real seconds;
## dialogue is advanced by pressing jump, not by waiting.
##
## Run:  godot --headless res://tests/act2_jamshid_encounter_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var beats: Act2Beats
var jamshid: JamshidNpc
var canvas_mod: CanvasModulate

# Milestones, latched as the scene plays.
var locked_ever := false
var jamshid_spoke := false
var hooshang_spoke := false
var max_blue := -1.0        # how blue (b - r) the sky ever got — night
var campfire_visible := false
var blackout_during_talk := false
var spawned_spring := false
var original_fish: Fish
var ellipsis_speakers: Array[Node] = []
var max_stars := 0.0        # peak StarField.amount — the night sky lit up


func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Act_2_Level_1"
	world = load("res://ldtk/Act2World.tscn").instantiate()
	add_child(world)
	await _run()


func _run() -> void:
	# Let the world build its rooms and Act2Beats claim the encounter.
	for i in 30:
		await _frames(1)
		if world.player != null and not world.rooms.is_empty():
			break
	_check(world.player != null, "the world came up with a player")
	beats = _find(world, "Act2Beats") as Act2Beats
	_check(beats != null, "Act2Beats is wired into the world")
	canvas_mod = world.get_node_or_null("CanvasModulate")

	var room := _room("Act_2_Level_1")
	_check(room != null, "Act_2_Level_1 is present")
	jamshid = _find_jamshid(room)
	_check(jamshid != null, "Level_1 has a JamshidNpc")
	# A couple of frames for Act2Beats._ready to finish claiming it.
	for i in 10:
		await _frames(1)
		if jamshid != null and jamshid.defer_to_cutscene:
			break
	_check(jamshid != null and jamshid.defer_to_cutscene,
		"the encounter claims Jamshid (his one-line greeting is deferred)")

	get_tree().node_added.connect(func(node: Node) -> void:
		if node is SpringPlatform:
			spawned_spring = true
		if node is EmoteBubble:
			ellipsis_speakers.append(node.get_parent()))
	original_fish = beats._pond_fish
	_check(is_instance_valid(original_fish), "the catch fish exists before the greeting")
	var fish_start := original_fish.global_position
	await _frames(20)
	_check(original_fish.global_position.distance_to(fish_start) > 0.1, "the fish is already swimming before the catch")
	_check(original_fish.get_node("Sprite2D").texture.get_size() == Vector2(12, 8), "fish draws one native 12x8 frame, not the full sheet")

	# Speed the tweened day/night up so this does not take a real minute.
	Engine.time_scale = 8.0

	# Walk him up to Jamshid — the trigger is proximity, so put him in reach.
	world.player.global_position = jamshid.global_position + Vector2(-30, -8)

	var name_label: Label = Dialogue.get_node("NameLabel")
	var settled := false
	for i in 6000:
		await _frames(1)
		_press_jump()
		if world.player.input_locked:
			locked_ever = true
		if Dialogue.visible and name_label.visible:
			if name_label.text == "Jamshid":
				jamshid_spoke = true
			elif name_label.text == "Hooshang":
				hooshang_spoke = true
		if canvas_mod != null and canvas_mod.color.b > canvas_mod.color.r:
			campfire_visible = true
		if campfire_visible and beats._fade.color.a > 0.01:
			blackout_during_talk = true
		if canvas_mod != null:
			max_blue = maxf(max_blue, canvas_mod.color.b - canvas_mod.color.r)
		if beats != null and beats._stars != null:
			max_stars = maxf(max_stars, beats._stars.amount)
		# Done when the cutscene has handed control back AFTER it started.
		if locked_ever and not world.player.input_locked and jamshid_spoke and i > 30:
			settled = true
			break
	Engine.time_scale = 1.0

	_check(locked_ever, "reaching Jamshid locks the player's controls")
	_check(jamshid_spoke, "Jamshid speaks")
	_check(hooshang_spoke, "Hooshang speaks")
	_check(max_blue > 0.1,
		"the sky reaches night (blue over red)  [peak b-r %.2f]" % max_blue)
	_check(max_stars > 0.5, "the stars come out at night  [peak amount %.2f]" % max_stars)
	_check(not blackout_during_talk, "campfire conversation stays visible through night and dawn")
	_check(not spawned_spring, "departure spawns no spring")
	_check(settled, "the cutscene finishes and returns control")
	if settled:
		_check(not world.player.input_locked, "...control is the player's again at the end")
		# Ended at dawn: warm/pale, red back over blue.
		_check(canvas_mod == null or canvas_mod.color.r >= canvas_mod.color.b,
			"...and the sky has come round to dawn  [r %.2f b %.2f]"
				% [canvas_mod.color.r, canvas_mod.color.b])
		_check(beats._pond_fish == original_fish, "the catch reuses the original swimming fish")
		_check(not original_fish.visible, "the fish is gone after dinner")
		_check(ellipsis_speakers == [world.player, jamshid.actor, world.player, jamshid.actor, world.player, jamshid.actor, world.player, jamshid.actor, world.player], "nine automatic bubbles alternate between the cousins")
		_check(beats._stars.shots_fired == 3, "three shooting stars cross the timelapse")
		_check(beats._stars.amount == 0.0, "stars are gone at dawn")
		for child in world.get_children():
			if child is Campfire:
				_check(not child.is_lit(), "the campfire is out at dawn")
		_check(not world.player._frozen, "the cutscene releases the physics freeze")
		_check(not jamshid.visible, "...and Jamshid has ridden off (gone from view)")

	if failures.is_empty():
		print("ACT2 JAMSHID ENCOUNTER TEST: ALL PASS")
	else:
		print("ACT2 JAMSHID ENCOUNTER TEST: %d FAILURE(S)" % failures.size())
		for f in failures:
			push_error(f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _room(rname: String) -> Node2D:
	for r in world.rooms:
		if str(r.name) == rname:
			return r
	return null


func _find(node: Node, nname: String) -> Node:
	if str(node.name) == nname:
		return node
	for c in node.get_children():
		var f := _find(c, nname)
		if f != null:
			return f
	return null


func _find_jamshid(node: Node) -> JamshidNpc:
	if node is JamshidNpc:
		return node
	for c in node.get_children():
		var f := _find_jamshid(c)
		if f != null:
			return f
	return null


func _press_jump() -> void:
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
