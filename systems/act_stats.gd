extends Node
## Per-act results, independent of spendable inventory and the global HUD score.
const CONFIG = preload("res://resources/scoring/act_score.gd")
var world := ""
var seconds := 0.0
var deaths := 0
var available := 0
var finished := false
var _running := false
var _death_total := 0
var _collected: Dictionary = {}

func _ready() -> void:
	Screen.scene_loaded.connect(_scene_loaded)
	Collectibles.collected.connect(_lemons_changed)
	Deaths.changed.connect(_deaths_changed)

func _process(delta: float) -> void:
	if _running and not finished:
		# Undo cosmetic hitstop scaling; SceneTree pause still stops processing.
		seconds += delta / maxf(Engine.time_scale, 0.0001)

func reset() -> void:
	world = ""
	seconds = 0.0
	deaths = 0
	available = 0
	finished = false
	_running = false
	_collected.clear()
	_death_total = Deaths.total

func _scene_loaded(scene: Node) -> void:
	_running = false
	if scene == null or not CONFIG.ACTS.has(Screen.current_path()):
		return
	var path := Screen.current_path()
	if world != path:
		reset()
		world = path
	_death_total = Deaths.total
	_lemons_changed(0)
	# scene_loaded is synchronous, before already-taken lemons queue_free.
	# Union with saved IDs also handles a reload after those nodes were removed.
	var ids := _collected.duplicate()
	for lemon in get_tree().get_nodes_in_group("lemon"):
		if scene.is_ancestor_of(lemon):
			ids[lemon.collect_id()] = true
	available = ids.size()
	_running = true

func _lemons_changed(_total: int) -> void:
	if world.is_empty() or finished:
		return
	for id in Collectibles.save_state().get("taken", []):
		if str(id).begins_with(world + "@"):
			_collected[str(id)] = true

func _deaths_changed(total: int) -> void:
	if _running and not finished:
		deaths += maxi(0, total - _death_total)
	_death_total = total

func snapshot() -> Dictionary:
	return {"world": world, "seconds": seconds, "deaths": deaths,
		"lemons": _collected.size(), "available": available}

func finish() -> Dictionary:
	finished = true
	_running = false
	return snapshot()

func save_state() -> Dictionary:
	var data := snapshot()
	data["collected"] = _collected.keys()
	data["finished"] = finished
	return data

func load_state(data: Dictionary) -> void:
	reset()
	world = str(data.get("world", ""))
	seconds = maxf(0.0, float(data.get("seconds", 0.0)))
	deaths = maxi(0, int(data.get("deaths", 0)))
	available = maxi(0, int(data.get("available", 0)))
	finished = bool(data.get("finished", false))
	var ids: Variant = data.get("collected", [])
	if ids is Array:
		for id in ids:
			_collected[str(id)] = true
