extends NoteTile
## Existing note art/contact/audio, scoped to a persistent prison key gate.
@export var kind := "MusicalTile"
@export var entity_iid := ""
@export var fields: Dictionary = {}
var mission: Node
var gate: Node2D
var _feedback: AudioStreamPlayer2D

func _ready() -> void:
	super._ready()
	# Act1's manager owns glow and ordinary exits; this room owns its key gate.
	remove_from_group("note_tile")
	_feedback=AudioStreamPlayer2D.new()
	add_child(_feedback)
	stepped.connect(_on_note)

func bind(world: Node) -> void:
	mission=world
	gate=mission.circuit_reference(fields.get("Gate",""))
	if gate==null:push_error("Unresolved musical gate for "+entity_iid)

func refresh() -> void:
	pass

func _on_note(_tile: NoteTile) -> void:
	if mission==null or gate==null or get_parent().get_parent()!=mission.current_room:return
	if mission._transitioning or mission.player.input_locked or mission.player.state==Player.State.DEAD:return
	var id:=str(gate.fields.get("CircuitId",""))
	if mission.circuits.solved(id):return
	var advanced: bool=mission.circuits.touch(id,entity_iid)
	if not advanced:
		_feedback.stream=preload("res://assets/notes/wrong.wav")
		_feedback.play()
	elif mission.circuits.solved(id):
		_feedback.stream=preload("res://assets/notes/success.wav")
		_feedback.play()
		SaveGame.save_now()
