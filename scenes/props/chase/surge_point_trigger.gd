@tool
class_name SurgePointTrigger
extends Area2D
## The spot in a chase where Darkshang lunges. Walk into it and he telegraphs,
## then leaves the buffered path and comes straight at you for `surge_duration`.
##
## It only DESCRIBES the surge — the two numbers and where the line is drawn.
## Everything about what a surge does lives in darkshang.gd, the same split
## SlideZone/Player use: one node owns the movement, and a volume nearby is not
## allowed to be a second thing that moves him.
##
## FIRES ONCE. A trigger that re-armed on every overlap would surge again every
## time the player stepped back into it, which turns a set piece into a stutter;
## worse, a checkpoint inside one would ambush every single life. Darkshang
## re-arms the ones AHEAD of the player on respawn (see Darkshang.rearm points) —
## which is a decision about the route, so it belongs to him and not here.
##
## Place one in LDtk as a `SurgePoint` and stretch it across the corridor the
## lunge should start at; both fields are on the entity.

## Fired when the player crosses it, once. Carries the numbers so a room script
## can hang sound or a camera shake off the same beat Darkshang gets.
signal tripped(duration: float, intensity: float)

## Full size of the trigger box in px. LDtk sets this from the box you drag. A
## surge point normally spans the full height of the corridor it sits in — it is
## a line the player crosses, and one he can jump over is one he will.
@export var size := Vector2(16.0, 48.0):
	set(value):
		size = value
		_update_extents()

## How long the lunge lasts, in seconds. 1.2 is long enough to eat most of the
## chase gap at the default surge speed without being long enough to be
## unsurvivable — the player has to keep moving for about two seconds, which is
## one good decision rather than a war of attrition.
@export var surge_duration := 1.2

## How much of the read-delay the lunge eats, 0..1. 0.7 takes the default 1.2s
## delay down to 0.36s — he ends the surge roughly a third of the usual gap
## behind, which stays frightening until it recovers. 1.0 would put him exactly
## on top of the player, i.e. an unavoidable death.
@export_range(0.0, 1.0) var surge_intensity := 0.7

## Editor-only overlay colour. A trigger is invisible at runtime; this is a
## staging aid so the line is visible while a room is being laid out.
const EDITOR_TINT := Color(0.7, 0.25, 0.85, 0.25)

## Whether this one has already fired. Public so a test (and the respawn reset)
## can read it without guessing from behaviour.
var spent := false

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # the player and nothing else
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_update_extents()
	add_to_group("surge_point", true)
	if Engine.is_editor_hint():
		return
	# Connected HERE rather than in the import hook: a connection made at import
	# time does not survive being packed into the .scn (STYLE_GUIDE §9), and the
	# symptom is a trigger that silently never fires.
	body_entered.connect(_on_body_entered)


## Make it live again. Called by Darkshang on a respawn, for the points the
## player still has to get past.
func rearm() -> void:
	spent = false


func _on_body_entered(body: Node2D) -> void:
	if spent or body is not Player:
		return
	spent = true
	tripped.emit(surge_duration, surge_intensity)
	# The chase, not "the Darkshang in my room": there is one shadow, and finding
	# him by group is what lets a surge point be dropped anywhere along a route
	# that may later cross several rooms.
	var shadow := get_tree().get_first_node_in_group("darkshang") as Darkshang
	if shadow != null:
		shadow.surge(surge_duration, surge_intensity)


func _update_extents() -> void:
	if _shape == null:
		return
	(_shape.shape as RectangleShape2D).size = size.max(Vector2.ONE)
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-size * 0.5, size), EDITOR_TINT)
