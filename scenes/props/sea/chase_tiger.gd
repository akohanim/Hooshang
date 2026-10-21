class_name ChaseTiger
extends Node2D
## The tiger of the way home (SCRIPT.md TWELVE): it steps out of the tall grass
## and runs Hooshang to the edge of the land. Its twin waits at the foot of the
## cliff (THIRTEEN). Staged by Act3Beats; art from tools/gen_tiger.py.
##
## It chases as a DELAYED ECHO of his own path, the way Darkshang chases him in
## Act I: it leaps every gap he leaps, `follow_delay` behind him, so it catches
## only a man who stops. Its tape is its own rather than Darkshang's
## PlayerPositionBuffer, for two reasons that both showed up in play: it
## records only while he is FREE TO MOVE, so a room slide or a cutscene pauses
## the chase instead of handing the tiger the seconds he spent frozen; and it is
## laid down again on EVERY respawn, not only on one far enough away to look
## like a teleport. A tiger that caught him a few pixels from the checkpoint
## used to catch him again the instant he stood up, forever. After a respawn it
## waits behind him until he moves `hold_distance`, like the shadow at a
## threshold in Act I.

signal caught

const SHEET := preload("res://assets/characters/tiger/tiger.png")
const DATA_PATH := "res://assets/characters/tiger/tiger.json"
const FRAME := Vector2(44, 22)
## Where the paws meet the ground inside a frame, from its top-left.
const FEET := Vector2(22, 21)
## The way he came from: the chase runs right, so his run-up lies to the left.
const BEHIND := Vector2.LEFT
const TICK := 60.0

## Seconds behind him on his own path. Shorter is a closer, crueller chase.
@export var follow_delay := 1.0
## Speed of the run-up laid behind him after a respawn, px/s (his run speed).
@export var run_in_speed := 72.0
## How far he has to move after a respawn before it comes on again, px.
@export var hold_distance := 16.0
## The jaws: a box just ahead of its shoulders, px. Small on purpose: the echo
## is where he was a second ago, so it bites only when it is truly on him.
@export var catch_size := Vector2(10.0, 10.0)

var chasing := false
var visual: AnimatedSprite2D
var _tape := PackedVector2Array()
var _player: Player
var _hold_at := Vector2.INF
var _was_dead := false

static var _frames: SpriteFrames


## The tiger's clips, cut from the exported sheet by its Aseprite tags.
static func sprite_frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	_frames = SpriteFrames.new()
	_frames.remove_animation(&"default")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not data is Dictionary:
		push_error("ChaseTiger: %s is missing or unreadable" % DATA_PATH)
		return _frames
	var frames: Array = data["frames"]
	for tag: Dictionary in data["meta"]["frameTags"]:
		var name := StringName(tag["name"])
		_frames.add_animation(name)
		_frames.set_animation_loop(name, true)
		_frames.set_animation_speed(name, 1000.0)
		for i in range(int(tag["from"]), int(tag["to"]) + 1):
			var box: Dictionary = frames[i]["frame"]
			var atlas := AtlasTexture.new()
			atlas.atlas = SHEET
			atlas.region = Rect2(box["x"], box["y"], box["w"], box["h"])
			_frames.add_frame(name, atlas, float(frames[i]["duration"]))
	return _frames


func _ready() -> void:
	visual = AnimatedSprite2D.new()
	visual.name = "Visual"
	visual.sprite_frames = sprite_frames()
	visual.centered = false
	visual.offset = -FEET
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(visual)
	visual.play(&"walk")
	z_index = 4


## Start running him down from where he stands.
func chase(player: Player) -> void:
	_player = player
	_reseed()
	chasing = true


func stop() -> void:
	chasing = false


## His past, as a straight run-up ending where he stands now.
func _reseed() -> void:
	_tape.clear()
	var frames := int(follow_delay * TICK) + 2
	var step := BEHIND * (run_in_speed / TICK)
	for i in frames:
		_tape.append(_player.global_position + step * float(frames - 1 - i))
	_hold_at = _player.global_position


func _echo() -> Vector2:
	var back := int(round(follow_delay * TICK))
	return _tape[maxi(0, _tape.size() - 1 - back)]


func _physics_process(delta: float) -> void:
	if not chasing or _player == null:
		return
	if _player.state == Player.State.DEAD:
		_was_dead = true
		return
	if _was_dead:
		_was_dead = false
		_reseed()
	# Frozen for a slide or held by a beat: the chase waits with him.
	if _player.input_locked:
		return
	if _hold_at != Vector2.INF:
		if _player.global_position.distance_to(_hold_at) < hold_distance:
			_reseed()
		else:
			_hold_at = Vector2.INF
	_tape.append(_player.global_position)
	if _tape.size() > 600:
		_tape = _tape.slice(_tape.size() - 600)
	var target := _echo() + Vector2(0.0, Player.HALF_HEIGHT)
	var speed := (target - global_position) / maxf(delta, 1e-4)
	global_position = target
	if absf(speed.x) > 4.0:
		visual.flip_h = speed.x < 0.0
	var clip := &"run" if speed.length() > 24.0 else &"walk"
	if visual.animation != clip:
		visual.play(clip)
	visual.speed_scale = 1.0 if speed.length() > 4.0 else 0.0
	var reach := 1.0 if not visual.flip_h else -1.0
	var jaws := Rect2(global_position + Vector2(reach * 6.0 - catch_size.x * 0.5, -catch_size.y - 3.0), catch_size)
	if jaws.intersects(_player.hitbox_rect()):
		caught.emit()
		_player.die()
