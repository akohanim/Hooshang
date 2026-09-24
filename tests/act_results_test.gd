extends Node
const CONFIG = preload("res://resources/scoring/act_score.gd")
const RESULTS = preload("res://scenes/ui/ActResults.tscn")
const WORLD := "res://ldtk/Act1World.tscn"
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveGame.slot = -1
	ActStats.reset()
	Collectibles.reset()
	Deaths.reset()
	var sample := {"world": WORLD, "seconds": 423.0, "lemons": 8, "available": 8, "deaths": 12}
	var score: Dictionary = CONFIG.calculate(sample)
	check(score.final == 14470, "sample score includes time, fruit, all-fruit and penalty")
	sample.seconds = 700.0
	sample.deaths = 10000
	check(CONFIG.calculate(sample).final == 0, "over-par and negative final clamp")
	sample.deaths = 0
	sample.lemons = 0
	sample.available = 0
	check(CONFIG.calculate(sample).final == 1000, "empty act has only deathless bonus")

	LdtkWorld.debug_start_room = "Level_5"
	var world := Screen.load_scene(WORLD)
	world.player.input_locked = true
	var count := 0
	var fruit: Node
	for node in get_tree().get_nodes_in_group("lemon"):
		if world.is_ancestor_of(node):
			count += 1
			fruit = node
	check(count > 0 and ActStats.available == count, "total includes all authored act lemons")
	var id: String = fruit.collect_id()
	Collectibles.collect(id)
	Collectibles.spend(1)
	Collectibles.collect(id)
	check(ActStats.snapshot().lemons == 1, "spend and duplicate pickup do not alter collected count")
	Deaths.record()
	check(ActStats.deaths == 1, "existing death signal increments act deaths")
	ActStats.seconds = 120.0
	get_tree().paused = true
	for i in 5:
		await get_tree().process_frame
	check(ActStats.seconds == 120.0, "pause excludes elapsed time")
	get_tree().paused = false
	ActStats._process(1.0)
	check(ActStats.seconds == 121.0, "active timer increments")
	var payload: Dictionary = SaveGame._gather()
	ActStats.reset()
	SaveGame._apply(payload)
	check(ActStats.seconds == 121.0 and ActStats.deaths == 1, "save payload restores stats")
	LdtkWorld.debug_start_room = "Level_5"
	world = Screen.load_scene(WORLD)
	world.player.input_locked = true
	check(ActStats.available == count and ActStats.snapshot().lemons == 1, "reload retains total and collected IDs")
	check(ActStats.seconds == 121.0, "same-act reload preserves timer")
	var snapshot: Dictionary = ActStats.finish()
	ActStats._process(10.0)
	check(ActStats.seconds == 121.0, "completion freezes timer")
	var results := RESULTS.instantiate()
	results.stats = snapshot
	add_child(results)
	results.set_process(false)
	check(get_tree().paused, "results freeze world")
	check(results._rows[0].visible and not results._rows[1].visible, "tally starts with time only")
	results._process(results.tally_time * 0.5)
	check(int(results._rows[0].get_node("Value").text) > 0, "time points animate")
	results._process(results.tally_time)
	check(results._rows[1].visible, "next row appears in sequence")
	var press := InputEventAction.new()
	press.action = "jump"
	press.pressed = true
	results._input(press)
	check(results.complete and get_tree().paused, "first press finishes without continuing")
	check(results._rows[5].visible and results._rows[5].get_node("Value").text == str(CONFIG.calculate(snapshot).final), "skip fills exact final score")
	results._input(press)
	check(results._leaving and not get_tree().paused, "second press continues and unpauses")
	results.queue_free()
	await get_tree().process_frame

	# Natural playback reaches the same values, including negative penalties.
	results = RESULTS.instantiate()
	results.stats = snapshot
	add_child(results)
	results.set_process(false)
	for i in 6:
		results._process(results.tally_time + 0.01)
		if i == 2:
			check(results._rows[2].get_node("Value").text == "-25", "penalty tallies down")
		results._process(results.line_pause)
	check(results.complete, "natural tally completes")
	results.queue_free()
	await get_tree().process_frame
	check(not get_tree().paused, "removing results restores prior pause state")

	# Exercise the real shared handoff: no scene change until confirmation.
	var beats: Node = world.find_child("Act1Beats", true, false)
	check(beats != null, "actual finale controller exists")
	if beats != null:
		beats.act_two_scene = "res://ldtk/Act2World.tscn"
		beats._handoff_act_two()
		var overlay: Node = get_tree().root.get_node("ActResults")
		check(Screen.current == world, "handoff waits on results")
		beats._handoff_act_two()
		overlay._input(press)
		check(Screen.current == world, "skip does not load next act")
		overlay._input(press)
		await get_tree().process_frame
		check(Screen.current_path() == "res://ldtk/Act2World.tscn", "continue uses existing next-act path")
		check(ActStats.deaths == 0 and not ActStats.finished and ActStats.seconds < 1.0, "new act resets stats")
	print("ACT RESULTS TEST: ", "ALL PASS" if failures == 0 else str(failures) + " FAILURES")
	get_tree().quit(0 if failures == 0 else 1)
