extends Node
## A doorway cut, not a long pan through unrelated rooms on the LDtk world grid.
## Duration of each half of the doorway fade, in seconds.
@export var fade_seconds := 0.22
var world: LdtkWorld
var gatehouse: Node2D
var hub: Node2D
@onready var curtain: ColorRect = $Curtain/Fade

func _ready() -> void:
	world = get_parent() as LdtkWorld
	call_deferred("_bind_rooms")

func _bind_rooms() -> void:
	for room in world.rooms:
		if room.name == "Act_2_Level_15": gatehouse = room
		if room.name == "Prison_Hub": hub = room
	if gatehouse != null and hub != null:
		world.exit_overrides[gatehouse] = _leave_gatehouse

func _leave_gatehouse(target: Node2D) -> bool:
	if target != hub: return false
	world.transition_with_sequence(hub, _fade.bind(1.0), _arrive.bind(Vector2.INF))
	return true

func return_to_courtyard(destination: String) -> void:
	if gatehouse == null or str(gatehouse.name) != destination or world.current_room != hub: return
	if world.story_flags.get("cell_reunion",false):
		for room in world.rooms:
			if room.name == "Act_2_Level_16":
				await world.transition_with_sequence(room, _fade.bind(1.0), _arrive.bind(Vector2.INF))
				return
	var at := world._re_entry_point(gatehouse)
	await world.transition_with_sequence(gatehouse, _fade.bind(1.0), _arrive.bind(at))
	# This is a backward arrival at the forward door. Its left edge must
	# continue toward the gardens, rather than returning to the prison again.
	world._arm_return(world._room_before(gatehouse))

func _arrive(at: Vector2) -> void:
	if at != Vector2.INF:
		world.player.respawn(at)
		world.player.freeze()
		world.set_story_checkpoint(world.current_room, at)
		world.player.camera.reset_smoothing()
	await _fade(0.0)

func _fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(curtain,"color:a",alpha,fade_seconds)
	await tween.finished
