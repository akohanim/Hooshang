@tool
class_name Jellyfish
extends DarkThought
## Act III's thoughts: they drift DarkThought's paths (Motion / Amplitude / Speed
## / Phase are the same fields, the same "placed point is the centre of the
## path" rule), reset with every other thought on a death or a room entry
## (they ARE DarkThoughts, so LdtkWorld's DarkThought.reset_all covers them),
## and the TENTACLES kill.
##
## The difference is the BELL: landing on it — or swimming up into it from
## below the dome's rim, never through the tentacles — bounces him and hands back
## both the dash and the Dive (Player.refill_swim_dash). Rumi: "Though these,
## jaan, you may also land on." Red is lethal everywhere in this game, so the
## tentacles are drawn red and the bell is not.
##
## The kill box sits wholly BELOW the bell with a pixel of daylight between
## them, so a body coming down onto the dome meets the bell first and is already
## travelling up before it could reach a tentacle.

const SHEET := preload("res://assets/act3/sea/jellyfish.png")
const JELLY_FRAME := Vector2(16.0, 20.0)
const JELLY_FRAMES := 4
## The bell, in prop-local px (origin = sheet frame centre).
const BELL := Rect2(-7.0, -9.0, 14.0, 7.0)
## The tentacles' kill box.
const STING := Rect2(-4.0, -1.0, 8.0, 9.0)

## Launch off the bell in the air, px/s (a spring's ~1.6x jump).
@export var bounce_speed := 250.0
## The same off the bell underwater, where drag eats it quickly.
@export var swim_bounce_speed := 230.0

var _bounce_cooldown := 0.0
var _squash := 0.0


func _ready() -> void:
	super()
	light_color = Color(0.55, 0.9, 1.0)
	light_scale = 0.55
	light_energy = 1.0
	_apply_glow()


func _build_visual() -> void:
	super()
	_sprite.texture = _frame(0)


func _frame(i: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(Vector2(i * JELLY_FRAME.x, 0.0), JELLY_FRAME)
	return tex


func _apply_tone() -> void:
	if _sprite == null:
		return
	_sprite.texture = _frame(0)
	if _sprite.material == null:
		_sprite.material = _unshaded(false)


func _update_extents() -> void:
	if _shape == null:
		return
	_shape.shape.size = STING.size
	_shape.position = STING.get_center()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_clock += delta
	position = _origin + _offset(_clock)
	# The bell pulses on its own slow beat, quicker for a moment after a bounce.
	_squash = maxf(_squash - delta * 3.0, 0.0)
	if _sprite != null:
		_sprite.texture = _frame(int(_clock / 0.18) % JELLY_FRAMES)
		_sprite.scale = Vector2(1.0 + _squash * 0.25, 1.0 - _squash * 0.3)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_bounce_cooldown = maxf(_bounce_cooldown - delta, 0.0)
	if _bounce_cooldown > 0.0 or _removed:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.state == Player.State.DEAD:
		return
	var bell := Rect2(global_position + BELL.position, BELL.size)
	var body := player.hitbox_rect()
	if not bell.intersects(body):
		return
	# Coming DOWN onto the dome, or rising into it from beside it — but never
	# from underneath, through the tentacles.
	var feet := body.end.y
	if feet > bell.end.y + 1.0 and player.velocity.y < 0.0:
		return
	_bounce_cooldown = 0.25
	_squash = 1.0
	player.refill_swim_dash()
	if player.swimming():
		player.velocity.y = -swim_bounce_speed
	else:
		player.bounce(bounce_speed)
	Sfx.play(&"jelly")
