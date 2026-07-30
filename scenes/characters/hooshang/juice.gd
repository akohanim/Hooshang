class_name Juice
extends Node
## Self-contained "game feel" component: squash & stretch, dash afterimages,
## camera shake, and hitstop.
##
## HOW THIS WORKS: the player controller calls this node's public methods at
## the moments things happen (on_jump, on_land, on_dash_start, dash_tick) —
## this node never reaches into the player's state machine itself. That
## one-way flow means you can rip Juice out entirely (delete the node) and
## the game still plays identically; you'd just lose the polish.
##
## WIRE-UP: expects to be a child of the player, with two sibling nodes:
## a "SpriteSquash" Node2D wrapping the visible sprite (scale tweens apply
## here, never on the sprite's own base scale) and that sprite itself named
## "Visual" (an AnimatedSprite2D), plus a "Camera2D".

@export_group("Squash & Stretch")
## How long the pre-jump crouch takes to reach its deepest point. This is the
## visual "anticipation" — it does NOT delay the actual jump; the jump impulse
## fires on the same frame it always did, this just plays alongside it.
@export var jump_anticipation_time := 0.05
## How squashed the crouch gets (x,y multiplier). Wide and short.
@export var jump_anticipation_scale := Vector2(1.2, 0.75)
## How long the launch stretch takes to reach its most stretched point.
@export var jump_squash_time := 0.08
## How stretched the launch pose gets. Narrow and tall.
@export var jump_squash_scale := Vector2(0.75, 1.25)
## Landing squash at the hardest possible impact (x,y multiplier). Softer
## landings blend toward Vector2.ONE — see landing_shake_max_speed below.
@export var land_squash_scale := Vector2(1.3, 0.7)
## Time to ease back to normal scale after either a jump or a landing.
@export var squash_ease_time := 0.13

@export_group("Dash Trail")
@export var trail_enabled := true
## Spawn a new afterimage this often while dashing.
@export var trail_interval := 0.025
## How long each afterimage takes to fade out and free itself.
@export var trail_lifetime := 0.18
## Warm gold, ties into the Rumi/dash-grant theme (alpha here sets max opacity).
@export var trail_color := Color(1.0, 0.82, 0.35, 0.55)

@export_group("Camera")
## Landings slower than this don't bounce the camera or squash much at all.
@export var landing_shake_min_speed := 160.0
## Landings at or above this speed give the FULL bounce/squash strength.
@export var landing_shake_max_speed := 260.0
## How far the camera dips down on impact, in pixels, at full strength
## (Celeste-style smooth dip + spring-back, not random jitter).
@export var landing_shake_max_strength := 0.9
@export var landing_shake_time := 0.18
## True "everything pauses" hitstop on dash start. Real seconds, not scaled.
@export var hitstop_time := 0.04
## How slow time gets during hitstop. Not exactly 0 to dodge zero-delta edge
## cases elsewhere in the engine.
@export_range(0.0, 1.0) var hitstop_time_scale := 0.05

@onready var _player: Node2D = get_parent()
@onready var _sprite_squash: Node2D = _player.get_node("SpriteSquash")
@onready var _visual: AnimatedSprite2D = _player.get_node("SpriteSquash/Visual")
@onready var _camera: Camera2D = _player.get_node("Camera2D")

var _squash_tween: Tween
var _shake_tween: Tween
var _trail_timer := 0.0


func _exit_tree() -> void:
	# Safety net: if the player is freed mid-hitstop (e.g. a death right after
	# a dash), don't leave the whole game stuck in slow motion.
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0


# --------------------------------------------------------- squash/stretch ----

## Call the instant a jump's velocity is applied (buffered, coyote, or wall
## jump — doesn't matter which). Purely cosmetic; never delays the jump.
func on_jump() -> void:
	_play_squash_sequence([
		[jump_anticipation_scale, jump_anticipation_time],
		[jump_squash_scale, jump_squash_time],
		[Vector2.ONE, squash_ease_time],
	], Tween.EASE_OUT, Tween.TRANS_QUAD)


## Call right after landing is detected, passing the vertical speed the
## player was falling at the instant of impact (velocity.y BEFORE
## move_and_slide resolves the collision). Harder falls squash more and
## shake the camera; soft landings barely register.
func on_land(impact_speed: float) -> void:
	var t := clampf(
		(impact_speed - landing_shake_min_speed)
			/ maxf(landing_shake_max_speed - landing_shake_min_speed, 1.0),
		0.0, 1.0)
	if t <= 0.0:
		return  # too soft a landing to bother with
	var squash := Vector2.ONE.lerp(land_squash_scale, t)
	_play_squash_sequence([
		[squash, 0.03],
		[Vector2.ONE, squash_ease_time],
	], Tween.EASE_OUT, Tween.TRANS_BACK)
	_camera_shake(landing_shake_max_strength * t, landing_shake_time)


func _play_squash_sequence(keys: Array, ease_mode: Tween.EaseType, trans_mode: Tween.TransitionType) -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_sprite_squash.scale = Vector2.ONE
	_squash_tween = create_tween()
	for key in keys:
		_squash_tween.tween_property(_sprite_squash, "scale", key[0], key[1]) \
			.set_ease(ease_mode).set_trans(trans_mode)


# --------------------------------------------------------------- dashing ----

## Call once, the moment a dash successfully starts.
func on_dash_start(_dash_dir: Vector2) -> void:
	_trail_timer = 0.0  # spawn the first afterimage immediately
	hitstop(hitstop_time)


## Call every physics frame while state == DASH, passing delta. Spawns
## afterimages at trail_interval; does nothing if trail_enabled is false.
func dash_tick(delta: float) -> void:
	if not trail_enabled:
		return
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = trail_interval
		_spawn_afterimage()


func _spawn_afterimage() -> void:
	if _visual.sprite_frames == null or not _visual.sprite_frames.has_animation(_visual.animation):
		return
	var img := Sprite2D.new()
	img.texture = _visual.sprite_frames.get_frame_texture(_visual.animation, _visual.frame)
	img.global_position = _visual.global_position
	img.global_rotation = _visual.global_rotation
	img.scale = _visual.global_scale
	img.flip_h = _visual.flip_h
	img.centered = _visual.centered
	img.offset = _visual.offset
	img.modulate = trail_color
	img.z_index = -1  # behind the live sprite
	get_tree().current_scene.add_child(img)
	var t := img.create_tween()
	t.tween_property(img, "modulate:a", 0.0, trail_lifetime)
	t.tween_callback(img.queue_free)


# ----------------------------------------------------------- camera/time ----

## True engine-wide hitstop: a brief real-time pause felt by everything on
## screen, not just the player. Restores itself even if this node is freed
## mid-freeze (see _exit_tree above).
func hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	Engine.time_scale = hitstop_time_scale
	# ignore_time_scale=true so this timer counts real seconds, not slowed ones.
	get_tree().create_timer(duration, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0)


## Celeste-style landing bounce: not random jitter — a single smooth dip
## downward (the screen "sags" under the impact) that springs back to
## rest with a touch of overshoot. Reads as weighty rather than noisy.
func _camera_shake(strength: float, duration: float) -> void:
	if strength <= 0.0:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_camera.offset = Vector2.ZERO
	_shake_tween = create_tween()
	_shake_tween.tween_property(_camera, "offset:y", strength, duration * 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(_camera, "offset:y", 0.0, duration * 0.75) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
