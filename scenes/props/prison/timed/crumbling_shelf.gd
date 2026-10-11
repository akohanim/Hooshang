@tool
extends CrumblingPlatform
## Existing crumble stones and warning animation; linked lever restores them.
@export var kind := "CrumblingShelf"
@export var fields: Dictionary = {}
var mission: Node
var puzzle_id := ""

func bind(world: Node) -> void:
	mission = world
	var gate: Node2D = mission.timed_reference(fields.get("Gate", ""))
	if gate == null:
		push_error("Unresolved crumbling shelf gate")
		return
	puzzle_id = str(gate.fields.get("PuzzleId", ""))
	mission.timers.lever_used.connect(_on_attempt_started)
	mission.room_changed.connect(_on_room_changed)

func _on_attempt_started(id: String) -> void:
	if id == puzzle_id: reset()

func _on_room_changed(room: Node2D) -> void:
	if room == get_parent().get_parent(): reset()

func refresh() -> void:
	pass
