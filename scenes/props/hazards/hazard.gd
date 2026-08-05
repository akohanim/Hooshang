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
var _visual: CanvasItem


func _ready() -> void:
	collision_layer = 4  # layer 3 "hazards"
	collision_mask = 2  # only looks for the player layer
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_build_visual()
	_update_extents()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


## What the hazard looks like. The greybox default is the red rectangle; a
## hazard with real art overrides this and _update_extents() together and
## inherits everything that makes it lethal — layer, mask, and the one line
## below that kills the player. See hazards/glass_spikes.gd.
func _build_visual() -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.9, 0.25, 0.3)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual = rect
	add_child(rect)


func _update_extents() -> void:
	if _shape == null:
		return
	_shape.shape.size = (size - Vector2(KILL_MARGIN, KILL_MARGIN)).max(Vector2(1.0, 1.0))
	var rect := _visual as ColorRect
	if rect != null:
		rect.position = -size / 2.0
		rect.size = size


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()
