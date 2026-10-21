class_name ChaseTiger
extends Node2D
## The tiger of the way home (SCRIPT.md TWELVE): it steps out of the tall grass
## and runs Hooshang to the edge of the land. Its twin waits at the foot of the
## cliff (THIRTEEN). Staged by Act3Beats; art from tools/gen_tiger.py.
##
## It is a PURSUER, not an echo. It used to replay his path a second behind him,
## Darkshang's way, and an echo is a recording, not a predator: it copied his
## pacing and his jumps on the spot, and when he doubled back it walked away from
## him and he could chase it. Now it keeps a TRAIL of his furthest progress only,
## the ground he opened up running right, recorded as a height per x, so pacing
## and jumping in place are never on it. Each frame it moves along that trail
## TOWARD wherever he is: on after him when he is ahead, back at him when he has
## turned round. It never moves away from him. It follows the trail's own
## heights, so it leaps every gap and log he leapt, and goes nowhere he has not.
##
## It runs a little slower than he does (`speed`), so a man who keeps running
## stays ahead and one who hesitates is caught; far behind (`catch_up_gap`) it
## runs faster (`catch_up_speed`) so it never drops off the screen. Its trail is
## recorded only while he is FREE TO MOVE, so a room slide or a cutscene pauses
## the chase. After a death the trail is laid down again as a run-up behind him
## and it waits there until he moves `hold_distance`.

signal caught

const SHEET := preload("res://assets/characters/tiger/tiger.png")
const DATA_PATH := "res://assets/characters/tiger/tiger.json"
const FRAME := Vector2(44, 22)
## Where the paws meet the ground inside a frame, from its top-left.
const FEET := Vector2(22, 21)

## How far behind him it starts after the roar or a respawn, px.
@export var start_gap := 72.0
## Its running pace, px/s. His run is 72: a little under means he gains while he
## keeps going and loses ground every time he stops.
@export var speed := 64.0
## Further behind than this (px, along x) it runs at `catch_up_speed`.
@export var catch_up_gap := 120.0
@export var catch_up_speed := 92.0
## How far he has to move after a respawn before it comes on again, px.
@export var hold_distance := 16.0
## The jaws: a box just ahead of its shoulders, px.
@export var catch_size := Vector2(10.0, 10.0)

var chasing := false
var visual: AnimatedSprite2D
## The trail: his furthest progress, as x (strictly increasing) and the height he
## was at there (his centre, world space).
var _xs := PackedFloat32Array()
var _ys := PackedFloat32Array()
var _x := 0.0
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


## A fresh start: the run-up laid behind him, and the hold set where he stands.
func _reseed() -> void:
	_lay_trail()
	_hold_at = _player.global_position


## A level run-up `start_gap` long ending where he stands, with the tiger at its
## far end. Re-laid every frame of the hold so it waits that far behind him; the
## hold point itself stays put, or he could never get clear of it.
func _lay_trail() -> void:
	var at := _player.global_position
	# On the ground, never at the top of a jump: a run-up laid at the height he
	# had in the air made the tiger hop on the spot with him.
	var y := at.y if _player.is_on_floor() or _ys.is_empty() else _ys[_ys.size() - 1]
	_xs.clear()
	_ys.clear()
	var n := 8
	for i in n + 1:
		_xs.append(at.x - start_gap * float(n - i) / n)
		_ys.append(y)
	_x = _xs[0]


## Extend the trail only where he has gone further than ever before.
func _record(at: Vector2) -> void:
	if _xs.is_empty() or at.x > _xs[_xs.size() - 1] + 0.5:
		_xs.append(at.x)
		_ys.append(at.y)


## The trail's height at `x`: where he was when he first got that far.
func height_at(x: float) -> float:
	var n := _xs.size()
	if n == 0:
		return global_position.y
	if x <= _xs[0]:
		return _ys[0]
	if x >= _xs[n - 1]:
		return _ys[n - 1]
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _xs[mid] <= x:
			lo = mid
		else:
			hi = mid
	var t := (x - _xs[lo]) / maxf(0.001, _xs[hi] - _xs[lo])
	return lerpf(_ys[lo], _ys[hi], t)


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
	var me := _player.global_position
	if _hold_at != Vector2.INF:
		if me.distance_to(_hold_at) < hold_distance:
			_lay_trail()
		else:
			_hold_at = Vector2.INF
	_record(me)
	# Toward him along the trail, whichever side of it he is on, never past him.
	var goal := clampf(me.x, _xs[0], _xs[_xs.size() - 1])
	var gap := absf(goal - _x)
	var pace := catch_up_speed if gap > catch_up_gap else speed
	var step := minf(gap, pace * delta)
	var dir := signf(goal - _x)
	_x += dir * step
	var was := global_position
	global_position = Vector2(_x, height_at(_x) + Player.HALF_HEIGHT)
	var moved := (global_position - was) / maxf(delta, 1e-4)
	if dir != 0.0:
		visual.flip_h = dir < 0.0
	var clip := &"run" if absf(moved.x) > 24.0 else &"walk"
	if visual.animation != clip:
		visual.play(clip)
	visual.speed_scale = 1.0 if moved.length() > 4.0 else 0.0
	var reach := -1.0 if visual.flip_h else 1.0
	var jaws := Rect2(global_position + Vector2(reach * 6.0 - catch_size.x * 0.5, -catch_size.y - 3.0), catch_size)
	if jaws.intersects(_player.hitbox_rect()):
		caught.emit()
		_player.die()
