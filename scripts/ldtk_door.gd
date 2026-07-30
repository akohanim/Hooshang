class_name LdtkDoor
extends Door
## The story door in the LDtk-authored level — a ONE-TIME beat, not a reusable
## mechanic. Rumi's trigger calls arm() the moment she fades out; the door
## swings open onto the black void behind it, and once Hooshang is standing at
## the doorway's centre he walks through and is gone.
##
## Extends Door (scenes/props/door.gd) rather than replacing it: the swing
## itself is still Door.open()/opened, this only adds the story sequencing on
## top. scripts/ldtk_entities_post_import.gd swaps this script in and puts the
## node in the "story_door" group so the Rumi trigger can find it.

signal walked_through

## How close (px) Hooshang's centre must be to the doorway's centre before he
## steps through. Roughly half his hitbox, so it triggers as he covers it.
@export var centre_tolerance := 5.0
## How long the final step into the doorway takes.
@export var step_time := 0.45
## How long he takes to fade into the dark once he's stepping through.
@export var fade_time := 0.7

var _armed := false
var _walking := false

@onready var _void: ColorRect = $Void


func _ready() -> void:
	# Only poll for the player once the door is actually open and waiting.
	set_physics_process(false)


## Called by the Rumi trigger once she's gone: swing open, then start watching
## for Hooshang to line up with the doorway.
func arm() -> void:
	if _armed:
		return
	_armed = true
	open()
	await opened
	if not _walking:
		set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if _walking:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	# You WALK through a door. Requiring both feet on the ground and a position
	# inside the opening matters because the doorway column is open all the way
	# to the ceiling: an x-only test (what this used to be) fired when the
	# player jump-dashed to the top corner far above the door, dissolving him
	# into the wall.
	if not player.is_on_floor():
		return
	var top := _void.global_position.y
	if player.global_position.y < top or player.global_position.y > top + _void.size.y:
		return
	if absf(player.global_position.x - doorway_centre_x()) <= centre_tolerance:
		_walk_through(player)


## World-space x of the middle of the opening, derived from the void panel so
## it stays correct no matter how the door art is offset or scaled.
func doorway_centre_x() -> float:
	return _void.global_position.x + _void.size.x * 0.5


func _walk_through(player: Player) -> void:
	_walking = true
	set_physics_process(false)

	# Take the controller out of the loop entirely for the walk-through: with
	# input_locked alone the state machine would still decelerate him to IDLE
	# and overwrite the run animation every frame. Freezing his
	# _physics_process lets this tween own his position and pose outright.
	player.input_locked = true
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.visual.play("run")

	var t := create_tween().set_parallel()
	t.tween_property(player, "global_position:x", doorway_centre_x(), step_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(player, "modulate:a", 0.0, fade_time)
	await t.finished

	player.visible = false
	walked_through.emit()
