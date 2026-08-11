class_name PlayerPositionBuffer
extends Node
## A rolling recording of where the player has been, one sample per physics
## frame, so something else can stand where he stood N seconds ago.
##
## Darkshang is a DELAYED ECHO of the player, and an echo needs a tape. This is
## the tape: a fixed-size ring of world positions with `get_position_at_delay()`
## reading back into it, interpolating between the two samples either side of the
## requested moment so the echo moves smoothly rather than in 1/60s steps.
##
## WHY IT IS NOT A CHILD OF Hooshang.tscn
##
## That scene is shared by every level in the game. Hanging a recorder on it
## would make every existing room pay for a mechanic exactly one room uses, and
## any bug in here would be a bug in levels 0-10. So the buffer lives beside
## Darkshang (he builds one in his own _ready) and finds the player through the
## `player` group each frame. Nothing about the player changes.
##
## RECORDING ORDER MATTERS. `process_physics_priority` is set to 1 so this runs
## AFTER the player's own _physics_process (priority 0) and its move_and_slide().
## Sampling before it would record the position he had at the END of the previous
## frame and quietly add one frame to every delay — the same reasoning as the
## note in conveyor_belt.gd.
##
## EVERYTHING HERE IS WORLD SPACE. Samples are `global_position`, so a tape does
## not care which room it was recorded in and a chase can cross a room boundary
## without anything being rebased. What it DOES care about is being teleported —
## see `teleported` below.

## Emitted when consecutive samples are further apart than any real movement
## could put them: the player was moved rather than having moved. A room
## transition (LdtkWorld._slide_to_room places him at the next room's spawn
## point), a respawn, and the debug room picker all do this, and a tape that
## replayed the jump as if it were a path would walk whatever is following it
## across the level in one frame.
signal teleported(to: Vector2)

## Longest delay the tape can be asked for, in seconds. Sizes the ring; asking
## for more than this returns the oldest sample there is. 4s is well over three
## times the chase's 1.2s default, so a longer chase across several rooms only
## needs the delay turned up, not this code changed.
@export var max_delay := 4.0

## Distance between consecutive samples that can only be a teleport, in px per
## physics frame. The player's fastest move is a 260 px/s dash = 4.4px a frame,
## so 64 (a 3840 px/s "run") cannot be reached by anything he can do on purpose.
@export var teleport_threshold := 64.0

## Spare samples kept on top of `max_delay`. Small, and only exists so a read at
## exactly max_delay still has a sample on BOTH sides to interpolate between
## rather than falling off the end of the tape.
@export var headroom_frames := 8

## Samples in the ring — max_delay's worth of frames plus the headroom. Public
## because "how far back can this actually see" is the one thing a caller might
## reasonably want to check, and it is derived rather than typed in.
var capacity := 0

var _samples: PackedVector2Array = PackedVector2Array()
## Index of the NEXT write. `_samples[(_head - 1) % capacity]` is the newest.
var _head := 0
## How many real samples have been written, capped at capacity. Below capacity
## the tape is still filling and a deep read has to clamp to the oldest.
var _filled := 0
var _tick := 60.0


func _ready() -> void:
	_tick = float(Engine.physics_ticks_per_second)
	capacity = int(ceil(maxf(max_delay, 0.0) * _tick)) + maxi(headroom_frames, 2)
	_samples.resize(capacity)
	process_physics_priority = 1


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	record(player.global_position)


## Write one sample. Public so a test (or a cutscene) can drive the tape by hand
## without a player in the tree.
func record(at: Vector2) -> void:
	if capacity == 0:
		return
	# Announce a jump BEFORE writing it, so a listener that reseeds the tape in
	# response is not immediately overwritten by the very sample that tripped it.
	if _filled > 0 and latest().distance_to(at) > teleport_threshold:
		teleported.emit(at)
		return
	_samples[_head] = at
	_head = (_head + 1) % capacity
	_filled = mini(_filled + 1, capacity)


## How many real samples the tape holds — 0 means nothing has been recorded yet
## and every read is a guess. Public so a follower can tell "he was at the origin"
## apart from "there is no tape".
func samples() -> int:
	return _filled


## Where the player was `seconds` ago, interpolated between the two samples
## either side of that moment.
##
## Clamps at both ends rather than failing: 0 (or less) is the live position, and
## a delay deeper than the tape holds returns the oldest sample. A chase that
## started two frames ago has no history to replay, and the honest answer there
## is "the start of the tape", not a zero vector at the world origin.
func get_position_at_delay(seconds: float) -> Vector2:
	if _filled == 0:
		return Vector2.ZERO
	var frames := maxf(seconds, 0.0) * _tick
	# The newest sample is 0 frames back, so the oldest readable one is _filled-1.
	frames = minf(frames, float(_filled - 1))
	var whole := int(floor(frames))
	var frac := frames - float(whole)
	var a := _sample_back(whole)
	if frac <= 0.0001 or whole + 1 > _filled - 1:
		return a
	return a.lerp(_sample_back(whole + 1), frac)


## Throw the tape away and start it again with `at` as the whole of history.
##
## Called on every respawn: the path Darkshang was replaying led to a player who
## no longer exists, and following it would walk him through the room to a corpse
## while the live player stands somewhere else entirely.
##
## `trail_dir` / `trail_speed` seed a SYNTHETIC path leading up to `at` instead of
## a flat one. A flat seed reads back as "he was standing here the whole time" at
## every depth, which puts the echo exactly on top of the player — an instant
## death on the first frame of every new life. Seeding a straight approach at
## `trail_speed` px/s along `-trail_dir` gives the echo the same gap it would have
## had if the player really had run in from behind. Both default to nothing, so
## `clear_and_seed(at)` alone still means "he has always been here".
func clear_and_seed(at: Vector2, trail_dir := Vector2.ZERO, trail_speed := 0.0) -> void:
	if capacity == 0:
		return
	var step := Vector2.ZERO
	if trail_dir != Vector2.ZERO and trail_speed > 0.0:
		step = trail_dir.normalized() * (trail_speed / _tick)
	# Written oldest-first so the ring ends up with `at` as the newest sample.
	for i in capacity:
		var back := capacity - 1 - i  # frames before "now"
		_samples[i] = at + step * float(back)
	_head = 0
	_filled = capacity


## Newest sample, i.e. where the player was at the end of the last physics frame.
func latest() -> Vector2:
	return _sample_back(0)


## `back` frames before the newest sample. Clamped to what exists.
func _sample_back(back: int) -> Vector2:
	if _filled == 0:
		return Vector2.ZERO
	var b := clampi(back, 0, _filled - 1)
	return _samples[(_head - 1 - b + capacity * 2) % capacity]
