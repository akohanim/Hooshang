@tool
class_name SafeZoneTrigger
extends Area2D
## The end of the chase. Reaching it stops Darkshang dead and hands the moment
## over to whoever is telling the story.
##
## It does not kill him, hide him or free him — it calls stop_chase(), which puts
## him back to DORMANT with everything reset. He is still standing there, which
## is what a narrative beat needs: something to talk to. Restarting the chase is
## then one call rather than a fresh spawn.
##
## FIRES ONCE, like the surge points, and unlike them it is never re-armed: the
## chase being over is not a state the player is meant to be able to leave and
## re-enter. If a later act wants a second chase, that is a second SafeZone.
##
## Place one in LDtk as a `SafeZone` and stretch it over the doorway, alcove or
## ledge the chase ends at.

## Fired when the player reaches safety. `end_dialogue_id` is passed straight
## through from the LDtk field — this node knows nothing about dialogue, it just
## carries the name of the beat that should play, which keeps the narrative side
## free to re-cut its script without touching the chase.
signal reached(end_dialogue_id: String)

## Full size of the safe area in px. LDtk sets this from the box you drag.
@export var size := Vector2(32.0, 48.0):
	set(value):
		size = value
		_update_extents()

## Which dialogue beat plays when the chase ends. Empty = no beat; the signal
## still fires, so a room can react without a line being spoken.
@export var end_dialogue_id := ""

## Editor-only overlay colour, a staging aid — green, because it is the one
## volume in this system that is good news.
const EDITOR_TINT := Color(0.3, 0.9, 0.5, 0.22)

## Whether the chase has already been ended here.
var spent := false

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # the player and nothing else
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_update_extents()
	add_to_group("safe_zone", true)
	if Engine.is_editor_hint():
		return
	# In _ready, not in the import hook — see the same note in
	# surge_point_trigger.gd and STYLE_GUIDE §9.
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if spent or body is not Player:
		return
	spent = true
	var shadow := get_tree().get_first_node_in_group("darkshang") as Darkshang
	if shadow != null:
		# Halt the chase BEFORE announcing it. An ingestion cut short by this pays
		# its death inside stop_chase(), and a narrative beat that started first
		# would be talking over a death animation.
		shadow.stop_chase()
	reached.emit(end_dialogue_id)


func _update_extents() -> void:
	if _shape == null:
		return
	(_shape.shape as RectangleShape2D).size = size.max(Vector2.ONE)
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-size * 0.5, size), EDITOR_TINT)
