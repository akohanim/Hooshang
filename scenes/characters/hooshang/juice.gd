class_name Juice
extends Node
## Self-contained "game feel" component: squash & stretch, dash afterimages,
## camera shake, and hitstop.
##
## The camera only ever moves for something that happens TO him — death, a
## collapse, a scripted jolt. Jumping and landing are squash-and-stretch only.
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
## landings blend toward Vector2.ONE — see landing_squash_max_speed below.
@export var land_squash_scale := Vector2(1.3, 0.7)
## Time to ease back to normal scale after either a jump or a landing.
@export var squash_ease_time := 0.13
## How squashed a hard direction flip on the ground gets. Narrow and tall — he
## leans into the turn — which is the opposite of a landing and reads as one.
@export var turn_squash_scale := Vector2(0.74, 1.16)
@export var turn_squash_time := 0.06
## Flips slower than this aren't worth a visual: shuffling on the spot at walking
## pace would otherwise squash him on every tap of the stick.
@export var turn_min_speed := 55.0
## Lockout after a turn squash. _apply_run's reversal branch is true for every
## frame the old velocity survives — three or four of them at ground_decel — so
## without this the tween restarts each frame and the squash never gets past its
## first frame.
@export var turn_cooldown_time := 0.25
## How far the sprite stretches ALONG the dash on the frame it starts (0 = off).
## Applied to whichever axis the dash is mostly on; a pure diagonal gets none,
## because there is no axis to stretch a square scale along.
@export var dash_stretch := 0.3
## ...and how much it compresses along that same axis when the dash drops to
## dash_end_speed. The dash used to get afterimages and nothing else, so it began
## and ended with no weight anywhere on the sprite.
@export var dash_end_squash := 0.18

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

## Soft puffs kicked up under his feet — three sizes, 8px cells, drawn by
## tools/gen_dust.py. Deliberately its own sheet and not SHARD_SHEET tinted: a
## shard is hard-edged debris, and a landing that throws those looks like a small
## death rather than like dust.
const DUST_SHEET := preload("res://assets/effects/dust_puff.png")
const DUST_CELL := 8.0
const DUST_SHAPES := 3

## Reused rather than a sheet of its own — a mushroom-power sparkle is the
## same "soft additive glow" LemonGlowLight and DarkThought's halo already
## use this texture for, just at a tiny scale and tinted warm.
const SPARKLE_TEXTURE := preload("res://assets/light_radial.png")

@export_group("Dust")
@export var dust_enabled := true
## Puffs a full-strength burst throws. Scaled down for gentler ones.
@export var dust_count := 5
## How fast a puff drifts away from his feet, px/s.
@export var dust_speed := 26.0
## Half-width of the spray around its axis, in degrees.
@export var dust_spread_degrees := 32.0
## How long one puff lives. Short — dust that hangs around reads as smoke.
@export var dust_lifetime := 0.32
## Size of a puff as a multiple of the 8px art, at spawn. They GROW as they fade,
## which is what makes them read as dispersing rather than as shrinking sparks.
@export var dust_scale := 0.38
@export var dust_growth := 1.6
## Pale warm grey. Alpha here is the starting opacity — office dust should be
## barely there, not a white puff.
@export var dust_color := Color(0.85, 0.83, 0.78, 0.45)
## How far below his origin his feet are (8x12 hitbox, so 6px).
@export var dust_foot_offset := 6.0
## Fraction of a full burst a jump throws. A takeoff disturbs less than a landing.
@export_range(0.0, 2.0) var dust_jump_strength := 0.6
## ...and a dash, which scuffs off in one direction rather than puffing outward.
@export_range(0.0, 2.0) var dust_dash_strength := 0.85

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
## How far the camera dips on the frame he dies, in pixels (a smooth dip and
## spring-back, not random jitter). Death is the ONLY movement beat that moves
## the camera — jumps and landings deliberately do not, so a shaking screen
## always means something happened TO him.
@export var death_shake_strength := 0.9
@export var death_shake_time := 0.18

@export_group("Mushroom Sparkle")
## While a mushroom's power is running, spawn one twinkle at roughly this
## interval, in seconds.
@export var sparkle_interval := 0.12
## Warm gold-white, additive — reads as a shimmer rather than a solid sprite.
## Alpha here is the starting opacity.
@export var sparkle_color := Color(1.0, 0.95, 0.65, 0.9)
## How far from his centre a twinkle can appear, px.
@export var sparkle_radius := 9.0
## How big a twinkle starts, as a scale of the (reused) radial light texture.
@export var sparkle_scale := 0.09
## How long one twinkle takes to grow and fade.
@export var sparkle_life := 0.4
## In the power's own flicker window (Player.mushroom_power_flicker_time),
## spawn at this fraction of the normal rate — SPARSER rather than dimmer,
## the same "still unmistakably there, but visibly running out" cue
## lemon_glow_flicker_speed gives with a blink instead.
@export_range(0.0, 1.0) var sparkle_warning_rate := 0.35

@export_group("Camera")
## Landings slower than this barely squash at all.
@export var landing_squash_min_speed := 160.0
## Landings at or above this speed give the FULL squash.
@export var landing_squash_max_speed := 260.0
## True "everything pauses" hitstop on dash start. Real seconds, not scaled.
@export var hitstop_time := 0.04
## How slow time gets during hitstop. Not exactly 0 to dodge zero-delta edge
## cases elsewhere in the engine.
@export_range(0.0, 1.0) var hitstop_time_scale := 0.05
## How often the sustained tremor (set_tremor) picks a new point to drift to, in
## seconds. Short enough to read as a rattle; lengthen it and it becomes a sway.
@export var tremor_step := 0.05

@onready var _player: Node2D = get_parent()
@onready var _sprite_squash: Node2D = _player.get_node("SpriteSquash")
@onready var _visual: AnimatedSprite2D = _player.get_node("SpriteSquash/Visual")
@onready var _camera: Camera2D = _player.get_node("Camera2D")

var _squash_tween: Tween
var _trail_timer := 0.0
var _turn_cooldown := 0.0
var _sparkle_timer := 0.0
var _sparkle_material: CanvasItemMaterial

# The camera has TWO independent shake channels, summed into Camera2D.offset once
# a frame by _process. Nothing else in the project writes that offset.
#
# They are separate on purpose. shake() and rumble() share one tween and each new
# call kills the last — right for one-off knocks (the second knock IS the current
# state of the camera), useless for a background that has to keep running
# underneath them. CollapseAmbience holds the tremor channel at a level for the
# whole time he is in a room, so the building groaning can neither delete nor be
# deleted by the jolt of a room actually giving way (Act1Beats._play_collapse).
var _shake_tween: Tween
## The tween channel: one-off knocks and runs. Written by shake()/rumble() only.
var _shake_offset := Vector2.ZERO
## The tremor channel: a level, held until it is changed. See set_tremor().
var _tremor_amplitude := 0.0
var _tremor_offset := Vector2.ZERO
var _tremor_from := Vector2.ZERO
var _tremor_to := Vector2.ZERO
var _tremor_phase := 1.0


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
		# The settle overshoots and comes back, rather than easing flat onto 1.0.
		# The landing already did this (TRANS_BACK) and the jump did not, so the
		# same sprite sprang on the way down and deflated on the way up.
		[Vector2.ONE, squash_ease_time, Tween.TRANS_BACK],
	], Tween.EASE_OUT, Tween.TRANS_QUAD)
	_spawn_dust(Vector2.ZERO, dust_jump_strength)


## Call right after landing is detected, passing the vertical speed the
## player was falling at the instant of impact (velocity.y BEFORE
## move_and_slide resolves the collision). Harder falls squash more; soft
## landings barely register.
##
## The impact is carried entirely by the SPRITE, never the camera. A platformer
## this jump-dense puts a landing on screen every second or so, and a camera
## that answers each one leaves the view permanently unsettled — the shake stops
## reading as impact and starts reading as noise. Squash says the same thing
## without moving the frame the player is aiming with.
func on_land(impact_speed: float) -> void:
	var t := clampf(
		(impact_speed - landing_squash_min_speed)
			/ maxf(landing_squash_max_speed - landing_squash_min_speed, 1.0),
		0.0, 1.0)
	if t <= 0.0:
		return  # too soft a landing to bother with
	var squash := Vector2.ONE.lerp(land_squash_scale, t)
	_play_squash_sequence([
		[squash, 0.03],
		[Vector2.ONE, squash_ease_time],
	], Tween.EASE_OUT, Tween.TRANS_BACK)
	# Same `t`: the puff is as big as the impact was, which is what ties the dust
	# to the fall rather than making every landing throw the same cloud.
	_spawn_dust(Vector2.ZERO, t)


## Call when he flips direction on the ground at speed, passing the speed he was
## still travelling at. A lean into the turn — the only bit of the run cycle with
## any weight in it, since a reversal is the one ground move that isn't a
## constant-velocity slide.
func on_turn(speed: float) -> void:
	if speed < turn_min_speed or _turn_cooldown > 0.0:
		return
	_turn_cooldown = turn_cooldown_time
	_play_squash_sequence([
		[turn_squash_scale, turn_squash_time],
		[Vector2.ONE, squash_ease_time, Tween.TRANS_BACK],
	], Tween.EASE_OUT, Tween.TRANS_QUAD)


## Keys are [scale, seconds] or [scale, seconds, trans], the third entry
## overriding `trans_mode` for that step alone — which is how one sequence can
## stretch smoothly and then settle with a spring.
func _play_squash_sequence(keys: Array, ease_mode: Tween.EaseType, trans_mode: Tween.TransitionType) -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_sprite_squash.scale = Vector2.ONE
	_squash_tween = create_tween()
	for key: Array in keys:
		var trans: Tween.TransitionType = key[2] if key.size() > 2 else trans_mode
		_squash_tween.tween_property(_sprite_squash, "scale", key[0], key[1]) \
			.set_ease(ease_mode).set_trans(trans)


# --------------------------------------------------------------- dashing ----

## Call once, the moment a dash successfully starts.
func on_dash_start(dash_dir: Vector2) -> void:
	_trail_timer = 0.0  # spawn the first afterimage immediately
	hitstop(hitstop_time)
	_play_squash_sequence([
		[_along(dash_dir, dash_stretch), 0.04],
		[Vector2.ONE, squash_ease_time * 1.4],
	], Tween.EASE_OUT, Tween.TRANS_QUAD)
	# Scuffed off BEHIND him, unlike the jump and landing puffs, which go outward
	# from under his feet. A dash is a push against something.
	_spawn_dust(-dash_dir, dust_dash_strength)


## Call when the dash drops to dash_end_speed. The momentum carry-over is still
## running, so this is the sprite catching up rather than a stop.
func on_dash_end(dash_dir: Vector2) -> void:
	_play_squash_sequence([
		[_along(dash_dir, -dash_end_squash), 0.05],
		[Vector2.ONE, squash_ease_time, Tween.TRANS_BACK],
	], Tween.EASE_OUT, Tween.TRANS_QUAD)


## A scale stretched by `amount` along whichever axis `dir` mostly points down,
## and squeezed by the same on the other — the volume-preserving read that makes
## squash & stretch look like a body rather than a resize.
##
## A pure diagonal cancels to Vector2.ONE, which is correct and not a gap: an
## axis-aligned scale has no way to stretch along 45 degrees, and faking it by
## picking one axis would make the same dash look different left and up.
func _along(dir: Vector2, amount: float) -> Vector2:
	var axis := Vector2(absf(dir.x), absf(dir.y))
	return Vector2.ONE + (axis - Vector2(axis.y, axis.x)) * amount


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
	_camera_shake(death_shake_strength, death_shake_time)
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


# ----------------------------------------------------------------- dust ----

## A puff at his feet. `direction` is the axis it sprays along; Vector2.ZERO
## means "outward from under him", which is what a takeoff and a landing both
## look like. `strength` (0-1ish) scales how many puffs and how far they go, so
## the same call covers a scuff and a heavy landing.
##
## Hand-tweened sprites rather than a CPUParticles2D node, for the same two
## reasons the dash trail and the death burst are: they have to be parented to
## the ROOM (levels live in Screen's sub-viewport, so current_scene is the UI
## surface) and pinned into the playable z band, and a particle node carried on
## the player would drag its live particles along with him as he moves.
func _spawn_dust(direction: Vector2, strength: float) -> void:
	if not dust_enabled or strength <= 0.0:
		return
	var world := _player.get_parent()
	if world == null:
		return
	var at := _player.global_position + Vector2(0.0, dust_foot_offset)
	var count := maxi(int(round(dust_count * minf(strength, 1.0))), 1)
	for i in count:
		var away := direction
		if away == Vector2.ZERO:
			# Alternating sideways with a slight lift. A puff under his feet has
			# to go somewhere, and sideways is the only direction that reads as
			# air pushed out from under him — straight up reads as steam.
			away = Vector2(1.0 if i % 2 == 0 else -1.0, -0.35)
		var angle := away.angle() \
			+ randf_range(-1.0, 1.0) * deg_to_rad(dust_spread_degrees)
		_spawn_puff(world, at, Vector2.RIGHT.rotated(angle), strength, i)


func _spawn_puff(world: Node, at: Vector2, away: Vector2, strength: float, index: int) -> void:
	var puff := Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = DUST_SHEET
	# Cycled, not random: three random picks from three shapes reliably comes up
	# all-the-same often enough to notice, and the point of the sheet is that one
	# puff isn't three copies of a sprite.
	tex.region = Rect2((index % DUST_SHAPES) * DUST_CELL, 0.0, DUST_CELL, DUST_CELL)
	puff.texture = tex
	puff.modulate = dust_color
	puff.global_position = at
	puff.scale = Vector2.ONE * dust_scale
	puff.z_as_relative = false
	puff.z_index = 0
	world.add_child(puff)
	# Behind him, unlike the afterimages: dust he kicked up should not be drawn
	# over his boots.
	world.move_child(puff, maxi(_player.get_index() - 1, 0))

	var life := dust_lifetime * randf_range(0.8, 1.15)
	var to := at + away * dust_speed * life * (0.6 + strength * 0.6)
	var t := puff.create_tween().set_parallel()
	t.tween_property(puff, "global_position", to, life) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(puff, "scale", Vector2.ONE * dust_scale * dust_growth, life) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(puff, "modulate:a", 0.0, life) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(puff.queue_free)


# ------------------------------------------------------ mushroom sparkle ----

## Call every physics frame while Player._mushroom_power_timer is running.
## `warning` thins the spawn rate rather than dimming it — see
## sparkle_warning_rate — as the power's own countdown nears the end.
func mushroom_sparkle_tick(delta: float, warning: bool) -> void:
	_sparkle_timer -= delta
	if _sparkle_timer > 0.0:
		return
	_sparkle_timer = sparkle_interval / maxf(sparkle_warning_rate if warning else 1.0, 0.01)
	_spawn_sparkle()


## A single twinkle near him, grown and faded out in place. Parented to the
## ROOM and pinned into the playable z band for the same two reasons dust and
## the dash trail are (see _spawn_dust) — levels live in Screen's sub-viewport,
## so current_scene is the wrong surface and the wrong scale, and a sprite
## carried as the player's own child would drag it along mid-fade instead of
## letting it hang in place where it appeared.
func _spawn_sparkle() -> void:
	var world := _player.get_parent()
	if world == null:
		return
	if _sparkle_material == null:
		_sparkle_material = CanvasItemMaterial.new()
		_sparkle_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_sparkle_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var img := Sprite2D.new()
	img.texture = SPARKLE_TEXTURE
	img.material = _sparkle_material
	img.modulate = sparkle_color
	img.global_position = _player.global_position + Vector2(
		randf_range(-sparkle_radius, sparkle_radius),
		randf_range(-sparkle_radius, sparkle_radius))
	img.scale = Vector2.ONE * sparkle_scale
	img.z_as_relative = false
	img.z_index = 0
	world.add_child(img)
	world.move_child(img, _player.get_index())

	var t := img.create_tween().set_parallel()
	t.tween_property(img, "scale", Vector2.ONE * sparkle_scale * 1.6, sparkle_life) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(img, "modulate:a", 0.0, sparkle_life) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(img.queue_free)


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


## Bounce the camera for a single hard jolt — a chunk of ceiling coming down
## nearby, a room giving way. Ordinary movement never calls this: routine jumps
## and landings leave the camera alone on purpose, so a knock stays an event.
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
	_shake_offset = Vector2.ZERO
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
		_shake_tween.tween_property(self, "_shake_offset", to, STEP) \
			.set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(self, "_shake_offset", Vector2.ZERO, STEP * 2.0)


## Hold the camera at a sustained rattle of `amplitude` px until it is changed
## again — the building coming down around him for as long as he is in the room.
## 0 turns it off (it eases home over one tremor_step rather than snapping).
##
## Not rumble() repeated. rumble is a run with an END, and it owns the tween that
## shake() also owns; this is a LEVEL, driven per frame by whatever is describing
## the room (CollapseAmbience), and it deliberately shares nothing with the two
## above so a knock can land on top of a tremor without either one vanishing.
func set_tremor(amplitude: float) -> void:
	_tremor_amplitude = maxf(amplitude, 0.0)


## Both channels, summed and written once. The only place Camera2D.offset is set.
func _process(delta: float) -> void:
	_turn_cooldown = maxf(_turn_cooldown - delta, 0.0)
	_advance_tremor(delta)
	var want := _shake_offset + _tremor_offset
	if _camera.offset != want:
		_camera.offset = want


## Step the tremor toward a fresh random point every tremor_step.
##
## Deliberately not new noise every frame: at 320x180 with pixel snapping, a
## camera re-rolled at 60Hz strobes rather than shakes. Stepping and easing
## between points is the same trick rumble() plays with its 0.045s tween steps.
func _advance_tremor(delta: float) -> void:
	if _tremor_amplitude <= 0.0 and _tremor_offset.is_zero_approx():
		_tremor_offset = Vector2.ZERO
		return
	_tremor_phase += delta / maxf(tremor_step, 0.001)
	if _tremor_phase >= 1.0:
		_tremor_phase = 0.0
		_tremor_from = _tremor_to
		# A point anywhere INSIDE the amplitude, not on a ring — the camera has to
		# pass through the middle sometimes, or the rattle reads as an orbit.
		_tremor_to = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* _tremor_amplitude
	_tremor_offset = _tremor_from.lerp(_tremor_to, smoothstep(0.0, 1.0, _tremor_phase))


## Celeste-style landing bounce: not random jitter — a single smooth dip
## downward (the screen "sags" under the impact) that springs back to
## rest with a touch of overshoot. Reads as weighty rather than noisy.
func _camera_shake(strength: float, duration: float) -> void:
	if strength <= 0.0:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_offset = Vector2.ZERO
	_shake_tween = create_tween()
	# The whole Vector2 rather than its `y` sub-path: x stays 0 throughout, so
	# this is the identical dip, and tweening a plain script variable by sub-path
	# is a subtlety this does not need to depend on.
	_shake_tween.tween_property(self, "_shake_offset", Vector2(0.0, strength),
			duration * 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(self, "_shake_offset", Vector2.ZERO,
			duration * 0.75) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
