extends CharacterBody2D

# ─────────────────────────────────────────────────────────────────────────────
#  Celeste-accurate physics  (all values in px / s or px / s²)
#
#  Reference: Celeste runs at 320×180, 8px tiles.
#  Our game:  640×360, 32px tiles  (4× tile scale, 2× viewport).
#  Constants below are tuned so the jump arc, speed, and feel are identical
#  to Celeste when scaled for our larger grid.
# ─────────────────────────────────────────────────────────────────────────────

# Horizontal
const MAX_SPEED         := 330.0   # px/s  (Celeste: ~90 × 3.7)
const ACCELERATION      := 6500.0  # ground: reach max speed in ≈ 2 frames
const FRICTION          := 6500.0  # ground: full stop in ≈ 2 frames
const AIR_ACCEL         := 3200.0  # air: good control, momentum preserved
const AIR_FRICTION      := 420.0   # air: almost no braking — carry momentum

# Vertical
const GRAVITY           := 2200.0  # px/s²  rising gravity
const FALL_GRAVITY      := 3100.0  # px/s²  falling gravity (asymmetric — Celeste snap)
const FAST_FALL_GRAVITY := 4200.0  # px/s²  hold ↓ in air
const MAX_FALL          := 600.0   # terminal velocity (normal)
const FAST_FALL_MAX     := 800.0   # terminal velocity (fast-fall)

# Jump
const JUMP_VELOCITY     := -720.0  # px/s   ≈ 3.5 tiles high at GRAVITY above
const JUMP_CUT_MULT     := 0.25    # 0.25 → tap gives ≈ 25 px hop; hold = full arc
const COYOTE_TIME       := 0.10    # s  (Celeste: 6 frames)
const JUMP_BUFFER_TIME  := 0.10    # s  (Celeste: 6 frames)

# Wall
const WALL_SLIDE_MAX    := 40.0    # px/s  barely creep down the wall
const WALL_JUMP_X       := 300.0
const WALL_JUMP_Y       := -660.0

# Dash
const DASH_SPEED        := 820.0   # px/s
const DASH_DURATION     := 0.15    # s
const DASH_COOLDOWN     := 0.30    # s
const FREEZE_SCALE      := 0.05    # time-scale during hitstop
const FREEZE_DURATION   := 0.04    # s  of real-time freeze

# Sprite sheet  —  IDLE.png 960×96 (10 cols) · RUN.png 1536×96 (16 cols)
const IDLE_FRAMES       := 10
const IDLE_FPS          := 10.0
const RUN_FRAMES        := 16
const RUN_FPS           := 14.0
## 96 px sheet → 64 px on screen (⅔ scale, clearly visible on 640×360)
const SPRITE_SCALE      := Vector2(2.0 / 3.0, 2.0 / 3.0)

# Trail
const TRAIL_LEN         := 16
const TRAIL_HEAD        := Color(0.80, 0.35, 1.00, 0.90)
const TRAIL_TAIL        := Color(0.80, 0.35, 1.00, 0.00)

# Paper trail  (Level 4 mechanic — safe to leave in for other levels)
const PAPER_SCENE_PATH  := "res://scenes/paper_platform.tscn"
const PAPER_INTERVAL    := 0.045  # s — one paper platform every N seconds of dash

# Dash colour indicator
const COLOR_READY       := Color(1.00, 1.00, 1.00, 1.00)  # normal — dash available
const COLOR_SPENT       := Color(0.55, 0.15, 0.15, 1.00)  # dark red — dash used up

# ─── Timers ───────────────────────────────────────────────────────────────────
var _coyote_t   := 0.0
var _buffer_t   := 0.0
var _dash_cd_t  := 0.0
var _dash_t     := 0.0

# ─── Animation state ──────────────────────────────────────────────────────────
var _anim_t     := 0.0
var _anim_frame := 0
var _anim_name  := "idle"
var _idle_tex   : Texture2D = null
var _run_tex    : Texture2D = null

# ─── Player state ─────────────────────────────────────────────────────────────
var _was_on_floor   := false
var _facing         := 1
var _is_dashing     := false
var _can_dash       := true
var _dash_dir       := Vector2.ZERO
var _trail_pts      : Array[Vector2] = []

# Paper trail state
var _paper_scene    : PackedScene = null
var _paper_t        : float = 0.0
var _paper_enabled  : bool  = false   # true only after collecting a Document Floater

# External force accumulator (wind shafts, shredder vacuum, etc.)
var _external_force : Vector2 = Vector2.ZERO

@onready var _sprite : Sprite2D = $Sprite2D
@onready var _trail  : Line2D   = $DashTrail


# ═══ Init ════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_textures()
	_setup_trail()
	_paper_scene = load(PAPER_SCENE_PATH)   # null if scene doesn't exist yet


func _load_textures() -> void:
	_idle_tex = load("res://assets/sprites/IDLE.png")
	_run_tex  = load("res://assets/sprites/RUN.png")
	if _idle_tex == null or _run_tex == null:
		push_error("player.gd: sprite sheets not found in res://assets/sprites/")
		return
	_sprite.texture  = _idle_tex
	_sprite.hframes  = IDLE_FRAMES
	_sprite.vframes  = 1
	_sprite.frame    = 0
	_sprite.scale    = SPRITE_SCALE
	_sprite.centered = true


func _setup_trail() -> void:
	_trail.top_level      = true
	_trail.width          = 8.0
	_trail.joint_mode     = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode   = Line2D.LINE_CAP_ROUND
	var g := Gradient.new()
	g.colors     = PackedColorArray([TRAIL_HEAD, TRAIL_TAIL])
	_trail.gradient = g
	_trail.visible  = false


# ═══ Main loop ════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if _is_dashing:
		_tick_dash(delta)
		return

	_tick_timers(delta)
	_apply_gravity(delta)
	_handle_horizontal(delta)
	_handle_jump_and_dash()
	# Apply and clear any external forces (wind, vacuum) accumulated this frame.
	if _external_force != Vector2.ZERO:
		velocity += _external_force
		_external_force = Vector2.ZERO
	move_and_slide()
	_post_move()
	_animate(delta)
	_decay_trail()


# ═══ Gravity ══════════════════════════════════════════════════════════════════

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
		return

	if _wall_sliding():
		# Creep down slowly — feels like friction on the wall.
		velocity.y = minf(velocity.y + GRAVITY * delta * 0.25, WALL_SLIDE_MAX)
		return

	# Asymmetric gravity: fall faster than you rise (Celeste snap feel).
	# Fast-fall (hold ↓) adds even more.
	var fast_fall := Input.is_action_pressed("move_down")
	var grav: float
	var max_v: float
	if fast_fall:
		grav  = FAST_FALL_GRAVITY
		max_v = FAST_FALL_MAX
	elif velocity.y > 0.0:          # descending
		grav  = FALL_GRAVITY
		max_v = MAX_FALL
	else:                            # ascending
		grav  = GRAVITY
		max_v = MAX_FALL

	velocity.y = minf(velocity.y + grav * delta, max_v)


# ═══ Horizontal ═══════════════════════════════════════════════════════════════

func _handle_horizontal(delta: float) -> void:
	var on_floor := is_on_floor()
	var accel    := ACCELERATION if on_floor else AIR_ACCEL
	var fric     := FRICTION     if on_floor else AIR_FRICTION
	var dir      := Input.get_axis("move_left", "move_right")

	if dir != 0.0:
		_facing    = sign(dir) as int
		velocity.x = move_toward(velocity.x, dir * MAX_SPEED, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	_sprite.flip_h = (_facing < 0)


# ═══ Jump & Dash ══════════════════════════════════════════════════════════════

func _handle_jump_and_dash() -> void:
	# Always cache the input — buffer fires even if jump fires this frame.
	if Input.is_action_just_pressed("jump"):
		_buffer_t = JUMP_BUFFER_TIME

	# Dash (highest priority).
	if Input.is_action_just_pressed("dash") and _can_dash and _dash_cd_t <= 0.0:
		_start_dash()
		return

	# Wall jump (overrides floor jump on the same frame).
	if Input.is_action_just_pressed("jump") and is_on_wall() and not is_on_floor():
		var n    := get_wall_normal()
		velocity  = Vector2(n.x * WALL_JUMP_X, WALL_JUMP_Y)
		_coyote_t = 0.0
		_buffer_t = 0.0
		return

	# Normal / coyote jump via buffer.
	if _buffer_t > 0.0 and (is_on_floor() or _coyote_t > 0.0):
		velocity.y = JUMP_VELOCITY
		_coyote_t  = 0.0
		_buffer_t  = 0.0

	# Variable height: cut velocity aggressively on early release.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULT


# ═══ Post-move bookkeeping ════════════════════════════════════════════════════

func _post_move() -> void:
	var on_floor := is_on_floor()
	# Coyote window opens the first frame we leave the floor.
	if _was_on_floor and not on_floor and velocity.y >= 0.0:
		_coyote_t = COYOTE_TIME
	# Dash recharges on landing.
	if on_floor:
		_can_dash = true
	_was_on_floor = on_floor


func _wall_sliding() -> bool:
	return is_on_wall() and not is_on_floor() and velocity.y > 0.0


# ═══ Timers ═══════════════════════════════════════════════════════════════════

func _tick_timers(delta: float) -> void:
	_coyote_t  = maxf(_coyote_t  - delta, 0.0)
	_buffer_t  = maxf(_buffer_t  - delta, 0.0)
	_dash_cd_t = maxf(_dash_cd_t - delta, 0.0)


# ═══ Dash ═════════════════════════════════════════════════════════════════════

func _tick_dash(delta: float) -> void:
	_dash_t  -= delta
	_paper_t += delta
	velocity  = _dash_dir * DASH_SPEED
	move_and_slide()
	_push_trail_point()
	if _paper_enabled and _paper_t >= PAPER_INTERVAL:
		_paper_t -= PAPER_INTERVAL
		_spawn_paper()
	if _dash_t <= 0.0:
		_end_dash()


func _end_dash() -> void:
	_is_dashing = false
	velocity    = _dash_dir * MAX_SPEED
	_paper_enabled = false   # one-time use — consumed when the dash ends


func _start_dash() -> void:
	var raw := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	)
	_dash_dir   = raw.normalized() if raw != Vector2.ZERO \
				  else Vector2(float(_facing), 0.0)
	velocity    = _dash_dir * DASH_SPEED
	_is_dashing = true
	_can_dash   = false
	_dash_t     = DASH_DURATION
	_dash_cd_t  = DASH_COOLDOWN
	_trail_pts.clear()
	_trail.clear_points()
	_trail.visible = true
	_paper_t = 0.0
	_engine_freeze()


## Spawn a single paper-document platform at the player's current feet position.
## Called periodically during every dash to lay a trail of solid stepping stones.
func _spawn_paper() -> void:
	if _paper_scene == null:
		return
	var p : StaticBody2D = _paper_scene.instantiate()
	get_parent().add_child(p)
	# Place paper at feet level (20 px below body centre — approx. half-height).
	p.global_position = global_position + Vector2(0.0, 20.0)


## Called by water-cooler pickups to restore the dash charge mid-air.
func refresh_dash() -> void:
	_can_dash = true


## Called by Document Floater pickups to arm the paper trail for the next dash.
func enable_paper_trail() -> void:
	_paper_enabled = true


## Accumulate an external impulse (wind shaft, shredder vacuum, etc.).
## The caller should scale the force by delta before passing it in.
func add_force(f: Vector2) -> void:
	_external_force += f


func _engine_freeze() -> void:
	Engine.time_scale = FREEZE_SCALE
	var t := get_tree().create_timer(FREEZE_DURATION, true, false, true)
	t.timeout.connect(func() -> void: Engine.time_scale = 1.0)


# ═══ Animation ════════════════════════════════════════════════════════════════

func _animate(delta: float) -> void:
	if _idle_tex == null or _run_tex == null:
		return

	# Dash charge indicator — red when spent, resets on landing (Celeste style).
	_sprite.modulate = COLOR_READY if _can_dash else COLOR_SPENT

	var want := "run" if (is_on_floor() and absf(velocity.x) > 10.0) else "idle"

	if want != _anim_name:
		_anim_name  = want
		_anim_frame = 0
		_anim_t     = 0.0
		_sprite.texture = _run_tex   if _anim_name == "run" else _idle_tex
		_sprite.hframes = RUN_FRAMES if _anim_name == "run" else IDLE_FRAMES
		_sprite.frame   = 0

	_anim_t += delta
	var spf := 1.0 / (RUN_FPS if _anim_name == "run" else IDLE_FPS)
	if _anim_t >= spf:
		_anim_t    -= spf
		_anim_frame = (_anim_frame + 1) % _sprite.hframes
		_sprite.frame = _anim_frame


# ═══ Trail ════════════════════════════════════════════════════════════════════

func _push_trail_point() -> void:
	_trail_pts.push_front(global_position)
	if _trail_pts.size() > TRAIL_LEN:
		_trail_pts.resize(TRAIL_LEN)
	_trail.clear_points()
	for pt in _trail_pts:
		_trail.add_point(pt)


func _decay_trail() -> void:
	if _trail_pts.is_empty():
		_trail.visible = false
		return
	if not _is_dashing:
		_trail_pts.pop_back()
		_trail.clear_points()
		for pt in _trail_pts:
			_trail.add_point(pt)
