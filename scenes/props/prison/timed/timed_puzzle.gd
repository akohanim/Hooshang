extends Node2D
## Lever, countdown shutter or permanent relay, linked through LDtk EntityRefs.
@export var kind := "TimedLever"
@export var entity_iid := ""
@export var fields: Dictionary = {}
@export var prop_size := Vector2(16,16)
const BARS := preload("res://assets/props/prison_circuits/circuit.png")
const ICONS := preload("res://assets/props/prison_circuits/timed.png")
var mission: Node
var gate: Node2D
var puzzle_id := ""
var _physically_open := false
var _plate_pressed := false
@onready var barrier: CollisionShape2D = $Barrier/Shape

func _ready() -> void:
	barrier.shape = barrier.shape.duplicate()
	(barrier.shape as RectangleShape2D).size = prop_size
	barrier.disabled = kind not in ["TimedGate","TimedShutter"]
	z_index = 2 if kind in ["TimedGate","TimedShutter"] else -1

func bind(world: Node) -> void:
	mission = world
	if kind=="TimedGate":
		puzzle_id = str(fields.get("PuzzleId",""))
		if not mission.timers.register_puzzle(puzzle_id,float(fields.get("Duration",8.0))):
			push_error("Invalid/duplicate timed puzzle: "+puzzle_id)
	else:
		gate = mission.timed_reference(fields.get("Gate",""))
		if gate==null: push_error("Unresolved timed gate: "+entity_iid)
		else: puzzle_id = str(gate.fields.get("PuzzleId",""))
	mission.timers.changed.connect(refresh)
	refresh()

func refresh() -> void:
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if mission==null or not is_instance_valid(mission.player): return
	if kind in ["TimedGate","TimedShutter"]:
		# A shutter already open may defer closure; an initially closed gate
		# never opens just because someone is pushing against its collider.
		var occupied := Rect2(global_position-prop_size/2,prop_size).grow(0.5).intersects(mission.player.hitbox_rect())
		var requested: bool = mission.timers.solved(puzzle_id) if bool(fields.get("RequireBank",false)) else mission.timers.active(puzzle_id)
		_physically_open = requested or (_physically_open and occupied)
		barrier.set_deferred("disabled",_physically_open)
		queue_redraw()
		return
	if gate==null or get_parent().get_parent()!=mission.current_room or mission._transitioning or mission.player.input_locked or mission.player.state==Player.State.DEAD:
		_plate_pressed = false
		return
	if kind=="PressurePlate":
		var foot: Vector2 = mission.player.global_position + Vector2(0,Player.HALF_HEIGHT-1)
		_plate_pressed = mission.player.is_on_floor() and Rect2(global_position-prop_size/2,prop_size).has_point(foot)
		if _plate_pressed and mission.timers.hold(puzzle_id): mission.get_node("Act2Audio").play_cue(&"Lock")
		queue_redraw()
		return
	if not Rect2(global_position-Vector2(9,8),Vector2(18,16)).intersects(mission.player.hitbox_rect()): return
	if kind=="TimedLever":
		if mission.player.is_on_floor() and Input.is_action_just_pressed("move_up"):
			if mission.timers.start(puzzle_id,bool(fields.get("CanBank",true))): mission.get_node("Act2Audio").play_cue(&"Lock")
	elif kind=="TimedRelay" and mission.timers.bank(puzzle_id):
		mission.get_node("Act2Audio").play_cue(&"Key")
		SaveGame.save_now()

func _draw() -> void:
	var active: bool = mission!=null and mission.timers.active(puzzle_id)
	var solved: bool = mission!=null and mission.timers.solved(puzzle_id)
	if kind in ["TimedGate","TimedShutter"]:
		var rect := Rect2(-prop_size/2,prop_size)
		if not _physically_open:
			for y in range(0,int(prop_size.y),8):
				for x in range(0,int(prop_size.x),8):
					draw_texture_rect_region(BARS,Rect2(rect.position+Vector2(x,y),Vector2(8,8)),Rect2(32,0,8,8))
		# Only a live countdown needs an indicator. Completed passages remain clear.
		if mission!=null and active and not solved and not bool(fields.get("RequireBank",false)):
			var height := minf(24.0,prop_size.y)
			var remaining := floorf(height*mission.timers.fraction(puzzle_id))
			draw_rect(Rect2(rect.position,Vector2(1,height)),Color("514b38"))
			draw_rect(Rect2(rect.position+Vector2(0,height-remaining),Vector2(1,remaining)),Color("e8c06d"))
	else:
		if kind=="PressurePlate":
			# Reuse the established metal base at native pixel scale.
			var top := 1.0 if _plate_pressed else -2.0
			draw_texture_rect_region(ICONS,Rect2(-prop_size.x/2,top,prop_size.x,5),Rect2(2,10,12,5))
			return
		if kind=="TimedLever" and not bool(fields.get("CanBank",true)):
			var direction := signf(gate.position.x-position.x) if gate!=null else 1.0
			draw_line(Vector2(-2*direction,-9),Vector2(2*direction,-9),Color("e8c06d"),1)
			draw_line(Vector2(2*direction,-9),Vector2(0,-11),Color("e8c06d"),1)
		var frame := (16 if active else 0) if kind=="TimedLever" else (48 if solved else 32)
		draw_texture_rect_region(ICONS,Rect2(-8,-8,16,16),Rect2(frame,0,16,16))
