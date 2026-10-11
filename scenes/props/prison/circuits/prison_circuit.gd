extends Node2D
## Touch node or linked gate. The world ledger owns progress; this owns collision/art.
@export var kind := "CircuitNode"
@export var entity_iid := ""
@export var fields: Dictionary = {}
@export var prop_size := Vector2(16,16)
var mission: Node
var gate: Node2D
var circuit_id := ""
var _open := false
var _lit := false
const SHEET := preload("res://assets/props/prison_circuits/circuit.png")
const LEVER := preload("res://assets/props/prison_circuits/timed.png")
@onready var barrier: CollisionShape2D = $Barrier/Shape

func _ready() -> void:
	barrier.shape = barrier.shape.duplicate()
	(barrier.shape as RectangleShape2D).size = prop_size
	barrier.disabled = kind not in ["CircuitGate", "FloodGate", "MusicalGate"]
	z_index = -1 if kind == "FloodValve" and not bool(fields.get("Touch",false)) else 2

func bind(world: Node) -> void:
	mission = world
	if kind in ["CircuitGate", "FloodGate", "MusicalGate"]:
		circuit_id = str(fields.get("CircuitId", ""))
		var members: Array[String] = []
		var candidates=mission.props.duplicate()
		if kind=="MusicalGate":
			candidates=candidates.filter(func(p):return p.kind=="MusicalTile")
			candidates.sort_custom(func(a,b):return a.note_index<b.note_index)
		for prop in candidates:
			if prop.kind in ["CircuitNode", "FloodValve", "MusicalTile"] and mission.circuit_reference(prop.fields.get("Gate","")) == self:
				members.append(prop.entity_iid)
		if not mission.circuits.register_circuit(circuit_id,members,kind=="MusicalGate"):
			push_error("Invalid/duplicate prison circuit: " + circuit_id)
	else:
		gate = mission.circuit_reference(fields.get("Gate",""))
		if gate == null:
			push_error("Unresolved circuit gate for " + entity_iid)
	mission.circuits.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if mission == null: return
	if kind in ["CircuitGate", "FloodGate", "MusicalGate"]: _open = mission.circuits.solved(circuit_id)
	elif gate != null:
		# Read the gate field directly: bind order in the LDtk layer is arbitrary.
		_lit = mission.circuits.touched(str(gate.fields.get("CircuitId","")),entity_iid)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if mission == null or not is_instance_valid(mission.player): return
	if kind in ["CircuitGate", "FloodGate", "MusicalGate"]:
		# Completed circuits never close again. An unsolved gate must stay solid,
		# including when a fast movement brings the body against its edge.
		barrier.set_deferred("disabled", _open)
		return
	if gate == null or _lit or not get_parent().get_parent() == mission.current_room: return
	if mission._transitioning or mission.player.input_locked or mission.player.state == Player.State.DEAD: return
	if kind == "FloodValve":
		if bool(fields.get("RequireDry",false)) and (mission.player.swimming() or not mission.player.is_on_floor()): return
		if not bool(fields.get("Touch",false)) and not Input.is_action_just_pressed("move_up"): return
	if Rect2(global_position-Vector2(7,7),Vector2(14,14)).intersects(mission.player.hitbox_rect()):
		var id := str(gate.fields.get("CircuitId",""))
		if mission.circuits.touch(id,entity_iid):
			mission.get_node("Act2Audio").play_cue(&"Lock")
			if mission.circuits.solved(id): SaveGame.save_now()

func _draw() -> void:
	if kind in ["CircuitNode", "FloodValve"]:
		if kind == "FloodValve" and not bool(fields.get("Touch",false)):
			draw_texture_rect_region(LEVER,Rect2(-8,-8,16,16),Rect2(16 if _lit else 0,0,16,16))
		else:
			draw_texture_rect_region(SHEET,Rect2(-8,-8,16,16),Rect2(16 if _lit else 0,0,16,16))
	else:
		var rect := Rect2(-prop_size/2,prop_size)
		if not _open:
			for y in range(0,int(prop_size.y),8):
				for x in range(0,int(prop_size.x),8):
					draw_texture_rect_region(SHEET,Rect2(rect.position+Vector2(x,y),Vector2(8,8)),Rect2(32,0,8,8))
		else:
			draw_line(rect.position,rect.position+Vector2(rect.size.x,0),Color("bbd9a1"),2)
