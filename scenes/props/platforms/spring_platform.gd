@tool
class_name SpringPlatform
extends Platform
## A bounce pad: touch it and it launches him straight up, hard —
## Celeste/Mario-style, not a jump he chose. Extends Platform for the
## StaticBody2D/@tool/CollisionShape2D boilerplate it shares with
## CrumblingPlatform, NOT for Platform's own _rebuild() any more — see FIXED
## SIZE below for why that stopped fitting.
##
## DETECTION COPIES CrumblingPlatform'S SKIN TRICK, for the same reason: a
## StaticBody2D emits no contact signals, so an Area2D standing proud on
## every face is how this knows he has touched it at all. UNLIKE
## CrumblingPlatform, this no longer narrows that to "on top of it" — AT THE
## USER'S EXPLICIT DIRECTION: a solid FIXED_SIZE box the same height as a
## floor cell used to require jumping UP onto its top face before it would
## fire, which played as a small wall blocking the way rather than a spring
## in the floor he could just walk into. _touching() (renamed from the
## crumbling_platform.gd original this used to share verbatim, since it is no
## longer the same check) drops the top-surface height test and keeps only
## the "not already rising away from it" one, so contact from any side —
## walked into from the ground, same as landed on from above — launches him.
##
## NO RE-ARM STATE NEEDED, unlike CrumblingPlatform's _spent/_needs_clear.
## Player.bounce() sets velocity.y negative (upward) synchronously, so on the
## very next frame _touching()'s `velocity.y >= 0.0` check is false on its
## own — the platform cannot re-trigger itself before he has actually left,
## and it launches again next time he genuinely lands, forever. A spring is
## reusable by nature; nothing here has to remember that it fired.
##
## FIXED SIZE (2026-09), AT THE USER'S EXPLICIT DIRECTION: "16px x 8px when
## compact, 16px x 16px when expanded — this should be the only size for this
## entity." Two consequences:
##
## 1. This is no longer a stretchable Platform-style tile. Platform's own
##    _rebuild() lays copies of a 24px-wide repeating unit across whatever
##    `size.x` says (platform.gd's TILE, shared with Platform/
##    CrumblingPlatform) — exactly right for a ledge a level author drags to
##    whatever length, and no longer what this prop is. SpringPlatform now
##    overrides _rebuild() COMPLETELY (not Platform's _after_rebuild() hook,
##    which existed to re-skin tiles _rebuild() already laid out) and builds
##    one sprite, always FIXED_SIZE.
##
## 2. `size` ITSELF is still inherited from Platform, unchanged, rather than
##    redeclared here to lock it — VERIFIED this is not optional: GDScript
##    refuses to redeclare a property a parent class already exports, hard
##    parse error ("The member 'size' already exists in parent class
##    Platform"), not silently shadowed. So `size` still exists, still takes
##    whatever the LDtk importer's shared _build_platform() helper (or a
##    stray Inspector drag, or a stale saved level) hands it, and Platform's
##    own inherited setter still clamps its Y to CELL and calls _rebuild() —
##    none of that changed. What makes "the only size" an actual GUARANTEE
##    rather than a convention nobody enforces is that _rebuild() below never
##    reads `size` for anything: the collision shape, the sprite, and the
##    detection skin are all built from FIXED_SIZE. A level that somehow still
##    asks for a different width gets a SpringPlatform that quietly ignores
##    the request rather than one that is wrong on screen.
const FIXED_SIZE := Vector2(16.0, 8.0)

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
## How long the EXPANDED frame holds before easing back to IDLE — the "just
## let go" beat, the coil visibly taller than its own resting height.
@export var expand_time := 0.12
## How long the settle-back-to-rest bounce takes once EXPANDED hands back to
## IDLE.
@export var stretch_settle_time := 0.16

## IDLE/COMPRESSED share the compact 16x8 canvas; EXPANDED is its own taller
## 16x16 canvas — a REAL third frame now, not a scale trick played on IDLE.
## See tools/gen_spring_platform.py for why: an 8px-tall tile has no room to
## draw a taller pose without clipping, so an earlier pass scaled IDLE up
## tall-and-thin as a stand-in. The user asked for the coil to actually
## extend further up on launch, which needs actual extra pixels, which needs
## its own canvas — _apply_frame() below is what makes swapping between an
## 8-tall and a 16-tall texture look like the SAME object growing upward
## rather than the sprite jumping to a different vertical position.
const IDLE := preload("res://assets/props/spring_platform/idle.png")
const COMPRESSED := preload("res://assets/props/spring_platform/compressed.png")
const EXPANDED := preload("res://assets/props/spring_platform/expanded.png")

## How far the detection skin stands proud of the solid box — same value and
## same reasoning as CrumblingPlatform.SKIN.
const SKIN := 2.0

var _skin: Area2D
var _skin_shape: CollisionShape2D
var _bounce_tween: Tween


func _ready() -> void:
	super()
	set_process(not Engine.is_editor_hint())


## Full replacement for Platform's own _rebuild(), not a call to super() —
## see the class doc's FIXED SIZE note for why Platform's tile-laying loop no
## longer applies. One sprite, one collision box, both FIXED_SIZE regardless
## of what `size` currently holds.
func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual == null:
		_visual = Node2D.new()
		_visual.name = "Visual"
		add_child(_visual)
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "Shape"
		_shape.shape = RectangleShape2D.new()
		# Solid for a body landing on TOP, pass-through from underneath and
		# the sides — AT THE USER'S EXPLICIT DIRECTION, after a player jumping
		# up into its underside could get stuck against it (a plain solid box
		# there has nowhere to go: gravity pulls him back into it every
		# frame he is still rising, and _touching() already refuses to launch
		# him from that approach — see its own doc — so nothing was ever
		# going to resolve the contact). Godot's own one-way-collision is
		# exactly "solid from one face, transparent from the rest", the same
		# primitive every jump-through ledge in a platformer uses, and it
		# costs nothing here: side contact was already handled by the SKIN
		# Area2D (see _touching()), which has no idea whether the solid body
		# beneath it is one-way or not — a side approach still launches him
		# off the skin before he would ever need the solid box to stop him.
		_shape.one_way_collision = true
		add_child(_shape)
	for child in _visual.get_children():
		child.queue_free()
	(_shape.shape as RectangleShape2D).size = FIXED_SIZE
	_shape.position = Vector2.ZERO
	var tile := Sprite2D.new()
	tile.centered = false
	_visual.add_child(tile)
	_after_rebuild()


## Internal helper _rebuild() calls once its one sprite/shape exist — not
## Platform's own subclass hook any more (this class no longer goes through
## Platform's _rebuild() to reach it), just kept as its own method for the
## same "geometry, then skin/skin, then art" separation the old code had.
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
	(_skin_shape.shape as RectangleShape2D).size = FIXED_SIZE + Vector2(SKIN, SKIN) * 2.0
	_skin_shape.position = Vector2.ZERO
	_apply_frame(IDLE)


## Swap the one sprite's texture, bottom-anchored to FIXED_SIZE's own bottom
## edge — top_y()'s own reference point, where he actually stands — rather
## than to the texture's own size. That is what lets EXPANDED (16x16) grow
## the coil further UP on release instead of pushing the mount down through
## the floor: a taller texture's extra height is added entirely ABOVE the
## standable surface, and a compact one sits flush against it exactly as
## before.
func _apply_frame(tex: Texture2D) -> void:
	if _visual == null:
		return
	var tile := _visual.get_child(0) as Sprite2D
	if tile == null:
		return
	tile.texture = tex
	tile.position = Vector2(
		-FIXED_SIZE.x * 0.5, FIXED_SIZE.y * 0.5 - tex.get_height())


func _on_touched(body: Node2D) -> void:
	_try_launch(body)


## Any contact at all, from whichever side he approached — see the class
## doc's DETECTION note for why this dropped CrumblingPlatform's "on top of
## it" height test. The one thing still excluded is a body already rising
## away from a face it just bounced off (velocity.y negative, "up" in this
## project) — without it, the upward velocity bounce() itself just set would
## re-satisfy this on the very next physics frame and launch him again before
## he has actually left, forever.
func _touching(who: Player) -> bool:
	return who.velocity.y >= 0.0


func _try_launch(body: Node2D) -> void:
	if Engine.is_editor_hint() or body is not Player:
		return
	var who := body as Player
	if not _touching(who):
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


## Compress, expand, settle — the visual half of the bounce, played once per
## launch. Three beats now, matching the reference
## (mario.fandom.com/wiki/Spring_Jump) with a real frame each rather than a
## transform standing in for one: (1) COMPRESSED holds for compress_time, the
## coil visibly flattened wide under his weight; (2) the moment it lets go,
## _play_expand() below.
func _play_bounce() -> void:
	_apply_frame(COMPRESSED)
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_bounce_tween.tween_interval(compress_time)
	_bounce_tween.tween_callback(_play_expand)


## Beat two: the EXPANDED frame, genuinely taller than IDLE (see the class
## doc's FIXED SIZE note and tools/gen_spring_platform.py), held for
## expand_time before settling back down.
func _play_expand() -> void:
	_apply_frame(EXPANDED)
	var t := create_tween()
	t.tween_interval(expand_time)
	t.tween_callback(_play_settle)


## Beat three: back to IDLE, plus a small scale bounce easing to
## Vector2.ONE — the same squash/stretch-via-scale-tween trick juice.gd uses
## for the player's own jump/land/dash, now selling only the LANDING back
## down (EXPANDED's own art already sold the height, so this no longer has
## to fake it the way the old scale-only version did).
func _play_settle() -> void:
	_apply_frame(IDLE)
	if _visual == null:
		return
	_visual.scale = Vector2(1.12, 0.85)
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector2.ONE, stretch_settle_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
