@tool
class_name DarkshangVisual
extends Node2D
## What Darkshang looks like: Hooshang's shadow self, a chunky black silhouette
## with two cold slits for eyes, drawn in front of the entire world.
##
## This node is ONLY the picture. It has no collision shape, no body, no idea
## where the level is or what a wall is — the chase logic tells it three things
## and it plays them:
##
##     set_motion(state, velocity)      what he is doing and which way
##     set_inside_geometry(inside)      whether he is currently inside a solid
##     ingest(victim, duration)         eat that; awaitable, takes `duration`
##
## That one-way flow is the same rule Juice follows for the player: delete this
## node and the chase still runs, it just becomes invisible. Nothing here reads
## the chase's state, and nothing here decides timing — `ingest` is paced by its
## argument so the death's LENGTH stays a gameplay number, not an art one.
##
## Art: assets/characters/darkshang/darkshang.png, 4 columns x 3 rows of 32x48
## frames, one row per animation. Redraw it with tools/gen_darkshang.py. The
## SpriteFrames are built here in code rather than kept as a .tres, so the row
## map lives in exactly one place next to the generator's and cannot silently
## drift from the sheet it slices.
##
## The origin is at his FEET, centred left to right — put this node where he
## stands. Art nudges go through `art_offset`, never by moving the child sprite.
##
## He is NEVER occluded. The scene sets `z_as_relative = false` and `z_index =
## 60`, which is far above every band the world uses (README "z_index (world
## depth bands)": -1 background, 0 the playable area, 1 the foreground layer the
## player walks behind). A thing that is coming for you through the walls cannot
## be allowed to disappear behind a filing cabinet, and 60 leaves room for
## anything else that later wants to sit over the foreground without a fight.
## UI is a different render surface entirely, so no z_index here can reach it.
##
## He faces RIGHT in the sheet and is flipped for the other way, so every frame
## is drawn once and the eyes can never end up on the back of his head.
##
## @tool, so everything has to survive being poked before _ready: all three
## calls above guard their nodes and are safe to repeat.

const SHEET := preload("res://assets/characters/darkshang/darkshang.png")
const FRAME := Vector2i(32, 48)

## Motion states. Deliberately plain ints rather than a reference to the chase
## script's enum: the two are edited by different hands, and the art must keep
## parsing while the logic is mid-rewrite. Same reason ConveyorBeltVisual keeps
## its own LEFT/RIGHT.
const STATE_IDLE := 0
const STATE_MOVE := 1
const STATE_SURGE := 2

## state -> animation, animation -> (sheet row, frames, fps). The sheet's rows
## are: 0 idle (eyeless, breathing), 1 move (eyes open), 2 surge (the lunge,
## with motion arcs).
const ANIM := {STATE_IDLE: &"idle", STATE_MOVE: &"move", STATE_SURGE: &"surge"}
const ROWS := {&"idle": 0, &"move": 1, &"surge": 2}
const FRAMES_PER_ROW := 4
const FPS := {&"idle": 6.0, &"move": 10.0, &"surge": 14.0}

@export_group("Placement")
## Nudge the whole figure without moving the node the chase logic drives. Whole
## pixels only — a half-pixel here is what makes crisp pixel art shimmer.
@export var art_offset := Vector2.ZERO:
	set(value):
		art_offset = value.round()
		if _find_nodes():
			_body.position = art_offset

@export_group("Motion")
## Below this much horizontal speed he keeps facing the way he already was.
## Without it he flickers left/right every frame he is nearly still.
@export var face_deadzone := 6.0
## The speed at which the walk cycle plays at its drawn rate; faster than this
## and the legs speed up with him, so a sprint never looks like a moonwalk.
@export var walk_reference_speed := 55.0

@export_group("Pass-through swell")
## How much bigger he gets while inside a wall or floor. Passing through solid
## matter is supposed to look deliberate and wrong, not like a clipping bug —
## the swell is the tell that he MEANT to be in there.
##
## PURELY VISUAL. This node owns no collision shape and never scales one, and
## nothing that hits the player may ever be parented under `Body` — the hitbox
## belongs on the chase node, where it stays one fixed size no matter what the
## art is doing. A hurtbox that inflated with this would make walls into extra
## reach, which is a hazard the player cannot see coming.
@export var swell_scale := 1.16
## Time to reach the swell on the way in — short, so the crossing has a snap.
@export var swell_in_time := 0.08
## Time to settle back once he is clear. Longer than the way in, so he deflates
## rather than snapping back.
@export var swell_out_time := 0.26
## How dark the subtractive pool around him gets while he is inside geometry.
@export var crossing_energy := 0.3
## The spike on the frame he crosses a surface, on top of the above.
@export var crossing_flash := 0.6
## How long that spike takes to fall back to `crossing_energy` (or to nothing).
@export var crossing_flash_time := 0.22

@export_group("Ingestion")
## What Hooshang is tinted as he is drawn in: he goes shadow before he goes
## away, so the last thing you see is him becoming part of Darkshang.
@export var ingest_victim_tint := Color(0.05, 0.05, 0.07, 1.0)
## How much of him is left at the moment he disappears. Not zero — a victim
## shrunk to nothing pops out of existence a frame early.
@export var ingest_victim_scale := 0.08
## How far he swells on the swallow. Bigger than the pass-through swell: this is
## the one moment the shape should look like it gained something.
@export var ingest_gulp_scale := 1.38
## The cold flare through his rim and eyes on the swallow. Kept low: this is a
## multiply over a near-black fill, and pushed hard it turns the whole shadow
## into a glowing blue balloon — the flare belongs on the rim, not the mass.
@export var ingest_flash_tint := Color(1.2, 1.28, 1.45, 1.0)

var _body: Node2D
var _sprite: AnimatedSprite2D
var _void: PointLight2D
var _nodes_found := false

var _facing := 1
var _anim := &"idle"
var _inside := false

var _swell_tween: Tween
var _void_tween: Tween
var _ingest_tween: Tween

## What the victim looked like before we started eating it, so a death that is
## interrupted (respawn, scene change, this node freed) cannot leave Hooshang
## permanently 8% tall and black.
var _victim: Node2D
var _victim_scale := Vector2.ONE
var _victim_modulate := Color.WHITE
var _victim_rotation := 0.0


func _ready() -> void:
	if _find_nodes():
		_body.position = art_offset
		_apply_anim(&"idle")


func _exit_tree() -> void:
	_restore_victim()


# ------------------------------------------------------------------- API ----

## What he is doing, and how fast he is going while doing it.
## `state` is 0 IDLE / 1 MOVE / 2 SURGE; `velocity` is px/sec in world space.
## Safe to call every physics frame — it only touches the sprite when something
## actually changed.
func set_motion(state: int, velocity: Vector2) -> void:
	if not _find_nodes():
		return
	# Facing follows real movement, never the state: a surge that has already
	# passed the player should keep facing the way it is travelling.
	if absf(velocity.x) >= face_deadzone:
		_facing = 1 if velocity.x > 0.0 else -1
	_sprite.flip_h = _facing < 0

	var anim: StringName = ANIM.get(state, &"idle")
	if anim != _anim:
		_apply_anim(anim)
	# The walk speeds up with him; idle and surge play at their drawn rate,
	# because a breath that races and a lunge that stutters both read as broken.
	if anim == &"move":
		_sprite.speed_scale = clampf(
			velocity.length() / maxf(walk_reference_speed, 1.0), 0.55, 2.2)
	else:
		_sprite.speed_scale = 1.0


## True on the frame he enters a wall/floor, false once he is clear of it. The
## chase logic decides what "inside" means; this only draws the consequence.
##
## Again: the swell is art. Nothing in this file touches a collision shape, and
## nothing that can hurt the player should ever be parented under `Body`.
func set_inside_geometry(inside: bool) -> void:
	if not _find_nodes():
		return
	if inside == _inside:
		return  # idempotent: this gets called from a physics loop
	_inside = inside
	_tween_swell(swell_scale if inside else 1.0,
		swell_in_time if inside else swell_out_time,
		Tween.TRANS_BACK if inside else Tween.TRANS_ELASTIC)
	# Both crossings flash — going in and coming out are equally the moment
	# matter gives way — and the pool only stays lit while he is submerged.
	_flash_void(crossing_energy if inside else 0.0)


## Eat `victim` over `duration` seconds. Awaitable:
##
##     await darkshang_visual.ingest(player, 1.0)
##
## He is the active party. The victim is YANKED in and swallowed — one decisive
## motion, not a fade — because at a second long, a sequence of gentle stages
## reads as a loading screen. Order: he inhales (a beat of anticipation), the
## victim is pulled into his middle while going to shadow, he gulps, he settles.
##
## The victim's scale/rotation/modulate are restored when it is over (and if
## this node is freed mid-swallow), so respawning gets an un-mangled player back.
## Its POSITION is left where the swallow put it — where the player respawns is
## the game's decision, not this animation's.
func ingest(victim: Node2D, duration: float) -> void:
	if not _find_nodes():
		return
	# Re-entrant: a second death mid-swallow abandons the first cleanly rather
	# than running two tweens over the same nodes.
	_restore_victim()
	if _ingest_tween and _ingest_tween.is_valid():
		_ingest_tween.kill()

	var total := maxf(duration, 0.05)
	var inhale := total * 0.16
	var pull := total * 0.46
	var gulp := total * 0.16
	var settle := total - inhale - pull - gulp

	if is_instance_valid(victim):
		_victim = victim
		_victim_scale = victim.scale
		_victim_modulate = victim.modulate
		_victim_rotation = victim.rotation

	if _swell_tween and _swell_tween.is_valid():
		_swell_tween.kill()

	# Four groups, each one played to its end before the next starts. Everything
	# inside a group is simultaneous (set_parallel), and `chain()` opens each
	# new group — WITHOUT that chain the first tweener of a group joins the
	# previous group instead of following it, which quietly ate a third of the
	# running time and made `duration` a lie.
	_ingest_tween = create_tween()
	_ingest_tween.set_parallel()
	# 1. Inhale. He compresses — the pull-back that says the next thing is fast.
	_ingest_tween.chain().tween_property(_body, "scale", Vector2(0.9, 1.06), inhale) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 2. The yank, all at once. TRANS_BACK/EASE_IN drifts the victim outward for
	# a moment and then takes him, which is what makes it read as Darkshang
	# pulling rather than Hooshang walking in.
	if is_instance_valid(victim):
		var mouth := _mouth_position()
		var spin := victim.rotation + (0.9 if _facing > 0 else -0.9)
		_ingest_tween.chain().tween_property(victim, "global_position", mouth, pull) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_ingest_tween.tween_property(victim, "scale",
			_victim_scale * ingest_victim_scale, pull) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ingest_tween.tween_property(victim, "modulate", ingest_victim_tint,
			pull * 0.7).set_trans(Tween.TRANS_SINE)
		_ingest_tween.tween_property(victim, "rotation", spin, pull)
	else:
		_ingest_tween.chain().tween_interval(pull)
	# 3. The gulp: one hard swell with the flare through it.
	_ingest_tween.chain().tween_property(_body, "scale",
		Vector2.ONE * ingest_gulp_scale, gulp) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ingest_tween.tween_property(_sprite, "modulate", ingest_flash_tint,
		gulp * 0.5).set_trans(Tween.TRANS_SINE)
	# 4. Settle. Elastic, so the mass keeps moving after the shape stops.
	_ingest_tween.chain().tween_property(_body, "scale",
		Vector2.ONE * (swell_scale if _inside else 1.0), maxf(settle, 0.05)) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_ingest_tween.tween_property(_sprite, "modulate", Color.WHITE,
		maxf(settle, 0.05)).set_trans(Tween.TRANS_SINE)

	_flash_void(crossing_energy if _inside else 0.0)
	await _ingest_tween.finished
	_restore_victim()


# --------------------------------------------------------------- internals ----

## Fetches (and caches) the three child nodes. Returns false if the scene is not
## built yet, which is the guard that lets all three public calls happen before
## _ready without a null crash.
func _find_nodes() -> bool:
	if _nodes_found and is_instance_valid(_body):
		return true
	var body := get_node_or_null("Body") as Node2D
	var sprite := get_node_or_null("Body/Sprite") as AnimatedSprite2D
	var void_light := get_node_or_null("Void") as PointLight2D
	# All three or nothing. Caching a half-built set would make the NEXT call
	# take the fast path above and then dereference a null sprite.
	if body == null or sprite == null or void_light == null:
		return false
	_body = body
	_sprite = sprite
	_void = void_light
	_nodes_found = true
	if _sprite.sprite_frames == null:
		_sprite.sprite_frames = _build_frames()
	return true


## Slices the sheet into one animation per row. Built fresh per instance rather
## than shared: a handful of AtlasTextures is nothing, and a shared SpriteFrames
## that one instance re-tuned would re-tune every Darkshang on screen.
func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: StringName in ROWS:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, FPS[anim])
		frames.set_animation_loop(anim, true)
		for col in FRAMES_PER_ROW:
			var tex := AtlasTexture.new()
			tex.atlas = SHEET
			tex.region = Rect2(col * FRAME.x, int(ROWS[anim]) * FRAME.y,
				FRAME.x, FRAME.y)
			frames.add_frame(anim, tex)
	return frames


func _apply_anim(anim: StringName) -> void:
	_anim = anim
	_sprite.play(anim)


## Where a swallowed thing ends up: his middle, not his feet, and not the origin
## the chase node is positioned by.
func _mouth_position() -> Vector2:
	return _sprite.global_position + Vector2(0.0, -FRAME.y * 0.45) * global_scale.y


func _tween_swell(to: float, time: float, trans: Tween.TransitionType) -> void:
	if _ingest_tween and _ingest_tween.is_valid():
		return  # a swallow owns the shape until it is finished
	if _swell_tween and _swell_tween.is_valid():
		_swell_tween.kill()
	_swell_tween = create_tween()
	_swell_tween.tween_property(_body, "scale", Vector2.ONE * to, maxf(time, 0.01)) \
		.set_trans(trans).set_ease(Tween.EASE_OUT)


## The dark pool at a crossing: a SUBTRACTIVE light, so surfaces he passes
## through lose their light for a moment instead of gaining a glow. A shadow
## that lit things up would be a contradiction the player can see.
##
## The light's colour in the scene is deliberately NEUTRAL grey. Subtracting a
## colour leaves its opposite behind: the first pass used a cold blue pool and
## the room around him came back WARM — the one hue this character may never
## wear, and the one the note pickups own. Neutral takes light away without
## taking a side.
func _flash_void(hold: float) -> void:
	if _void_tween and _void_tween.is_valid():
		_void_tween.kill()
	_void.enabled = true
	_void.energy = crossing_flash + hold
	_void_tween = create_tween()
	_void_tween.tween_property(_void, "energy", hold, crossing_flash_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hold <= 0.0:
		# Switch it off at the end rather than leaving a zero-energy light in
		# the room for the renderer to keep considering.
		_void_tween.tween_callback(func() -> void: _void.enabled = false)


func _restore_victim() -> void:
	if _victim == null:
		return
	if is_instance_valid(_victim):
		_victim.scale = _victim_scale
		_victim.modulate = _victim_modulate
		_victim.rotation = _victim_rotation
	_victim = null
