class_name NoteTile
extends StaticBody2D
## One musical tile: a SOLID coloured 1-cell block that sounds its note when
## Hooshang makes contact — standing on top of it, head-butting it from
## underneath, or brushing a side. Five of these in the right order grant the
## glow; the ordering itself lives in scripts/note_sequence.gd, which listens
## to `stepped`. This node only knows its own index and how to sound.
##
## It is a StaticBody2D (world layer) so it blocks and can be landed on, plus a
## slightly oversized Area2D "skin" for detection. The skin is needed because a
## StaticBody2D emits no contact signals of its own, and because resting
## exactly ON a surface is a touch, not an overlap — the skin stands 2px proud
## of the solid box on every side so any real contact registers.
##
## Joins the "note_tile" group so the sequence manager finds every tile without
## a hardcoded list (STYLE_GUIDE §4).

signal stepped(tile: NoteTile)

const CELL := 16.0
## How far the detection skin stands proud of the solid box, per side.
const SKIN := 2.0

## 1-5. Which position in the sequence this tile is. Set per instance, or from
## the LDtk entity's NoteIndex field.
@export_range(1, 5) var note_index := 1:
	set(v):
		note_index = v
		_apply()
## Pulse the pad brighter for a moment when it sounds.
@export var lit_time := 0.35
@export var lit_boost := 2.2
## Ignore repeat contacts within this window. Landing on a block can produce
## several enter/exit pairs as the player settles; that should be one note.
@export var retrigger_grace := 0.25

var _sprite: Sprite2D
var _audio: AudioStreamPlayer2D
var _tween: Tween
var _last_sound := -999.0


func _ready() -> void:
	add_to_group("note_tile")
	collision_layer = 1  # world: the player collides with it
	collision_mask = 0

	var solid := CollisionShape2D.new()
	var solid_rect := RectangleShape2D.new()
	solid_rect.size = Vector2(CELL, CELL)
	solid.shape = solid_rect
	add_child(solid)

	var touch := Area2D.new()
	touch.name = "Touch"
	touch.collision_layer = 0
	touch.collision_mask = 2  # player only
	var touch_shape := CollisionShape2D.new()
	var touch_rect := RectangleShape2D.new()
	touch_rect.size = Vector2(CELL + SKIN * 2.0, CELL + SKIN * 2.0)
	touch_shape.shape = touch_rect
	touch.add_child(touch_shape)
	add_child(touch)

	_sprite = Sprite2D.new()
	add_child(_sprite)

	_audio = AudioStreamPlayer2D.new()
	add_child(_audio)

	_apply()
	touch.body_entered.connect(_on_touched)


func _apply() -> void:
	if _sprite == null:
		return
	var i := clampi(note_index, 1, 5)
	_sprite.texture = load("res://assets/notes/note_%d.png" % i)
	_audio.stream = load("res://assets/notes/note_%d.wav" % i)


func _on_touched(body: Node2D) -> void:
	if body is not Player:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_sound < retrigger_grace:
		return
	_last_sound = now
	sound()
	stepped.emit(self)


## Play this tile's note and flash the pad. Public so the sequence manager can
## replay a tile independently of contact.
func sound() -> void:
	if _audio.stream != null:
		_audio.play()
	if _tween and _tween.is_valid():
		_tween.kill()
	_sprite.modulate = Color(lit_boost, lit_boost, lit_boost)
	_tween = create_tween()
	_tween.tween_property(_sprite, "modulate", Color.WHITE, lit_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
