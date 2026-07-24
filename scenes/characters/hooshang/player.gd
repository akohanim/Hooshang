class_name Player
extends CharacterBody2D
## Celeste-style precision platformer controller, built as a small state machine.
##
## Units are pixels and seconds. The game renders at 320x180 with 8px tiles and
## physics at 60fps, so e.g. 90 px/s = 1.5 px per frame.
##
## FUTURE HOOKS (do not implement yet):
## - New states (underworld variants, B&W power mode, climbing...) slot in by
##   adding to the State enum, a branch in the match below, and a handler
##   function. Keep each state's logic in its own function.
## - Player visuals are decided in ONE place, _update_visual(). Palette shifts
##   and power-mode looks should extend that function, not scatter modulates.

signal died

enum State { IDLE, RUN, JUMP, FALL, DASH, WALL_SLIDE, DEAD }

@export_group("Run")
## Top horizontal speed. 90 px/s (Celeste's run speed) reads well at 8px tiles.
@export var max_run_speed := 90.0
## Ground acceleration. 900 px/s^2 reaches top speed in ~6 frames (90/900 = 0.1s).
@export var ground_accel := 900.0
## Used when stopping OR turning around. Higher than accel so stops and
## direction flips feel snappy rather than skatey.
@export var ground_decel := 1600.0
## Air acceleration as a fraction of the ground value. Below 1 so air feels
## slightly floatier, but still high for strong mid-air control.
@export_range(0.0, 1.0) var air_accel_mult := 0.8
## Air deceleration fraction (letting go of the stick mid-air).
@export_range(0.0, 1.0) var air_decel_mult := 0.6

@export_group("Jump")
## Initial upward speed. With rise_gravity 1400 this gives a ~28px (3.5 tile)
## jump, reaching the apex in 0.2s.
@export var jump_speed := 280.0
## Releasing jump early multiplies upward speed by this — that's the variable
## jump height. ~0.45 means a tap gives roughly half the full height.
@export_range(0.0, 1.0) var jump_cut_multiplier := 0.45
## Pressing jump this long BEFORE landing still jumps on landing.
@export var jump_buffer_time := 0.1
## Jumping this long AFTER walking off a ledge still works.
@export var coyote_time := 0.1

@export_group("Gravity")
## Gravity while moving up. Lower than fall gravity so the rise feels powerful.
@export var rise_gravity := 1400.0
## Gravity while moving down. Higher = snappy, weighty falls (Celeste-like).
@export var fall_gravity := 2200.0
## Terminal velocity. Caps fall speed so drops stay readable and survivable.
@export var max_fall_speed := 220.0
## When |vertical speed| is under this, we're "at the apex" of a jump...
@export var apex_threshold := 40.0
## ...and gravity is multiplied by this, giving a moment of float/control
## at the top of every jump ("anti-gravity apex").
@export_range(0.0, 1.0) var apex_gravity_mult := 0.4

@export_group("Dash")
## Ability gate: Level 1 starts with this OFF and Rumi grants it mid-level.
## The test level leaves it on. (Future abilities should follow this pattern.)
@export var has_dash := true
## Dash speed. 260 px/s for 0.15s = ~39px (~5 tiles) of fixed-distance dash.
@export var dash_speed := 260.0
## How long the dash lasts. Distance = dash_speed * dash_time.
@export var dash_time := 0.15
## Speed kept in the dash direction when the dash ends (momentum carry-over).
@export var dash_end_speed := 160.0
## Extra lockout after a dash ends before you can dash again (anti-spam).
@export var dash_cooldown := 0.2
## Freeze-frame on dash start (~3 frames at 60fps). Sells the impact.
@export var dash_freeze_time := 0.05

@export_group("Wall")
## Max downward speed while sliding on a wall (much slower than free fall).
@export var wall_slide_max_speed := 60.0
## Horizontal push away from the wall on a wall jump. Above max_run_speed so
## the kick is felt even at full run.
@export var wall_jump_speed_x := 170.0
## After a wall jump, air control is reduced for this long so you can't
## instantly steer back onto the same wall.
@export var wall_jump_lock_time := 0.15
## Air control multiplier during that lock (low = the kick "owns" you briefly).
@export_range(0.0, 1.0) var wall_jump_control_mult := 0.3
## A wall within this many pixels counts as jumpable — you do NOT need to be
## wall-sliding first. This is what makes chained wall jumps feel effortless.
@export var wall_jump_check_distance := 3.0
## Coyote time for walls: jumping shortly after drifting off a wall still works.
@export var wall_coyote_time := 0.1

var state: State = State.FALL
var facing := 1                 # 1 = right, -1 = left; used for neutral dashes
## Cutscene lock: physics keeps running (gravity settles the player) but all
## input reads as neutral. Dialogue/cinematics set this, not pause.
var input_locked := false
var dash_available := true      # one dash per airtime, refilled on landing
var wall_dir := 0               # which side the wall is on while wall sliding

# Feel timers, all count down to 0 in seconds.
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var wall_coyote_timer := 0.0    # counts down after last wall contact in the air
var last_wall_dir := 0          # side that last wall was on (-1 left, 1 right)
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var freeze_timer := 0.0         # dash hitstop: physics is skipped while > 0
var wall_lock_timer := 0.0      # reduced air control after wall jump

var dash_dir := Vector2.RIGHT

# The sprite sits at 0.55 scale (60px source frames -> ~17px tall on screen)
# with its feet offset-pinned to the bottom of the 8x12 hitbox. It lives
# inside SpriteSquash, a wrapper Node2D that Juice scale-tweens for squash &
# stretch — Visual's own scale/offset above are never touched by that, so
# they stay exactly as tuned regardless of what juice.gd is doing.
@onready var visual: AnimatedSprite2D = $SpriteSquash/Visual
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var juice: Juice = $Juice


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# Dash hitstop: freeze everything for a few frames, then resume.
	# Engine.time_scale (see juice.hitstop()) does NOT shrink this `delta` —
	# it changes how often fixed-delta physics ticks happen in real time, not
	# the delta value itself. So this counts down in exactly the same number
	# of physics FRAMES either way; hitstop just stretches out how much real
	# wall-clock time those frames take, which is the whole point of it.
	if freeze_timer > 0.0:
		freeze_timer -= delta
		return

	_tick_timers(delta)

	var input_x := 0.0 if input_locked else Input.get_axis("move_left", "move_right")
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	if not input_locked:
		if Input.is_action_just_pressed("jump"):
			jump_buffer_timer = jump_buffer_time
		if Input.is_action_just_pressed("dash") and _try_dash():
			return  # dash starts next frame, after the freeze-frames

	var was_on_floor := is_on_floor()

	match state:
		State.IDLE, State.RUN:
			_state_ground(delta, input_x)
		State.JUMP, State.FALL:
			_state_air(delta, input_x)
		State.DASH:
			_state_dash(delta)
		State.WALL_SLIDE:
			_state_wall_slide(delta)

	var incoming_vel_y := velocity.y  # fall speed just before landing is resolved, for juice.on_land()
	move_and_slide()
	_post_move(was_on_floor, input_x, incoming_vel_y)
	_update_visual()


func _tick_timers(delta: float) -> void:
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	wall_coyote_timer = maxf(wall_coyote_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	wall_lock_timer = maxf(wall_lock_timer - delta, 0.0)


# ---------------------------------------------------------------- states ----

func _state_ground(delta: float, input_x: float) -> void:
	_apply_run(delta, input_x, 1.0)
	if _try_buffered_jump():
		return
	state = State.RUN if input_x != 0.0 or absf(velocity.x) > 5.0 else State.IDLE


func _state_air(delta: float, input_x: float) -> void:
	var control := wall_jump_control_mult if wall_lock_timer > 0.0 else 1.0
	_apply_run(delta, input_x, control)
	_apply_gravity(delta)
	# Variable jump height: cutting the jump early kills most upward speed.
	if state == State.JUMP and velocity.y < 0.0 and Input.is_action_just_released("jump"):
		velocity.y *= jump_cut_multiplier
	if _try_buffered_jump():
		return  # coyote jump
	# Track nearby walls so a buffered jump can kick off them at any time —
	# no need to be wall-sliding first (this is what makes chaining easy).
	var near := _near_wall_dir()
	if near != 0:
		wall_coyote_timer = wall_coyote_time
		last_wall_dir = near
	if jump_buffer_timer > 0.0 and wall_coyote_timer > 0.0:
		_do_wall_jump(last_wall_dir)
		return
	if velocity.y >= 0.0:
		state = State.FALL


func _state_dash(delta: float) -> void:
	# Fixed direction and speed, no gravity: the dash "owns" the player.
	velocity = dash_dir * dash_speed
	juice.dash_tick(delta)
	dash_timer -= delta
	if dash_timer <= 0.0:
		velocity = dash_dir * dash_end_speed  # keep some momentum
		state = State.IDLE if is_on_floor() else State.FALL


func _state_wall_slide(delta: float) -> void:
	# Wall jump (uses the same buffer as normal jumps).
	if jump_buffer_timer > 0.0:
		_do_wall_jump(wall_dir)
		return
	# Slide down slowly; keep a nudge into the wall so contact is maintained.
	velocity.y = minf(velocity.y + fall_gravity * delta, wall_slide_max_speed)
	velocity.x = wall_dir * 20.0


# ------------------------------------------------------------- helpers ----

func _apply_run(delta: float, input_x: float, control_mult: float) -> void:
	var target := input_x * max_run_speed
	# Stopping or reversing uses the (faster) decel rate -> instant turnaround.
	var rate := ground_accel
	if target == 0.0 or (velocity.x != 0.0 and signf(target) != signf(velocity.x)):
		rate = ground_decel
	if not is_on_floor():
		rate *= air_accel_mult if target != 0.0 else air_decel_mult
	rate *= control_mult
	velocity.x = move_toward(velocity.x, target, rate * delta)


func _apply_gravity(delta: float) -> void:
	var g := rise_gravity if velocity.y < 0.0 else fall_gravity
	# Anti-gravity apex: floatier right at the top of the jump for control.
	if absf(velocity.y) < apex_threshold:
		g *= apex_gravity_mult
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _try_buffered_jump() -> bool:
	if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		velocity.y = -jump_speed
		state = State.JUMP
		juice.on_jump()
		return true
	return false


## Which side has a wall within wall_jump_check_distance: -1 left, 1 right, 0 none.
func _near_wall_dir() -> int:
	if test_move(global_transform, Vector2(-wall_jump_check_distance, 0.0)):
		return -1
	if test_move(global_transform, Vector2(wall_jump_check_distance, 0.0)):
		return 1
	return 0


func _do_wall_jump(from_wall_dir: int) -> void:
	jump_buffer_timer = 0.0
	wall_coyote_timer = 0.0
	velocity = Vector2(-from_wall_dir * wall_jump_speed_x, -jump_speed)
	wall_lock_timer = wall_jump_lock_time
	state = State.JUMP
	juice.on_jump()


func _try_dash() -> bool:
	if not has_dash:
		return false  # ability not unlocked yet (see Level 1's Rumi scene)
	if state == State.DASH or state == State.DEAD:
		return false
	if not dash_available or dash_cooldown_timer > 0.0:
		return false
	# 8-directional: snap analog input to -1/0/1 per axis; neutral = forward.
	var dir := Vector2(
		roundf(Input.get_axis("move_left", "move_right")),
		roundf(Input.get_axis("move_up", "move_down"))
	)
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0)
	dash_dir = dir.normalized()
	velocity = dash_dir * dash_speed
	dash_available = false
	dash_timer = dash_time
	dash_cooldown_timer = dash_time + dash_cooldown
	freeze_timer = dash_freeze_time
	state = State.DASH
	juice.on_dash_start(dash_dir)
	return true


## Transitions that depend on what move_and_slide() just discovered.
func _post_move(was_on_floor: bool, input_x: float, incoming_vel_y: float) -> void:
	if state == State.DASH or state == State.DEAD:
		return
	if is_on_floor():
		dash_available = true  # dash refreshes on landing
		if state == State.FALL or state == State.JUMP or state == State.WALL_SLIDE:
			juice.on_land(incoming_vel_y)
			state = State.RUN if input_x != 0.0 else State.IDLE
		return

	# Just walked off a ledge (didn't jump): start coyote time.
	if was_on_floor and velocity.y >= 0.0 and state != State.JUMP:
		coyote_timer = coyote_time
		state = State.FALL

	if state == State.WALL_SLIDE:
		# Let go, ran out of wall, or moving up -> back to normal air.
		if not is_on_wall() or input_x * wall_dir <= 0.0 or velocity.y < 0.0:
			state = State.FALL
	elif state == State.FALL:
		# Falling, touching a wall, and pushing into it -> wall slide.
		if velocity.y > 0.0 and is_on_wall_only():
			var wd := -signf(get_wall_normal().x)
			if input_x != 0.0 and signf(input_x) == wd:
				wall_dir = int(wd)
				state = State.WALL_SLIDE
				velocity.y = minf(velocity.y, wall_slide_max_speed)


## The ONE place player visuals are decided (future palette/power-mode hook).
func _update_visual() -> void:
	visual.flip_h = facing < 0
	match state:
		State.IDLE:
			visual.play("idle")
		State.RUN:
			visual.play("run")
		State.JUMP:
			visual.play("jump")
		State.FALL:
			visual.play("fall")
		State.DASH:
			visual.play("dash")  # forward lunge burst, one-shot
		State.WALL_SLIDE:
			visual.play("wall_slide")  # reuses the idle pose; tinted below to read distinctly
	# Dash availability tint (our stand-in for Celeste's hair color):
	# normal colors = dash ready, cool blue tint = dash spent.
	if state == State.WALL_SLIDE:
		visual.modulate = Color(0.65, 0.65, 0.72)
	elif state != State.DASH:
		visual.modulate = Color.WHITE if dash_available else Color(0.6, 0.75, 1.0)


# -------------------------------------------------------- death/respawn ----

func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector2.ZERO
	visible = false
	body_shape.set_deferred("disabled", true)
	died.emit()


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	dash_available = true
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	wall_coyote_timer = 0.0
	dash_cooldown_timer = 0.0
	freeze_timer = 0.0
	wall_lock_timer = 0.0
	visible = true
	body_shape.set_deferred("disabled", false)
	state = State.FALL
	camera.reset_smoothing()  # snap the camera so retries feel instant


func state_name() -> String:
	return State.keys()[state]


# ------------------------------------------------------------- cosmetics ----
# Small API so other nodes ask the player to do a thing, rather than reaching
# into its child sprite/camera directly.

## Brief cosmetic flash on the sprite (e.g. Rumi granting an ability). Visual
## only — uses self_modulate so it doesn't fight the dash-tint on modulate.
func flash(color := Color(3.0, 2.6, 1.6), rise := 0.15, fall := 0.35) -> void:
	var t := create_tween()
	t.tween_property(visual, "self_modulate", color, rise)
	t.tween_property(visual, "self_modulate", Color.WHITE, fall)


## Clamp the follow-camera to a level's bounds (pixels). Called by LevelBase.
func set_camera_limits(bounds: Rect2i) -> void:
	camera.limit_left = bounds.position.x
	camera.limit_top = bounds.position.y
	camera.limit_right = bounds.end.x
	camera.limit_bottom = bounds.end.y
