class_name InputPrompt
extends Node2D
## A Celeste-style input bubble that floats over the spot a move is made from.
##
## WORLD-SPACE, like EmoteBubble and for the same reason: it is attached to a
## PLACE in the room, and the dialogue box's surface is a flat screen overlay
## that knows nothing about where the camera is. It is drawn at 320x180 with
## everything else, which is why the art is hand-set pixels rather than a
## downscale (tools/gen_input_prompt.py).
##
## It says one thing and waits. Nothing about it is timed: it appears when the
## move becomes necessary and leaves when the move is made, so a player who
## stands and reads it is not punished and a player who already knows never sees
## it for long.

const ART := preload("res://assets/ui/prompt_dash.png")

## How far above the anchor the bubble's tail sits.
@export var lift := 22.0
## The rise and fade it comes in on.
@export var pop_from := 5.0
@export var pop_time := 0.22
@export var fade_time := 0.18
## How far it drifts, and how long one drift takes. A prompt that is perfectly
## still reads as part of the level art.
@export var bob := 1.5
@export var bob_time := 1.4

var _sprite: Sprite2D
var _bob: Tween


func _ready() -> void:
	z_as_relative = false
	z_index = 1                      # over the props, under nothing that matters
	_sprite = Sprite2D.new()
	_sprite.texture = ART
	# The tail is the bottom of the art, so the sprite hangs entirely ABOVE the
	# point it is anchored to and never covers the gap he is being asked to jump.
	_sprite.centered = false
	_sprite.offset = Vector2(-ART.get_width() * 0.5, -ART.get_height())
	_sprite.modulate.a = 0.0
	add_child(_sprite)


## Float it in over `at` (a world position — the spot he is standing on).
## `texture` defaults to the dash art so DashTutorial's existing call needs no
## change; a lesson with more than one picture (JumpTutorial's keyboard vs.
## controller art) passes its own.
func show_at(at: Vector2, texture: Texture2D = ART) -> void:
	_sprite.texture = texture
	global_position = at + Vector2(0.0, -lift)
	_sprite.position.y = pop_from
	var t := create_tween().set_parallel()
	t.tween_property(_sprite, "modulate:a", 1.0, pop_time)
	t.tween_property(_sprite, "position:y", 0.0, pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(_start_bob)


## Swap the picture on a prompt that is already up — JumpTutorial calls this
## when InputDevice reports he switched between keyboard and controller mid
## display, so the badge he is looking at never lies about what to press.
func set_texture(texture: Texture2D) -> void:
	if _sprite != null:
		_sprite.texture = texture


func _start_bob() -> void:
	_bob = create_tween().set_loops()
	_bob.tween_property(_sprite, "position:y", -bob, bob_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(_sprite, "position:y", 0.0, bob_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Fade out and free. Safe to call twice.
func dismiss() -> void:
	if _bob != null and _bob.is_valid():
		_bob.kill()
	var t := create_tween().set_parallel()
	t.tween_property(_sprite, "modulate:a", 0.0, fade_time)
	t.tween_property(_sprite, "position:y", -6.0, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)
