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
## How fast momentum he was HANDED bleeds away, px/s^2 — a conveyor belt's
## takeoff today, anything else that gives him speed later. Much gentler than
## ground_decel: this is the knob that decides how long a boost lasts. Raise it
## to make boosts snappier and shorter, drop it to make them carry.
@export var overspeed_decel := 150.0
## How long after a handover that gentler rate applies. It exists to SCOPE the
## rule, not to time it: at 150 px/s^2 a 60 px/s boost is spent in 0.4s anyway.
##
## Scoped deliberately. The dash also leaves him well above his top speed
## (dash_end_speed 160), and a rule written as "anything above max_run_speed
## decays gently" quietly made every dash carry half again as far — 49px to 77px
## in smoke_test — which is tuned feel nobody asked to change.
@export var boost_time := 0.6
## Air acceleration as a fraction of the ground value. Below 1 so air feels
## slightly floatier, but still high for strong mid-air control.
@export_range(0.0, 1.0) var air_accel_mult := 0.8
## Air deceleration fraction (letting go of the stick mid-air).
@export_range(0.0, 1.0) var air_decel_mult := 0.6

@export_group("Jump")
## Initial upward speed. With rise_gravity 1400 (and the anti-gravity apex
## below) this measures to a ~33px apex — just over a 2-cell pillar on the
## 16px LDtk grid (32px), so a full-height jump BARELY clears it (~1px spare).
## Measured, not derived: the apex modifier makes the closed-form v^2/2g wrong.
@export var jump_speed := 290.0
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
## Dash speed. Sized so a full jump + upward dash clears a 4-cell platform on
## the 16px LDtk grid (64px) RELIABLY rather than frame-perfectly: measured
## apex runs 54-82px depending on when you dash, clearing 64px on 17 of 20
## tested timings. Tuning this down to a "barely clears" ~1px margin was tried
## and is wrong — that margin only exists at the single best dash timing, so
## in play the platform reads as impossible (it cleared on just 6 of 20).
## Vertical clearance needs a WINDOW, not a knife edge.
@export var dash_speed := 260.0
## How long the dash lasts. Distance = dash_speed * dash_time.
@export var dash_time := 0.15
## Speed kept in the dash direction when the dash ends (momentum carry-over).
@export var dash_end_speed := 160.0
## Extra lockout after a dash ends before you can dash again (anti-spam).
@export var dash_cooldown := 0.2
## Freeze-frame on dash start (~3 frames at 60fps). Sells the impact.
@export var dash_freeze_time := 0.05

@export_group("Glow")
## Ability gate, same pattern as has_dash: OFF until earned. The musical-tile
## sequence grants it (see scripts/note_sequence.gd).
@export var has_glow := false
## How far the glow reaches, in CELLS of the 16px LDtk grid. The falloff comes
## from the radial texture, so it fades out toward this edge rather than
## ending at a hard rim.
##
## 5.2 = 83px, a third of the 320px room's width. Widened from 4.0 by request:
## the reward for playing the tune is being able to SEE, and at 4 cells the lit
## pool barely reached past his own body in the rooms the puzzle unlocks.
@export var glow_radius_cells := 5.2
## Brightness at full strength.
@export var glow_energy := 1.25
## Warm yellow, to read as "Hooshang's own light" against the cold office.
@export var glow_color := Color(1.0, 0.9, 0.42)
## Fade-in when the ability is granted.
@export var glow_grant_time := 0.8

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
## How long the dedicated wall-jump kick animation plays for after pushing off.
## Sized to the clip (5 frames at 14fps = 0.36s) so it reads fully before the
## normal jump/fall pose takes over; shorten it to cut the kick short.
@export var wall_jump_anim_time := 0.36

@export_group("Death")
## How long the death animation owns the screen before he respawns, in seconds.
##
## Lives on the PLAYER rather than in each level's respawn_delay because it is a
## property of dying, not of a room: two levels disagreeing about it would mean
## the burst getting cut off in one of them. Levels wait at least this long (see
## level_base.gd / ldtk_world.gd), so a level is still free to hold longer.
##
## The burst itself is shorter (Juice.death_shard_time) on purpose — the shards
## are gone and the screen is still for a beat before he comes back, which is
## what makes a retry read as a new attempt rather than a bounce. Halving this
## therefore means halving that too, or the burst runs right up to the respawn
## and the beat disappears.
@export var death_time := 0.5

@export_group("Slide zones")
## Ceiling on how fast a slide zone can carry him, in px/s. The zone supplies
## the acceleration; this is the limit, so a long chute cannot ramp him up to a
## speed that tunnels him through a wall in one physics step.
@export var max_slide_speed := 260.0

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
var wall_jump_timer := 0.0      # how long the wall-jump kick animation still has to run
var boost_timer := 0.0          # while > 0, handed-over momentum decays gently

var dash_dir := Vector2.RIGHT

# Slide zones. The zone he is standing in owns part of his movement: it drags
# him along `slide_dir`, throttles his steering to `slide_control`, and takes
# jump and dash away entirely until he is out of it.
#
# The zone hands these over through enter_slide() and does NOT drive velocity
# itself. A zone writing velocity from its own _physics_process would land
# either side of this node's move_and_slide() depending on tree order, which is
# the kind of bug that only shows up in one room. Everything that moves him
# lives here, in one frame order.
var slide_zone: Node = null     # which zone, so a second one leaving can't clear it
var slide_dir := Vector2.ZERO   # unit vector he is being dragged along
var slide_control := 1.0        # multiplier on steering while inside, 1 = full
var slide_accel := 0.0          # px/s^2 the drag builds at
var slide_speed := 0.0          # px/s it has built to so far

# The sprite sits at 0.39 scale (88px source frames -> ~17px tall on screen)
# with its feet offset-pinned to the bottom of the 8x12 hitbox. It lives
# inside SpriteSquash, a wrapper Node2D that Juice scale-tweens for squash &
# stretch — Visual's own scale/offset above are never touched by that, so
# they stay exactly as tuned regardless of what juice.gd is doing.
@onready var visual: AnimatedSprite2D = $SpriteSquash/Visual
@onready var camera: Camera2D = $Camera2D
@onready var juice: Juice = $Juice
@onready var glow_light: PointLight2D = $GlowLight


func _ready() -> void:
	_apply_glow(has_glow)


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
	# A slide owns him: no jumps, including one buffered on the way in. Cleared
	# here rather than guarded at each jump site, because there are four of them
	# (ground, coyote, wall slide, wall coyote) and a fifth would forget.
	if sliding():
		jump_buffer_timer = 0.0

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

	if sliding():
		_apply_slide(delta)

	var incoming_vel_y := velocity.y  # fall speed just before landing is resolved, for juice.on_land()
	move_and_slide()
	_post_move(was_on_floor, input_x, incoming_vel_y)
	_update_visual()


func _tick_timers(delta: float) -> void:
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	boost_timer = maxf(boost_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	wall_coyote_timer = maxf(wall_coyote_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	wall_lock_timer = maxf(wall_lock_timer - delta, 0.0)
	wall_jump_timer = maxf(wall_jump_timer - delta, 0.0)


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
		# Landing in IDLE with the dash's UPWARD momentum still applied is what
		# used to strand him mid-air (see the invariant in _post_move). Go to
		# FALL whenever there is any rise left, so gravity owns him again; IDLE
		# is only for a dash that genuinely finished on the ground.
		state = State.IDLE if is_on_floor() and velocity.y >= 0.0 else State.FALL


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
	# slide_control is 1.0 unless he is in a slide zone. Applied to the RATE, the
	# same knob wall_jump_control_mult turns: he still has a top speed and can
	# still choose a direction, he just cannot change his mind quickly. Capping
	# his top speed instead would read as walking through treacle rather than as
	# losing his footing.
	rate *= control_mult * slide_control
	# Momentum he was GIVEN bleeds off at its own gentle rate rather than at the
	# rate he changes his mind. Without this a boost is arithmetically real and
	# completely imperceptible: his own deceleration drags him back to the speed
	# he asked for inside a fifth of a second, so a 60 px/s conveyor bought about
	# ten pixels of extra jump.
	#
	# Only while he is not fighting it — pushing the other way still turns him
	# around at the usual rate, so nothing about steering changes — and only
	# while it is SLOWING him, so it can never cap his acceleration.
	if boost_timer > 0.0 and absf(velocity.x) > absf(target) \
			and (target == 0.0 or signf(target) == signf(velocity.x)):
		rate = overspeed_decel
	velocity.x = move_toward(velocity.x, target, rate * delta)


## Drag him along the slide, and build that drag up over time.
##
## slide_speed is a FLOOR on how fast he is going along the slope, not a force
## added each frame: it ramps at slide_accel and the velocity is projected up to
## meet it. That way gravity and his own running still add on top — a player who
## throws himself down the chute goes faster than one who does not — while the
## slide alone can never stall, and never compounds with gravity into a speed
## nobody chose.
func _apply_slide(delta: float) -> void:
	slide_speed = minf(slide_speed + slide_accel * delta, max_slide_speed)
	var along := velocity.dot(slide_dir)
	if along < slide_speed:
		velocity += slide_dir * (slide_speed - along)


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
	wall_jump_timer = wall_jump_anim_time
	state = State.JUMP
	juice.on_jump()


func _try_dash() -> bool:
	if not has_dash:
		return false  # ability not unlocked yet (see Level 1's Rumi scene)
	if sliding():
		return false  # the slide owns him until he is out of it
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
	# A dash starts from a clean slate, so nothing it was handed earlier trails
	# into it: dash_end_speed decaying gently instead of normally would make a
	# dash off a conveyor carry further than the same dash anywhere else, and a
	# dash has to be the same move everywhere it is used.
	boost_timer = 0.0
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

	# INVARIANT: a ground state must never run in mid-air.
	#
	# _state_ground() deliberately applies no gravity — on the floor there is
	# nothing to fall towards. So being airborne in IDLE or RUN means NOTHING
	# pulls the player down: he keeps whatever vertical speed he had forever.
	# With upward speed that is a permanent float — he rises at a constant rate,
	# reaches the ceiling, has velocity.y zeroed by the collision, and then hangs
	# there for good, because no branch below moves a ground state on.
	#
	# The coyote check above used to be the only way out and it cannot cover
	# this: it requires `velocity.y >= 0.0`, which is exactly false in the case
	# that strands him. Anything that leaves a ground state set while off the
	# floor lands here instead (the dash exit below can, when a dash with an
	# upward component happens to end on the frame the player is still touching
	# the floor). Fixing the invariant rather than that one caller keeps the
	# whole class of bug closed.
	if state == State.IDLE or state == State.RUN:
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
			# A wall jump is an ordinary JUMP state — the dedicated kick is
			# selected by how the jump STARTED, which only this timer records.
			visual.play("wall_jump" if wall_jump_timer > 0.0 else "jump")
		State.FALL:
			# Keep the kick through the arc if it is still running: a short hop
			# off a wall can reach FALL before the clip has played out.
			visual.play("wall_jump" if wall_jump_timer > 0.0 else "fall")
		State.DASH:
			visual.play("dash")  # forward lunge burst, one-shot
		State.WALL_SLIDE:
			visual.play("wall_slide")  # dedicated Slide pose
	# Dash availability tint (our stand-in for Celeste's hair color):
	# normal colors = dash ready, cool blue tint = dash spent.
	if state != State.DASH:
		visual.modulate = Color.WHITE if dash_available else Color(0.6, 0.75, 1.0)


# -------------------------------------------------------- death/respawn ----

# DYING DOES NOT TOUCH COLLISION, AND THAT IS DELIBERATE.
#
# Death used to disable $CollisionShape2D and respawn re-enabled it. That
# double-counted EVERY hazard death, and the reason is worth keeping written
# down: taking a body out of an Area2D's detection and putting it back makes the
# area fire `body_entered` again at the position it was removed from. Measured
# on the real spikes — the second one arrives ~25 frames after the respawn, with
# Hooshang standing 200px away at his checkpoint. He is genuinely alive by then,
# so die()'s "already DEAD" guard has nothing to reject; the call is
# indistinguishable from a real death and no guard can fix it.
#
# Toggling `collision_layer` instead has exactly the same fault — it is the
# removal and re-add that does it, not which property performs them. The only
# fix is to never remove him.
#
# Nothing needs him removed: a DEAD player returns from _physics_process before
# move_and_slide, so the corpse cannot move, cannot be pushed, and cannot enter
# anything new in the 0.15s before it respawns.

func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector2.ZERO
	visible = false
	# The burst is thrown BEFORE he is counted or announced, so it leaves from
	# where he actually was. Purely cosmetic and nothing waits on it — see
	# juice.on_death(); how long the game holds is death_time, below.
	juice.on_death()
	Deaths.record()  # the run's death count, shown top-right
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
	wall_jump_timer = 0.0
	# Respawning outside a zone he died in still fires its body_exited, since he
	# is never removed from collision (see above) — but a checkpoint INSIDE the
	# same zone would not, and he would come back sliding with no zone to blame.
	# Cheaper to start every life with full control and let the zone re-take it.
	_clear_slide()
	visible = true
	state = State.FALL
	camera.reset_smoothing()  # snap the camera so retries feel instant


func state_name() -> String:
	return State.keys()[state]


# ----------------------------------------------------------- slide zones ----
# The API a SlideZone drives him through (scenes/props/zones/slide_zone.gd).
# The zone says what the slide IS; this node is the only thing that moves him.

func sliding() -> bool:
	return slide_zone != null


## Hand part of his movement to `zone`: dragged along `direction`, steering
## throttled to `control` (0..1), the drag building at `ramp` px/s^2.
##
## The drag starts at whatever speed he already had along the slope, so arriving
## at a run is not punished with a stall — a chute entered fast stays fast.
##
## A second zone entered while inside the first simply takes over. Overlapping
## zones are a level-design accident rather than a feature, and the alternative
## (counting overlaps) leaves him stuck sliding forever if one of them is ever
## freed while he is inside it.
## Hand him horizontal momentum, in px/s — a conveyor belt letting go of him on
## takeoff, and whatever else gives him speed later.
##
## A method rather than a prop writing `player.velocity.x` itself (STYLE_GUIDE
## §4), because the interesting half is not the addition: it is `boost_timer`,
## which is what tells _apply_run this speed was GIVEN and should bleed off
## gently instead of being scrubbed by his own deceleration in three frames.
## Reaching in from outside gets the addition and silently loses that.
func add_momentum(dx: float) -> void:
	if state == State.DEAD or is_zero_approx(dx):
		return
	velocity.x += dx
	boost_timer = boost_time


func enter_slide(zone: Node, direction: Vector2, control: float, ramp: float) -> void:
	if direction == Vector2.ZERO:
		return
	slide_zone = zone
	slide_dir = direction.normalized()
	slide_control = clampf(control, 0.0, 1.0)
	slide_accel = maxf(ramp, 0.0)
	slide_speed = maxf(velocity.dot(slide_dir), 0.0)


## Give control back, if `zone` is the one that took it. The check matters when
## zones overlap: the one he left is not always the one holding him.
func exit_slide(zone: Node) -> void:
	if slide_zone == zone:
		_clear_slide()


func _clear_slide() -> void:
	slide_zone = null
	slide_dir = Vector2.ZERO
	slide_control = 1.0
	slide_accel = 0.0
	slide_speed = 0.0


# ------------------------------------------------------------- cosmetics ----
# Small API so other nodes ask the player to do a thing, rather than reaching
# into its child sprite/camera directly.

## Turn Hooshang to face a direction during a cutscene (-1 left, 1 right).
## Exists because input_locked zeroes the input axis, so a locked player can
## never turn himself — a scripted "he looks around" beat has to ask. Takes
## effect on the next frame's _update_visual(), like every other visual.
func look(dir: int) -> void:
	if dir != 0:
		facing = signi(dir)


## Brief cosmetic flash on the sprite (e.g. Rumi granting an ability). Visual
## only — uses self_modulate so it doesn't fight the dash-tint on modulate.
func flash(color := Color(3.0, 2.6, 1.6), rise := 0.15, fall := 0.35) -> void:
	var t := create_tween()
	t.tween_property(visual, "self_modulate", color, rise)
	t.tween_property(visual, "self_modulate", Color.WHITE, fall)


## Bounce the camera, for something happening TO him rather than something he
## did. Forwards to the same dip-and-spring Juice uses for hard landings, so a
## collapsing room and a heavy fall shake the screen the same way.
##
## A method here rather than callers reaching into $Juice: cosmetic asks come in
## through the controller (see flash()), which is what lets Juice be deleted
## outright without breaking anything that talks to the player.
func shake(strength := 1.4, duration := 0.35) -> void:
	juice.shake(strength, duration)


## Rattle the camera for as long as something is coming apart around him. Unlike
## shake(), which is one knock, this runs for `duration` and decays — see
## Juice.rumble().
func rumble(strength := 1.6, duration := 1.0) -> void:
	juice.rumble(strength, duration)


## Freeze him mid-scene: no input, no gravity, no state machine, exactly where he
## stands. Comes back with velocity cleared, so a hold during a fall doesn't hand
## control back to a player who is suddenly moving at terminal speed.
##
## `input_locked` alone is not this — that takes his controls away and leaves him
## falling, which is right for a cutscene he walks into and wrong for one where
## the floor is the thing being dramatic.
func hold(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var locked := input_locked
	input_locked = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		return
	set_physics_process(true)
	velocity = Vector2.ZERO
	input_locked = locked


## Turn the glow on (the musical-tile sequence's reward), fading it up rather
## than popping it on. Safe to call twice.
##
## Deliberately NOT permanent, unlike has_dash: the glow lasts only for the
## current room and the current life. NoteSequence revokes it on death or on
## leaving the room, and you re-earn it by solving the tiles again.
func grant_glow() -> void:
	if has_glow:
		return
	has_glow = true
	_apply_glow(true)
	glow_light.energy = 0.0
	var t := create_tween()
	t.tween_property(glow_light, "energy", glow_energy, glow_grant_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Lose the glow. Snaps off rather than fading — it fires on death and on room
## transitions, and a glow lingering across either of those reads as a bug.
func revoke_glow() -> void:
	if not has_glow:
		return
	has_glow = false
	_apply_glow(false)


## Push the glow exports onto the light. The radial texture is 128px wide, so
## its untouched radius is 64px; scale that to the requested cell radius.
func _apply_glow(on: bool) -> void:
	if glow_light == null:
		return
	glow_light.enabled = on
	glow_light.color = glow_color
	glow_light.energy = glow_energy if on else 0.0
	const TEXTURE_RADIUS := 64.0
	glow_light.texture_scale = (glow_radius_cells * 16.0) / TEXTURE_RADIUS


## Clamp the follow-camera to a level's bounds (pixels). Called by LevelBase.
func set_camera_limits(bounds: Rect2i) -> void:
	camera.limit_left = bounds.position.x
	camera.limit_top = bounds.position.y
	camera.limit_right = bounds.end.x
	camera.limit_bottom = bounds.end.y
