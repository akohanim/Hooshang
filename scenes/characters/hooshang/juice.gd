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

## The sheet Hooshang comes apart into — three shapes, 8px cells. Draw it with
## tools/gen_death_shards.py.
const SHARD_SHEET := preload("res://assets/effects/death_shard.png")
const SHARD_CELL := 8.0
const SHARD_SHAPES := 3

@export_group("Death")
## How many shards the burst throws. Celeste's is a ring, not a spray: they go
## out evenly and the eye reads a circle opening rather than a puff.
@export var death_shards := 12
## How far they travel, in px. Jittered per shard by death_spread so the ring
## breaks up on its way out instead of staying a perfect circle.
@export var death_reach := 26.0
@export_range(0.0, 1.0) var death_spread := 0.35
## How long a shard flies before it is gone. Shorter than the full death pause
## on purpose — the burst should be over and the screen still for a beat before
## he comes back, which is what makes the respawn feel like a new attempt
## rather than a bounce.
@export var death_shard_time := 0.32
## How big a shard starts and ends, as a multiple of the 8px art. They shrink as
## they fly, which is what sells them as debris losing energy.
@export var death_shard_scale := 0.75
## Colour of the burst. White-hot at the centre of the ring, so it reads against
## both the dark office and a lit room.
@export var death_tint := Color(0.93, 0.96, 1.0, 1.0)
## The freeze on the frame he dies. Real seconds — the whole screen stops, which
## is the single biggest reason a Celeste death lands as an event.
@export var death_hitstop := 0.08

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


# ---------------------------------------------------------------- death ----

## Call the instant he dies. Throws the burst, freezes the screen for a frame or
## two, and shakes the camera.
##
## Everything here is cosmetic and nothing waits on it: the shards live in the
## room and free themselves, so the player is free to respawn on top of them and
## the burst simply finishes where it happened. How long the game HOLDS before
## respawning is Player.death_time, not this — an animation that also controlled
## the pacing would mean retuning the feel every time the art changed.
func on_death() -> void:
	hitstop(death_hitstop)
	_camera_shake(landing_shake_max_strength, landing_shake_time)
	var world := _player.get_parent()
	if world == null:
		return
	for i in death_shards:
		_spawn_shard(world, i)


## One piece of him, thrown out along the ring and shrinking as it goes.
func _spawn_shard(world: Node, index: int) -> void:
	var shard := Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = SHARD_SHEET
	# Shapes cycle rather than being picked at random: a ring of 12 that has
	# every shape spread evenly around it looks broken up, where 12 random picks
	# reliably clumps three of a kind together somewhere.
	tex.region = Rect2((index % SHARD_SHAPES) * SHARD_CELL, 0.0, SHARD_CELL, SHARD_CELL)
	shard.texture = tex
	shard.modulate = death_tint
	shard.global_position = _player.global_position
	shard.rotation = TAU * float(index) / float(death_shards)
	shard.scale = Vector2.ONE * death_shard_scale
	# Same two rules the dash trail learned: parent to the ROOM (levels live in
	# Screen's sub-viewport, so current_scene is the UI surface), and stay in the
	# playable band rather than dropping behind the tiles.
	shard.z_as_relative = false
	shard.z_index = 0
	world.add_child(shard)

	var angle := TAU * float(index) / float(death_shards)
	var reach: float = death_reach * (1.0 + randf_range(-death_spread, death_spread))
	var to: Vector2 = _player.global_position + Vector2.RIGHT.rotated(angle) * reach
	var t := shard.create_tween().set_parallel()
	t.tween_property(shard, "global_position", to, death_shard_time) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(shard, "scale", Vector2.ZERO, death_shard_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(shard, "rotation", shard.rotation + TAU * 0.4, death_shard_time)
	t.tween_property(shard, "modulate:a", 0.0, death_shard_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(shard.queue_free)


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

	# Parent to the PLAYER'S PARENT — the level — not get_tree().current_scene.
	# Levels load into Screen's game sub-viewport, so current_scene is the root
	# UI scene: afterimages were landing on the UI surface, at window resolution
	# and in window coordinates, i.e. the wrong size in the wrong place.
	#
	# Depth: stay in the playable band (z 0) rather than dropping to -1, which is
	# the BACKGROUND band and would draw the trail behind floors and walls.
	# Within one band draw order is sibling order, so slotting in at the player's
	# own index puts the trail in front of the tiles and behind the player.
	img.z_as_relative = false
	img.z_index = 0
	var world := _player.get_parent()
	if world == null:
		return
	world.add_child(img)
	world.move_child(img, _player.get_index())
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


## Bounce the camera for something that isn't a landing — an impact nearby, a
## single hard jolt. Same dip-and-spring as a hard landing so a one-off knock
## always reads the same way; only the reason differs.
func shake(strength: float, duration: float) -> void:
	_camera_shake(strength, duration)


## A sustained tremor: the building coming down, not a thing landing on it.
##
## Deliberately NOT _camera_shake repeated. That is one smooth dip and a spring
## back — weighty, and completely wrong here, because a collapse is not an impact
## with a direction. This is a rattle: short random steps in both axes, which is
## the difference between "something hit the floor" and "the floor is failing".
##
## It DECAYS across the duration, so the shaking stops because the building
## settles rather than because a tween ran out — a rumble cut off at full
## strength reads as a bug in the effect.
func rumble(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_camera.offset = Vector2.ZERO
	_shake_tween = create_tween()
	# Short enough to read as a rattle rather than a sway. Much below this and
	# the camera is moving less than one screen pixel per step at 320x180, so the
	# tremor quietly stops being visible at all.
	const STEP := 0.045
	var steps := maxi(int(duration / STEP), 2)
	var rng := RandomNumberGenerator.new()
	for i in steps:
		var fade := 1.0 - float(i) / float(steps)
		var to := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) \
			* strength * fade
		_shake_tween.tween_property(_camera, "offset", to, STEP) \
			.set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(_camera, "offset", Vector2.ZERO, STEP * 2.0)


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
