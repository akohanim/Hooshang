@tool
class_name Campfire
extends Node2D
## The campfire Jamshid sets during the Act 2 encounter — a stationary flame over
## two logs, plus a warm flickering light. Built in code from
## assets/props/campfire/flame.png (tools/gen_campfire.py) so there is no
## SpriteFrames .tres to keep in sync with the sheet's frame size.
##
## Starts UNLIT (cold logs, no light) and `light()` fades it up over
## `light_time`. The flame is unshaded with ordinary alpha blending: additive
## blending washed its orange bands out to white against the sunset sky.
## Its separate warm light still illuminates the characters at night.

const SHEET := preload("res://assets/props/campfire/flame.png")
const LIGHT_TEXTURE := preload("res://assets/light_radial.png")
const FRAMES := 6
const CELL := Vector2(16, 20)

## How bright the firelight burns once lit.
@export var light_energy := 0.28
## Radius of the firelight, as a texture_scale (light_radial.png is 128px, so
## radius = 64 x this).
@export var light_scale := 0.95
## Warm fire colour.
@export var light_color := Color(1.0, 0.72, 0.4, 1.0)
## Flame opacity; ordinary alpha preserves the source's shaded colour bands.
@export var flame_alpha := 1.0
## Seconds the fire takes to catch when light() is called.
@export var light_time := 1.2
## Flicker depth (fraction of energy) and speed, so the light breathes like fire.
@export var flicker_amount := 0.30
@export var flicker_speed := 11.0
## Play the flame animation and flicker in the editor too, so it can be placed.
@export var preview_in_editor := false

var _flame: AnimatedSprite2D
var _light: PointLight2D
var _lit := false
var _base_energy := 0.0
var _t := 0.0
var _audio: AudioStreamPlayer
var _shader: ShaderMaterial
## Full-strength fire ambience; quiet enough to leave dialogue clear.
@export var roar_volume_db := -10.0


func _ready() -> void:
	_build()
	set_process(true)


func _build() -> void:
	if _flame != null:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("burn")
	frames.set_animation_loop("burn", true)
	frames.set_animation_speed("burn", 12.0)
	for i in FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(Vector2(i * CELL.x, 0), CELL)
		frames.add_frame("burn", atlas)
	_flame = AnimatedSprite2D.new()
	_flame.name = "Flame"
	_flame.sprite_frames = frames
	_flame.animation = "burn"
	_flame.centered = true
	_flame.offset = Vector2(0, -CELL.y * 0.5)  # sit the logs on the origin (the ground)
	_shader = ShaderMaterial.new()
	_shader.shader = preload("res://assets/shaders/campfire_flicker.gdshader")
	_flame.material = _shader
	# Hold one silhouette: the source animation sways sideways between frames.
	# A pixel-snapped shader curls the upper tongues while the base stays anchored.
	_flame.frame = 1
	_flame.pause()
	add_child(_flame)

	_light = PointLight2D.new()
	_light.name = "Fire"
	_light.texture = LIGHT_TEXTURE
	_light.texture_scale = light_scale
	_light.color = light_color
	_light.energy = 0.0
	_light.position = Vector2(0, -CELL.y * 0.5)
	add_child(_light)

	# Cold until lit: the flame is hidden and the light is off. In the editor
	# preview we show it burning so it can be placed by eye.
	var showing := preview_in_editor and Engine.is_editor_hint()
	_flame.visible = showing
	_lit = showing
	if showing:
		_light.energy = light_energy
		_flame.modulate.a = flame_alpha
	_base_energy = light_energy if showing else 0.0
	if not Engine.is_editor_hint():
		_audio = AudioStreamPlayer.new()
		_audio.name = "FireAmbience"
		var stream := preload("res://assets/props/campfire/campfire_loop.res")
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = stream.data.size() / 2
			_audio.stream = stream
		add_child(_audio)


func _unshaded() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m


## Catch the fire: fade the flame in and raise the light over light_time.
func light() -> void:
	if _lit:
		return
	_lit = true
	_flame.visible = true
	_flame.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_flame, "modulate:a", flame_alpha, light_time)
	t.tween_method(func(e: float) -> void: _base_energy = e, 0.0, light_energy, light_time)


func is_lit() -> bool:
	return _lit


func _process(delta: float) -> void:
	if _light == null:
		return
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_t += delta * flicker_speed
	_shader.set_shader_parameter("flicker_time", _t / flicker_speed)
	_update_audio()
	queue_redraw()
	# Uneven brightness flicker, with no translation, rotation or scaling.
	var pulse := 0.5 + 0.30 * sin(_t) + 0.20 * sin(_t * 2.37 + 0.8)
	var brightness := 1.0 - flicker_amount * (1.0 - pulse)
	_light.energy = _base_energy * brightness
	_flame.self_modulate = Color(brightness, brightness, brightness, 1.0)


## Timelapse stages dim the fire without moving or rescaling its artwork.
func set_strength(value: float) -> void:
	_base_energy = light_energy * value
	_lit = value > 0.0
	_flame.visible = _lit
	_flame.scale = Vector2.ONE
	_flame.modulate.a = flame_alpha * value
	_update_audio()
	queue_redraw()


func _draw() -> void:
	# Sparse one-pixel embers lift away; the fire itself remains fixed.
	if _lit:
		var seconds := _t / flicker_speed
		for i in 4:
			var life := fposmod(seconds * (0.65 + i * 0.07) + i * 0.27, 1.0)
			var pos := Vector2(sin(seconds * 2.0 + i * 4) * 3.0, -9.0 - life * 19.0).round()
			draw_rect(Rect2(pos, Vector2.ONE), Color(1.0, 0.55 + 0.25 * life, 0.18, (1.0 - life) * _flame.modulate.a))
	# Logs remain after the last flame goes out.
	draw_line(Vector2(-6, -2), Vector2(6, -1), Color(0.24, 0.15, 0.10), 2.0)
	draw_line(Vector2(-5, -1), Vector2(5, -3), Color(0.38, 0.24, 0.14), 2.0)


func _update_audio() -> void:
	if _audio == null or _audio.stream == null:
		return
	var strength := _base_energy / maxf(light_energy, 0.001)
	if strength <= 0.001:
		_audio.stop()
		return
	_audio.volume_db = roar_volume_db + linear_to_db(strength)
	if not _audio.playing:
		_audio.play()
