@tool
class_name Hazard
extends Area2D
## Kills the player on touch (spikes, etc.). Greybox visual: a red rectangle.
## Resize per-instance with the exported `size` — the collision box and the
## visual follow automatically.

## Full visual size in pixels. The kill box is slightly smaller (see KILL_MARGIN).
@export var size := Vector2(8.0, 8.0):
	set(value):
		size = value
		_update_extents()

## The kill box is inset by this many pixels so deaths never feel unfair
## (classic platformer leniency: the visual is bigger than the hitbox).
const KILL_MARGIN := 2.0

var _shape: CollisionShape2D
var _visual: ColorRect


func _ready() -> void:
	collision_layer = 4  # layer 3 "hazards"
	collision_mask = 2  # only looks for the player layer
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_visual = ColorRect.new()
	_visual.color = Color(0.9, 0.25, 0.3)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	_update_extents()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _update_extents() -> void:
	if _shape == null:
		return
	_shape.shape.size = (size - Vector2(KILL_MARGIN, KILL_MARGIN)).max(Vector2(1.0, 1.0))
	_visual.position = -size / 2.0
	_visual.size = size


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()
