extends AudioStreamPlayer
## Both looping arrangements share one transport. Room changes crossfade their
## gains without restarting either cue; the world's dialogue duck still acts on
## this player's volume, and the Settings music bus still mutes both together.

## Alternate, somber arrangement heard throughout the Darkshang chase.
@export var chase_stream: AudioStream
## Seconds to blend into or out of the chase arrangement.
@export var transition_time := 2.0
## First numbered room that uses the chase arrangement.
@export var chase_first_room := 14
## Last numbered room before the original arrangement returns.
@export var chase_last_room := 25

var _mix: AudioStreamSynchronized
var _chase_blend := 0.0
var _chase_target := false
var _fade: Tween


func _ready() -> void:
	if stream == null or chase_stream == null:
		return
	_mix = AudioStreamSynchronized.new()
	_mix.stream_count = 2
	_mix.set_sync_stream(0, stream)
	_mix.set_sync_stream(1, chase_stream)
	_set_blend(0.0)
	stream = _mix
	play()
	var world := get_parent()
	if world.has_signal("room_changed"):
		world.room_changed.connect(_on_room_changed)


func _on_room_changed(room: Node2D) -> void:
	var room_name := str(room.name)
	var suffix := room_name.trim_prefix("Level_")
	var number := suffix.to_int() if suffix.is_valid_int() else -1
	var chase := room_name.begins_with("Level_") and number >= chase_first_room and number <= chase_last_room
	if chase == _chase_target:
		return
	_chase_target = chase
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_method(_set_blend, _chase_blend, 1.0 if chase else 0.0, transition_time)


func _set_blend(value: float) -> void:
	_chase_blend = value
	# Equal-power fade avoids a hollow dip halfway through the scene change.
	_mix.set_sync_stream_volume(0, linear_to_db(maxf(cos(value * PI * 0.5), 0.00001)))
	_mix.set_sync_stream_volume(1, linear_to_db(maxf(sin(value * PI * 0.5), 0.00001)))
