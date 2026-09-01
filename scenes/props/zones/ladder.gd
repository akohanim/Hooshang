@tool
class_name Ladder
extends Area2D
## A climbable rail: reach for it (press up or down while touching it) and it
## grips him — no gravity, steering locked to the rail, vertical speed answers
## move_up/move_down directly. Player.enter_ladder()/exit_ladder() do the
## actual moving, the same split SlideZone uses — this node only decides WHO
## should be climbing and WHEN, and never writes velocity itself (see
## slide_zone.gd's own note on why that split matters for frame order).
##
## Drop one in LDtk as a `Ladder` entity and stretch it to the height you want
## climbable; width is fixed at one cell (CELL) both here and in the LDtk
## definition, since nothing about a ladder should read as wider than the
## rail itself.

## Full height in pixels. LDtk sets this from the box you drag.
@export var height := 16.0:
	set(value):
		height = maxf(value, CELL)
		_update_extents()

const CELL := 8.0
const RUNG := preload("res://assets/props/ladder_rung.png")

var _shape: CollisionShape2D
var _rungs: Node2D
## The player currently gripping this ladder, so it knows whose grip to end.
var _held: Player


func _ready() -> void:
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # player only
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_rungs = Node2D.new()
	_rungs.name = "Rungs"
	add_child(_rungs)
	_update_extents()


## Nothing here builds anything until _ready has — the same guard SlideZone
## uses, for the same reason: `height` is set by the LDtk importer before this
## node's own children exist.
func _update_extents() -> void:
	if _shape == null:
		return
	_shape.shape.size = Vector2(CELL, height)
	_rebuild_rungs()


func _rebuild_rungs() -> void:
	for old in _rungs.get_children():
		old.free()  # free, not queue_free — reruns on every drag in the editor
	var cells := maxi(int(round(height / CELL)), 1)
	for i in cells:
		var tile := Sprite2D.new()
		tile.texture = RUNG
		tile.centered = false
		tile.position = Vector2(-CELL * 0.5, i * CELL - height * 0.5)
		_rungs.add_child(tile)


## Who is gripping, asked fresh every frame rather than tracked from
## body_entered/body_exited — the same reasoning SlideZone documents: a
## respawn, a room load, or the debug picker can all put the player inside
## without ever crossing the boundary.
##
## Unlike SlideZone this does not grab on overlap alone — touching a ladder in
## passing should not suck him onto it. Grabbing also needs move_up/move_down
## pressed, UNLESS he is already climbing, so a frame that briefly reads
## neutral input mid-climb does not drop him.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var inside: Player = null
	for body in get_overlapping_bodies():
		if body is Player:
			inside = body
			break
	if inside != null:
		if inside.climbing():
			_held = inside
		else:
			var reaching := not inside.input_locked \
				and Input.get_axis("move_up", "move_down") != 0.0
			if reaching:
				inside.enter_ladder(self, global_position.x)
				_held = inside
	elif _held != null:
		if is_instance_valid(_held):
			_held.exit_ladder(self)
		_held = null
