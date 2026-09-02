@tool
class_name SpringPlatform
extends Platform
## A bounce pad: land on top of it and it launches him straight up, hard —
## Celeste/Mario-style, not a jump he chose. Extends Platform for the same
## reason CrumblingPlatform does: the one-cell/@tool/size-export/tile-laying
## machinery (platform.gd's _rebuild) is exactly what this needs too, and
## _after_rebuild() is the hook Platform exposes for a subclass to re-skin the
## tiles _rebuild() already laid out — see platform.gd's own doc on that hook.
##
## DETECTION COPIES CrumblingPlatform'S SKIN TRICK, for the same reason: a
## StaticBody2D emits no contact signals, so an Area2D standing proud of the
## top face is how this knows he is on top of it (not merely touching it from
## the side or below). _standing_on() is copied verbatim from
## crumbling_platform.gd rather than shared, because Platform itself has no
## reason to know about either subclass.
##
## NO RE-ARM STATE NEEDED, unlike CrumblingPlatform's _spent/_needs_clear.
## Player.bounce() sets velocity.y negative (upward) synchronously, so on the
## very next frame _standing_on()'s `velocity.y >= 0.0` check is false on its
## own — the platform cannot re-trigger itself before he has actually left,
## and it launches again next time he genuinely lands, forever. A spring is
## reusable by nature; nothing here has to remember that it fired.

## How hard it launches him, px/s upward. MUCH more than a full jump —
## reference is classic Mario's spring (a bounce that reaches a platform
## clearly out of a normal jump's range, not an assisted hop): a full held
## jump apexes at 34px (Player.jump_speed docs), and this is tuned to roughly
## double that, ~68px — measured directly (spawn, bounce(), track peak height),
## not derived, same as every other feel number in this project. Comfortably
## under the game's existing max vertical reach (jump+dash, ~85px — see
## Player.jump_speed's own doc and tests/world_bounds_test), so a spring can
## never punch through a ceiling that reach was built against.
@export var launch_speed := 480.0
## How long the compressed frame shows before it starts releasing — the
## "under his weight" beat in the reference, held long enough to actually read
## as a landing rather than a flicker.
@export var compress_time := 0.09
## How long the release stretch takes to settle back to idle scale.
@export var stretch_settle_time := 0.16

const IDLE := preload("res://assets/props/spring_platform/idle.png")
const COMPRESSED := preload("res://assets/props/spring_platform/compressed.png")

## How far the detection skin stands proud of the solid box — same value and
## same reasoning as CrumblingPlatform.SKIN.
const SKIN := 2.0

var _skin: Area2D
var _skin_shape: CollisionShape2D
var _bounce_tween: Tween


func _ready() -> void:
	super()
	set_process(not Engine.is_editor_hint())


func _after_rebuild() -> void:
	if _skin == null:
		_skin = Area2D.new()
		_skin.name = "Skin"
		_skin.collision_layer = 8  # layer 4 "triggers"
		_skin.collision_mask = 2   # player only
		_skin_shape = CollisionShape2D.new()
		_skin_shape.shape = RectangleShape2D.new()
		_skin.add_child(_skin_shape)
		add_child(_skin)
		_skin.body_entered.connect(_on_touched)
	(_skin_shape.shape as RectangleShape2D).size = size + Vector2(SKIN, SKIN) * 2.0
	_skin_shape.position = Vector2.ZERO
	_apply_frame(IDLE)


## Frames swap on every laid tile at once, same as CrumblingPlatform._apply_frame.
func _apply_frame(tex: Texture2D) -> void:
	if _visual == null:
		return
	for child in _visual.get_children():
		if child is Sprite2D:
			(child as Sprite2D).texture = tex


func _on_touched(body: Node2D) -> void:
	_try_launch(body)


## On top of it, not merely touching it — verbatim copy of
## CrumblingPlatform._standing_on's logic (see that file for why both the feet
## check and the velocity check are needed).
func _standing_on(who: Player) -> bool:
	var feet := who.global_position.y + Player.HALF_HEIGHT
	return feet <= top_y() + SKIN * 2.0 and who.velocity.y >= 0.0


func _try_launch(body: Node2D) -> void:
	if Engine.is_editor_hint() or body is not Player:
		return
	var who := body as Player
	if not _standing_on(who):
		return
	who.bounce(launch_speed)
	_play_bounce()


## Every player currently inside the detection skin — same shape as
## CrumblingPlatform._players_on_skin.
func _players_on_skin() -> Array[Player]:
	var found: Array[Player] = []
	if _skin == null:
		return found
	for body in _skin.get_overlapping_bodies():
		if body is Player:
			found.append(body as Player)
	return found


## Polled every frame, same reason CrumblingPlatform re-asks every frame: a
## body_entered landing can be mid-air relative to "on top" the instant it
## fires (rising into the skin from below, clipping its end), and this catches
## the frame it actually becomes a real landing.
func _process(_delta: float) -> void:
	for who in _players_on_skin():
		_try_launch(who)


## Compress, then release with a stretch that snaps back to rest — the visual
## half of the bounce, played once per launch. Two beats, matching the
## reference: (1) COMPRESSED art holds for compress_time, the coil visibly
## flattened under his weight; (2) the moment it lets go, back to IDLE art
## PLUS a tall/thin scale stretch (the coil overshooting on release) that
## eases back to Vector2.ONE — the same squash/stretch-via-scale-tween trick
## juice.gd uses for the player's own jump/land/dash, just on the prop instead
## of the character. The 8px tile has no room to draw a genuinely taller
## "stretched" frame without clipping (idle's own zigzag already nearly fills
## it — see gen_spring_platform.py's draw()), so the overshoot is a transform,
## not a third art frame.
func _play_bounce() -> void:
	_apply_frame(COMPRESSED)
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_bounce_tween.tween_interval(compress_time)
	_bounce_tween.tween_callback(func() -> void:
		_apply_frame(IDLE)
		_play_stretch())


## The release overshoot: tall and thin for an instant, settling back to
## Vector2.ONE with a spring-appropriate overshoot ease.
func _play_stretch() -> void:
	if _visual == null:
		return
	_visual.scale = Vector2(0.8, 1.35)
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector2.ONE, stretch_settle_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
