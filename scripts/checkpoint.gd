@tool
class_name Checkpoint
extends Area2D
## Touch to set the respawn point. Greybox visual: a green post that lights up
## when it's the active checkpoint.

signal activated(checkpoint: Checkpoint)

var is_active := false:
	set(value):
		is_active = value
		_update_color()

var _visual: ColorRect


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # only the player triggers it
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12.0, 20.0)
	shape.shape = rect
	add_child(shape)
	_visual = ColorRect.new()
	_visual.position = Vector2(-2.0, -10.0)
	_visual.size = Vector2(4.0, 20.0)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	_update_color()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _update_color() -> void:
	if _visual == null:
		return
	_visual.color = Color(0.3, 1.0, 0.45) if is_active else Color(0.15, 0.45, 0.25)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_active:
		activated.emit(self)
