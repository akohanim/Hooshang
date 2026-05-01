extends Camera2D

## Frame-rate-independent exponential weight.
## 0.1 means ~10 % of the distance is closed each frame at 60 fps.
const FOLLOW_WEIGHT    := 0.10

## Maximum look-ahead offset in pixels.
const LOOK_AHEAD_DIST  := 52.0
## How quickly the look-ahead offset catches up. Lower = lazier.
const LOOK_AHEAD_SPEED := 4.0

## Minimum horizontal speed before the look-ahead engages.
const LOOK_AHEAD_THRESHOLD := 10.0

## Set by Main._ready() so the camera knows who to follow.
var target : CharacterBody2D = null

var _look_ahead := Vector2.ZERO


func _ready() -> void:
	# Disable the built-in positional smoothing; we drive position manually.
	position_smoothing_enabled = false
	ignore_rotation            = true


func _process(delta: float) -> void:
	if target == null:
		return

	_update_look_ahead(delta)

	# Frame-rate-independent lerp: converts the per-frame weight to a rate
	# so the feel stays constant at any refresh rate.
	var weight  := 1.0 - pow(1.0 - FOLLOW_WEIGHT, delta * 60.0)
	var desired := target.global_position + _look_ahead
	global_position = global_position.lerp(desired, weight)


func _update_look_ahead(delta: float) -> void:
	var vel_x        := target.velocity.x
	var target_ahead := Vector2.ZERO

	if absf(vel_x) > LOOK_AHEAD_THRESHOLD:
		target_ahead.x = signf(vel_x) * LOOK_AHEAD_DIST

	_look_ahead = _look_ahead.lerp(target_ahead, LOOK_AHEAD_SPEED * delta)


## Call this from Main after the TileMapLayer is populated so the camera
## never reveals the void beyond the painted tile area.
func configure_limits(left: int, top: int, right: int, bottom: int) -> void:
	limit_left   = left
	limit_top    = top
	limit_right  = right
	limit_bottom = bottom
