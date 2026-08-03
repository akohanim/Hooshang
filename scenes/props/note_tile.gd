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
const LIGHT_TEXTURE := preload("res://assets/light_radial.png")
## light_radial.png is 128px, so its untouched radius is 64 (see LIGHTING.md).
const TEXTURE_RADIUS := 64.0

## 1-5. Which position in the sequence this tile is. Set per instance, or from
## the LDtk entity's NoteIndex field.
@export_range(1, 5) var note_index := 1:
	set(v):
		note_index = v
		_apply()
## Pulse the pad brighter for a moment when it sounds.
@export var lit_time := 0.35
@export var lit_boost := 2.2

@export_group("Glow")
## Resting glow. The cave is deliberately near-black, so an unlit pad still has
## to announce itself as something that can be stepped on — but only just.
@export var idle_energy := 0.5
## Glow while sounding. Kept close to the resting value on purpose: the pad
## brightening (lit_boost) is the loud part, this only widens the pool it
## throws. Pushing it much past ~1.6 clips the tile art to white.
@export var lit_energy := 1.5
## Radius of the pool, in px. Small: five of these sit side by side, and the
## cave's darkness is the point.
@export var glow_radius := 22.0
## Ignore repeat contacts within this window. Landing on a block can produce
## several enter/exit pairs as the player settles; that should be one note.
@export var retrigger_grace := 0.25

var _sprite: Sprite2D
var _light: PointLight2D
var _audio: AudioStreamPlayer2D
var _tween: Tween
var _glow_tween: Tween
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
	touch.collision_layer = 8  # layer 4 "triggers"
	touch.collision_mask = 2  # player only
	var touch_shape := CollisionShape2D.new()
	var touch_rect := RectangleShape2D.new()
	touch_rect.size = Vector2(CELL + SKIN * 2.0, CELL + SKIN * 2.0)
	touch_shape.shape = touch_rect
	touch.add_child(touch_shape)
	add_child(touch)

	_sprite = Sprite2D.new()
	add_child(_sprite)

	_light = PointLight2D.new()
	_light.name = "Glow"
	_light.texture = LIGHT_TEXTURE
	add_child(_light)

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
	if _light != null:
		_light.texture_scale = glow_radius / TEXTURE_RADIUS
		_light.color = _glow_color(_sprite.texture)
		_light.energy = idle_energy


## Glow colour for a pad, taken from the pad's own art so the two can never
## drift apart — re-colouring note_3.png re-colours its light with it.
##
## The pad colours are mid-tones (note_1 is a dull red), and a light tinted with
## a mid-tone just reads muddy, so the sampled colour is pushed up until its
## strongest channel is full. That keeps the hue and drops the dinginess.
func _glow_color(tex: Texture2D) -> Color:
	if tex == null:
		return Color.WHITE
	var img := tex.get_image()
	if img == null:
		return Color.WHITE
	var sum := Vector3.ZERO
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a <= 0.05:
				continue
			sum += Vector3(px.r, px.g, px.b)
			n += 1
	if n == 0:
		return Color.WHITE
	var avg := sum / float(n)
	var peak := maxf(avg.x, maxf(avg.y, avg.z))
	if peak > 0.001:
		avg /= peak
	return Color(avg.x, avg.y, avg.z)


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

	# The pool follows the pad up and back down on the same curve, so the two
	# read as one event rather than as a flash with a light chasing it.
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_light.energy = lit_energy
	_glow_tween = create_tween()
	_glow_tween.tween_property(_light, "energy", idle_energy, lit_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
