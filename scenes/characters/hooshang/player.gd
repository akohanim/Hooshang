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

enum State { IDLE, RUN, JUMP, FALL, DASH, WALL_SLIDE, CLIMB, DEAD }

## Half of the 9x12 hitbox in Hooshang.tscn — his NORMAL width. Kept here because
## the footing check has to probe at the box's own edges; if the shape is ever
## resized, these move with it or he loses his footing at the wrong place.
##
## He is a cell and an eighth across, and every part of that is deliberate.
##
## He used to be exactly one cell (4.0), and the extra half-pixel a side came in
## with the weight: he is drawn 7.0px across the belly now against 4.7px before
## (tools/gen_chubby_hooshang.py), and a box that still stopped at 8 would have
## had him brushing rooms his own gut is visibly inside. It is deliberately only
## a pixel. The world is built on 8px cells and the walkable minimum is a 2-cell
## slot; at 9 he still clears one of those with 3.5px a side, and 10 starts
## eating a margin that level geometry was authored against.
##
## Being at least a cell wide costs something either way: a body that wide
## cannot pass through a one-cell slot at all, since Godot resolves two
## exactly-abutting AABBs as a collision and 9 into 8 does not even abut. That
## is the right trade for a FLOOR — a one-cell hole in a walkway is something you
## stride over, not something that swallows you — so the fix is not a narrower
## man but a deliberate act. See the Squeeze group and `_tick_squeeze()`, whose
## `squeeze_width` is an ABSOLUTE width and therefore did not move with this.
const HALF_WIDTH := 4.5
const HALF_HEIGHT := 6.0

@export_group("Run")
## Top horizontal speed.
##
## 72 px/s, which is Celeste's own run speed (90, and what this was) taken down
## by a fifth. Deliberately BELOW Madeline rather than level with her: he is an
## elderly office worker, and the whole read of the character is that he is
## slower than the game he is in.
##
## THIS IS A LEVEL-GEOMETRY NUMBER, not just a feel one. Horizontal reach is
## airtime x this, so changing it moves every gap in the game: measured, a
## running jump went 54.0px across at 90 and goes 43.2px at 72 — more than a
## cell shorter. Run tests/feel_measure.tscn before and after touching it, and
## the level tests after, or a gap somebody built to be just clearable stops
## being clearable and nothing says so.
@export var max_run_speed := 72.0
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
## Initial upward speed, and while the button is held this is the rise rate
## exactly — so read it together with jump_hold_time, not on its own.
##
## Low (135, from 290 before the hold existed) because the hold now carries most
## of the height: 135 x 0.2s = 27 of the 34px apex, leaving 7px of ballistic
## coast after release. That 20/80 split is Celeste's own — its 105 and 0.2s put
## 21 of a 28px apex in the hold — and it is what makes the hold LADDER wide
## enough to aim at instead of a switch between "hop" and "jump".
##
## The apex itself is unchanged at 34px, just over a 32px pillar — 4 cells on
## the 8px LDtk grid — so a full-height jump BARELY clears one. Every room in
## ldtk/ is built against that number IN PIXELS, which is why halving the grid
## did not touch it: the rooms did not move, they were only re-cut finer.
##
## Measured, not derived: the apex modifier and the hold both make the
## closed-form v^2/2g wrong. tests/feel_measure.tscn prints the apex, the whole
## hold ladder, the airtime, the horizontal reach and the jump+dash sweep, which
## is how a retune proves what it moved. Run it before and after.
@export var jump_speed := 135.0
## Variable jump height, Celeste-style: HOLDING jump sustains the launch speed
## for up to this long, and letting go hands him straight to gravity.
##
## The old model was the opposite — a CUT, multiplying upward speed by
## jump_cut_multiplier on release. Both give you a short hop, but they feel like
## different moves: a cut makes the tap and the full jump two different ARCS
## (one of them visibly braking mid-rise), where a hold makes them the same move
## held for different lengths. The buoyancy people read as "Celeste-like" is
## mostly this.
##
## 0.2s is Celeste's VarJumpTime verbatim, and the width of this window IS the
## number of distinct jump heights you can ask for. It was 0.105 first, and that
## saturated after six frames: past a light tap every press gave the same jump,
## so the variable height was real in the physics and unreachable with a thumb.
## At 0.2s the ladder measures (tests/feel_measure.tscn):
##
##     held   1f    2f    4f    6f    8f   10f   12f   14f+
##     apex  7.3   9.6  14.1  18.6  23.1  27.6  32.1  34.3 px
##
## — 13 frames of usable travel, so a short push, a medium hold and a full press
## are three heights you can actually aim at.
##
## It is also load-bearing on the apex: `jump_speed * jump_hold_time` is 27 of
## the 34px, because the rise is exactly flat while the button is down.
## Shortening the hold lowers the ceiling as surely as lowering jump_speed does —
## retune the pair together, and re-measure.
@export var jump_hold_time := 0.2
## Which of the two models runs. Kept as a switch rather than deleting the cut
## outright so the old feel is one export away for comparison; note that
## jump_speed and the gravities are tuned for the HOLD, so flipping this off
## gives a much shorter jump rather than the original one.
@export var use_jump_hold := true
## Releasing jump early multiplies upward speed by this — the OLD variable jump
## height, live only while use_jump_hold is off.
@export_range(0.0, 1.0) var jump_cut_multiplier := 0.45
## Pressing jump this long BEFORE landing still jumps on landing.
@export var jump_buffer_time := 0.1
## Jumping this long AFTER walking off a ledge still works.
@export var coyote_time := 0.1

@export_group("Gravity")
## Gravity while moving up.
@export var rise_gravity := 1600.0
## Gravity while moving down. Only a little heavier than the rise — the split
## used to be 1400/2200, a 1.57x asymmetry, and that heavy fall was what ate the
## airtime: the drop read as the arc being switched off at the top rather than
## coming over it. Celeste runs ONE gravity with a half-strength band at the apex
## and saves the fast fall for when you hold down; narrowing this to 1.2 and
## letting the apex band below do the work is the same idea.
@export var fall_gravity := 1900.0
## Terminal velocity. Caps fall speed so drops stay readable and survivable.
@export var max_fall_speed := 220.0
## When |vertical speed| is under this, we're "at the apex" of a jump...
@export var apex_threshold := 46.0
## ...and gravity is multiplied by this, giving a moment of float/control
## at the top of every jump ("anti-gravity apex").
##
## Widened (40 -> 46) and deepened (0.4 -> 0.36) in the bounce retune. This pair
## is the safest knob in the group for level geometry: it buys hang at the top of
## the arc while barely touching the apex HEIGHT, because the band is only ever
## entered at speeds too low to travel far under any gravity.
##
## HOW MUCH AIRTIME IS AVAILABLE IS NOT A FREE CHOICE. Airtime times
## max_run_speed is horizontal reach, and Level 2's second gap is a dash GATE —
## it is supposed to be uncrossable without one. At +26% airtime a plain running
## jump cleared it and the level stopped teaching the dash (level2_test catches
## this). +16% is what that gap allows with the margin it was built with; more
## hang than this needs the gap widened first.
@export_range(0.0, 1.0) var apex_gravity_mult := 0.36

@export_group("Dash")
## Ability gate: Level 1 starts with this OFF and Rumi grants it mid-level.
## The test level leaves it on. (Future abilities should follow this pattern.)
@export var has_dash := true
## Dash speed. Sized so a full jump + upward dash clears a 64px platform (8
## cells on the 8px LDtk grid) RELIABLY rather than frame-perfectly. Tuning this
## down to a "barely clears" ~1px margin was tried and is wrong — that margin
## only exists at the single best dash timing, so in play the platform reads as
## impossible (it cleared on just 6 of 20). Vertical clearance needs a WINDOW.
##
## That window narrowed when the jump became a hold, and it is worth knowing why
## rather than re-tuning this to chase it. The sweep now clears 64px on 13 of 20
## timings (49-83px apex) where it used to clear on 16, and the ones it lost are
## all at the FRONT: a hold rises flat at jump_speed instead of front-loading the
## whole impulse, so four frames into a jump he is 9px up rather than 19px, and a
## dash thrown that early simply starts lower. What is left is 13 contiguous
## frames — 0.22s — which is still a window and not a knife edge.
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
## How far the glow reaches, in CELLS of the 8px LDtk grid. The falloff comes
## from the radial texture, so it fades out toward this edge rather than
## ending at a hard rim.
##
## 10.4 = 83px, a third of the 320px room's width. Widened from 4.0 cells (of
## the old 16px grid) by request:
## the reward for playing the tune is being able to SEE, and at 4 cells the lit
## pool barely reached past his own body in the rooms the puzzle unlocks.
@export var glow_radius_cells := 10.4
## Brightness at full strength.
@export var glow_energy := 1.25
## Warm yellow, to read as "Hooshang's own light" against the cold office.
@export var glow_color := Color(1.0, 0.9, 0.42)
## Fade-in when the ability is granted.
@export var glow_grant_time := 0.8

@export_group("Lemon Glow")
## The 'z' ability: spend one lemon for this many seconds of light. Its own
## timer and its own light (LemonGlowLight) rather than a rebinding of the
## Glow group above — that one is NoteSequence's, and NoteSequence revokes it
## on every room change in the whole game (see note_sequence.gd), not just its
## own puzzle room. Sharing GlowLight would mean walking through any door
## snuffs out a lemon you just spent.
@export var lemon_glow_time := 30.0
## Same shape as glow_radius_cells/glow_energy/glow_color above, for this
## light instead.
@export var lemon_glow_radius_cells := 10.4
@export var lemon_glow_energy := 1.25
@export var lemon_glow_color := Color(0.85, 1.0, 0.3)
## Once this many seconds are left, the light starts blinking to warn it is
## about to run out.
@export var lemon_glow_flicker_time := 3.0
## Blink rate in that window, full on/off cycles per second. A square wave
## rather than randf() static — deterministic, so a test can count blinks
## instead of eyeballing a monitor.
@export var lemon_glow_flicker_speed := 6.0

@export_group("Mushroom Power")
## How long an eaten mushroom's power lasts, in seconds.
@export var mushroom_power_time := 30.0
## Once this many seconds are left, the sparkle thins out to warn the power
## is about to run out — the same job lemon_glow_flicker_time does for its
## own countdown, just spent on spawn rate instead of a blink (see
## Juice.mushroom_sparkle_tick).
@export var mushroom_power_flicker_time := 5.0

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

@export_group("Climb")
## Vertical speed while gripping a ladder, px/s — both directions use this,
## since nothing here asks for climbing up and down at different rates.
@export var climb_speed := 60.0

@export_group("Footing")
## How much solid ground he needs under his MIDDLE to keep standing, in px
## either side of his centre. 0 disables the check.
##
## This exists because the hitbox is much wider than the part of him that
## stands. Godot keeps a body standing while ANY part of its shape overlaps the
## floor, so before this he could walk until his centre was a full box-half past
## a ledge — measured at 4px, when the box was 8 — which put every drawn pixel
## of him over air with a 2px gap between his feet and the ledge he was
## apparently standing on.
##
## Narrowing the hitbox does not fix it and is worth knowing why: for any part
## of him to still be over the platform the overhang has to be under his own
## drawn half-width at the FEET, and his boots measure 1.17px left of centre and
## 1.95 right — narrower than any body the 8px grid can be built around. Putting
## weight on him did not change that either: the belly went from 4.7px across to
## 7.0 and the boots did not move (tools/gen_chubby_hooshang.py fattens by
## normalised height and the last band is 0.5px).
##
## **It does not scale with the box, and did not move when the box widened to
## 9.** The footprint this check asks about is his CENTRE — `_keep_footing`
## probes `_ground_under(0.0)`, a single ray — so what counts as standing is
## already the strictest it can be at any width. This number is that ray's
## reach: it starts a px above his soles and runs `footing_width + 2` down, so
## raising it lets him keep his footing further off a surface, not further out
## over one. What DID follow from the wider box is the slide: he now has to be
## moved 4.5px rather than 4 to clear a ledge (see `ledge_slip_speed`).
@export var footing_width := 1.0
## How fast he slides off a ledge he has lost his footing on, px/s.
##
## A slide rather than an instant drop, because his box still overlaps the ledge
## when his centre passes the edge and Godot will keep resolving that as solid
## ground however he is flagged. He has to be moved clear. At this speed that
## takes about three frames, which reads as losing his footing rather than as
## being teleported off.
@export var ledge_slip_speed := 55.0

@export_group("Squeeze")
## How wide his hitbox becomes while he is going down a one-cell slot, in px.
##
## Two pixels off the grid, not two pixels off the man. The slot is one cell and
## he is a cell and an eighth, and even at exactly a cell two AABBs that abut
## are a collision in Godot — measured, an 8px box entered Level_1's 8px shaft
## from 0 of 33 approach positions across its mouth, and 7.99 was no better.
## 6 clears it with a pixel either side.
##
## **This is an ABSOLUTE width, not a fraction of HALF_WIDTH, and that is the
## point.** What has to fit is the shaft, which is 8px whatever he weighs — so
## when the box went from 8 to 9 this did not move, and the chimney measures
## exactly as it did before. Deriving it from his own width instead would have
## quietly widened him out of Level_1's shaft the day he put on weight.
@export var squeeze_width := 6.0
## How far either side of his centre to look for the slot's walls, in px.
##
## Past his own edges on purpose: he can be standing off-centre over a slot, and
## the point of the probe is to find where the hole actually is so he can be put
## down the middle of it.
##
## Absolute, like `squeeze_width`, and for the same reason — it measures the
## SLOT. It is bounded on both sides: shorter than a cell and a half or a
## one-cell hole two thirds under him is missed, longer and a two-cell gap in
## the floor starts reading as a slot to squeeze into rather than a drop.
@export var squeeze_probe := 6.0
## Probe resolution. Half a pixel: the hole is 8 wide and he is 6, so a coarser
## step can misplace him by more than the clearance he has.
@export var squeeze_step := 0.5

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
## True while his box is narrowed to fit a one-cell slot. Public because the
## visual could want to know one day; nothing reads it yet.
var squeezing := false

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
var jump_hold_timer := 0.0      # how much sustained thrust the held jump has left
var invulnerable_timer := 0.0   # ignores hazard collision queries briefly after respawning
var _lemon_glow_timer := 0.0    # seconds left on a lemon-bought glow; 0 = not running
## Which power an eaten mushroom granted, and how long it has left — 0 means
## none is running. Only meaningful while the timer is > 0; see
## consume_mushroom() and has_thought_immunity().
var mushroom_power_type: Mushroom.MushroomType = Mushroom.MushroomType.BLACK_WHITE
var _mushroom_power_timer := 0.0

var dash_dir := Vector2.RIGHT

## His own collision box, and the width it goes back to. Duplicated in _ready so
## squeezing writes to HIS shape and not to the one every instance shares.
var _box: RectangleShape2D
var _box_width := HALF_WIDTH * 2.0

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

# Ladders. Same split as slide zones: the ladder decides who is gripping it
# and when (touching it and reaching up or down — see ladder.gd), and hands
# over to enter_ladder()/exit_ladder(); everything that actually moves him
# while he climbs lives here, in one frame order.
var ladder_zone: Node = null    # which ladder, so a second one leaving can't clear it
var ladder_x := 0.0             # the rail's x his box is held to while climbing

# The sprite sits at 0.39 scale (88px source frames -> ~17px tall on screen)
# with its feet offset-pinned to the bottom of the 9x12 hitbox. It lives
# inside SpriteSquash, a wrapper Node2D that Juice scale-tweens for squash &
# stretch — Visual's own scale/offset above are never touched by that, so
# they stay exactly as tuned regardless of what juice.gd is doing.
@onready var visual: AnimatedSprite2D = $SpriteSquash/Visual
@onready var camera: Camera2D = $Camera2D
@onready var juice: Juice = $Juice
@onready var glow_light: PointLight2D = $GlowLight
@onready var lemon_glow_light: Sprite2D = $LemonGlowLight


func _ready() -> void:
	_apply_glow(has_glow)
	_apply_lemon_glow()
	var shape: CollisionShape2D = $CollisionShape2D
	# DUPLICATED. A sub-resource in a PackedScene is shared by every instance of
	# it, so without this a squeeze would narrow every player ever made from this
	# scene — including the one a test spawned three lines ago.
	shape.shape = shape.shape.duplicate()
	_box = shape.shape
	_box_width = _box.size.x


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if invulnerable_timer > 0.0:
		invulnerable_timer = maxf(invulnerable_timer - delta, 0.0)
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
		if Input.is_action_just_pressed("glow"):
			_try_lemon_glow()

	_tick_squeeze()

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
		State.CLIMB:
			_state_climb(delta, input_x)

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
	jump_hold_timer = maxf(jump_hold_timer - delta, 0.0)
	if _lemon_glow_timer > 0.0:
		_lemon_glow_timer = maxf(_lemon_glow_timer - delta, 0.0)
		_apply_lemon_glow()
	if _mushroom_power_timer > 0.0:
		_mushroom_power_timer = maxf(_mushroom_power_timer - delta, 0.0)
		juice.mushroom_sparkle_tick(delta, _mushroom_power_timer <= mushroom_power_flicker_time)
		if _mushroom_power_timer <= 0.0:
			_end_mushroom_power()


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
	_apply_jump_hold()
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
		juice.on_dash_end(dash_dir)
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
	velocity.y = minf(velocity.y + fall_gravity * delta, wall_slide_max_speed)
	# In the squeeze/chimney case he is already centred by _tick_squeeze() and
	# there is no lateral force pulling him off it, so nothing needs to push
	# him into either wall. Nudging him anyway is actively harmful here: if
	# _walled_both_sides() ever locked onto a side that is only briefly real
	# (a stair tread's lip, say), this nudge is what pinned him against its
	# fading sliver of contact for many extra frames rather than falling
	# straight through and clearing it in one — the nudge was the feedback
	# loop that kept a wrong wall_dir looking confirmed.
	if not squeezing:
		# Ordinary single-wall slide: keep a nudge into the wall so contact is
		# maintained (real contact, not the squeeze's floor-gap pinch).
		velocity.x = wall_dir * 20.0


## Gripping a ladder: no gravity, steering locked to the rail, vertical speed
## answers move_up/move_down directly. Two ways off — jump to hop away from it,
## or reach the floor at its base and push a direction to just walk off.
## Anything else (climbing above the top, dropping below the bottom) ends the
## grip the same way it started: the ladder notices the overlap is gone and
## calls exit_ladder (see ladder.gd), not this function.
func _state_climb(delta: float, input_x: float) -> void:
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		velocity = Vector2(facing * max_run_speed * 0.6, -jump_speed * 0.6)
		jump_hold_timer = 0.0
		_clear_ladder()
		state = State.JUMP
		juice.on_jump()
		return
	if is_on_floor() and input_x != 0.0:
		_clear_ladder()
		state = State.RUN
		return
	var vertical := 0.0 if input_locked else Input.get_axis("move_up", "move_down")
	velocity.y = vertical * climb_speed
	# Snapped to the rail via velocity, not a direct position write — everything
	# that moves him goes through move_and_slide, the same rule enter_slide's
	# own note gives for why a zone never writes velocity from outside this
	# frame.
	const CLIMB_SNAP_SPEED := 400.0
	velocity.x = clampf((ladder_x - global_position.x) / delta, -CLIMB_SNAP_SPEED, CLIMB_SNAP_SPEED) \
		if delta > 0.0 else 0.0


# ------------------------------------------------------------- helpers ----

func _apply_run(delta: float, input_x: float, control_mult: float) -> void:
	var target := input_x * max_run_speed
	# Stopping or reversing uses the (faster) decel rate -> instant turnaround.
	var rate := ground_accel
	if target == 0.0 or (velocity.x != 0.0 and signf(target) != signf(velocity.x)):
		rate = ground_decel
		# A deliberate FLIP at speed, not just letting go of the stick: only the
		# flip gets a visual, because stopping is already read by the run cycle
		# ending. Juice owns the speed threshold and the retrigger lockout — this
		# branch is true for every frame the old velocity survives, which is
		# three or four of them.
		if target != 0.0 and is_on_floor():
			juice.on_turn(absf(velocity.x))
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


## Variable jump height. Runs immediately AFTER gravity, which is the whole
## trick of the hold model: gravity is applied as normal every frame and then
## clamped back off while the button is down, so the rise is genuinely flat for
## jump_hold_time and then continues from full speed the instant you let go.
## Nothing special happens on release — there is no braking impulse to feel.
##
## `minf` rather than an assignment so the thrust can only ever hold him UP, and
## never becomes a floor under a velocity something else has a better claim on
## (a ceiling bonk, a hazard, a slide). The timer is cleared on a dash and on a
## ceiling, the two ways he can stop rising with the button still held.
func _apply_jump_hold() -> void:
	if not use_jump_hold:
		# The old model, kept switchable: cutting the jump early kills most of
		# the upward speed rather than ending a thrust.
		if state == State.JUMP and velocity.y < 0.0 and Input.is_action_just_released("jump"):
			velocity.y *= jump_cut_multiplier
		return
	if jump_hold_timer <= 0.0:
		return
	if input_locked or not Input.is_action_pressed("jump"):
		jump_hold_timer = 0.0
		return
	velocity.y = minf(velocity.y, -jump_speed)


func _try_buffered_jump() -> bool:
	if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		velocity.y = -jump_speed
		jump_hold_timer = jump_hold_time
		state = State.JUMP
		juice.on_jump()
		return true
	return false


## Which side has a wall within wall_jump_check_distance: -1 left, 1 right, 0 none.
##
## Short-circuits on the first side it finds, which is the right question for
## its original caller (_state_air's wall-jump buffer: "is there a wall on
## EITHER side to kick off"). It is the WRONG question for the squeeze/chimney
## wall-slide below, which needs to know which side specifically, and cannot
## tell "walled on the near side only" from "walled on both" -- see
## _walled_both_sides(), which answers that instead.
func _near_wall_dir() -> int:
	if test_move(global_transform, Vector2(-wall_jump_check_distance, 0.0)):
		return -1
	if test_move(global_transform, Vector2(wall_jump_check_distance, 0.0)):
		return 1
	return 0


## True only when there is solid within wall_jump_check_distance on BOTH
## sides at once -- the genuine one-cell-chimney situation the squeeze
## wall-slide below is built for ("he is against both walls at once and
## there is no steering off either of them").
##
## This is NOT the same question _near_wall_dir() answers. That function
## checks left, and RETURNS the moment it finds something -- correct for "is
## there a wall on either side" (the wall-jump buffer), wrong for deciding
## whether he is truly PINNED. A one-cell shaft that is only two-sided for a
## few pixels before one wall drops away (a stair tread's lip, say) reads as
## walled via _near_wall_dir() the whole time he is anywhere near the lip,
## because it never even checks the other side once the first test_move
## succeeds. Measured: that let a squeeze-triggered slide lock onto the
## SHORT-LIVED side and then, because the squeeze continuation check trusts
## "he can't steer off either wall" and skips is_on_wall() entirely (it has
## to -- see the note there), keep reporting WALL_SLIDE for several frames
## while he drifted into open air on that side, is_on_wall() already false,
## with the real wall still standing untouched on the other side the whole
## time.
func _walled_both_sides() -> bool:
	return test_move(global_transform, Vector2(-wall_jump_check_distance, 0.0)) \
		and test_move(global_transform, Vector2(wall_jump_check_distance, 0.0))


func _do_wall_jump(from_wall_dir: int) -> void:
	jump_buffer_timer = 0.0
	wall_coyote_timer = 0.0
	velocity = Vector2(-from_wall_dir * wall_jump_speed_x, -jump_speed)
	jump_hold_timer = jump_hold_time
	wall_lock_timer = wall_jump_lock_time
	wall_jump_timer = wall_jump_anim_time
	state = State.JUMP
	juice.on_jump()


func _try_dash() -> bool:
	if not has_dash:
		return false  # ability not unlocked yet (see Level 1's Rumi scene)
	if sliding():
		return false  # the slide owns him until he is out of it
	if climbing():
		return false  # the ladder owns him until he lets go (jump)
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
	# The dash takes over from the jump entirely: a thrust still running when it
	# ends would re-launch him out of the top of it with the button still held.
	jump_hold_timer = 0.0
	dash_available = false
	dash_timer = dash_time
	dash_cooldown_timer = dash_time + dash_cooldown
	freeze_timer = dash_freeze_time
	state = State.DASH
	juice.on_dash_start(dash_dir)
	return true


## Transitions that depend on what move_and_slide() just discovered.
func _post_move(was_on_floor: bool, input_x: float, incoming_vel_y: float) -> void:
	# Hitting a ceiling ends the jump's thrust. Without this the hold keeps
	# re-asserting -jump_speed against a collision that keeps zeroing it, and he
	# sticks to the underside of the platform for the rest of jump_hold_time.
	if is_on_ceiling():
		jump_hold_timer = 0.0
	if state == State.DASH or state == State.DEAD:
		return
	if is_on_floor():
		dash_available = true  # dash refreshes on landing
		if state == State.FALL or state == State.JUMP or state == State.WALL_SLIDE:
			juice.on_land(incoming_vel_y)
			state = State.RUN if input_x != 0.0 else State.IDLE
		_keep_footing()
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
		# In a one-cell slot he is against both walls at once and there is no
		# steering off either of them, so the usual "let go and you fall" does not
		# apply — he rides it down until he leaves the slot or heads back up.
		#
		# "Against both walls" has to be CHECKED, not assumed from squeezing
		# alone: squeezing only means his narrowed box still doesn't fit at full
		# width, which one lingering wall can cause on its own (see
		# _walled_both_sides()'s own note). Skipping to is_on_wall() instead is
		# not an option either — in a genuine chimney there is a pixel of
		# clearance either side and it is FALSE the whole way down (see the FALL
		# branch below) — so this checks proximity on both sides at once, which
		# is true throughout a real chimney and false the moment only one side
		# still has anything.
		if squeezing:
			if velocity.y < 0.0 or not _walled_both_sides():
				state = State.FALL
		# Let go, ran out of wall, moving up, or facing away from the wall -> back to normal air.
		elif not is_on_wall() or input_x * wall_dir <= 0.0 or velocity.y < 0.0 or facing != wall_dir:
			state = State.FALL
	elif state == State.FALL:
		# A slot is a chimney, and he goes down it as one WITHOUT being asked.
		# Dropping straight down the middle of a one-cell shaft never touches
		# either wall — there is a pixel of clearance on both sides — so
		# is_on_wall() is false all the way down and the ordinary rule below
		# would let him free-fall between two walls he is practically resting on.
		#
		# Entry requires _walled_both_sides(), not just _near_wall_dir() != 0.
		# _near_wall_dir() short-circuits on whichever side it checks first
		# (left), so a slot that is only two-sided for a few pixels — a stair
		# tread's lip ending right where a real wall continues past it — reads
		# as walled the whole time he is near the lip, and locks wall_dir onto
		# the side about to vanish rather than the wall that is actually there.
		# Requiring both sides confirms this is a real pinch, not a coincidence
		# of check order.
		if squeezing and velocity.y > 0.0 and _walled_both_sides():
			wall_dir = _near_wall_dir()
			state = State.WALL_SLIDE
			velocity.y = minf(velocity.y, wall_slide_max_speed)
		# Falling, touching a wall, pushing into it, and facing it -> wall slide.
		elif velocity.y > 0.0 and is_on_wall_only():
			var wd := -signf(get_wall_normal().x)
			if input_x != 0.0 and signf(input_x) == wd and facing == int(wd):
				wall_dir = int(wd)
				state = State.WALL_SLIDE
				velocity.y = minf(velocity.y, wall_slide_max_speed)


## Going down a one-cell slot: the whole of it.
##
## He is exactly one cell wide and so is a one-cell hole, and Godot resolves two
## exactly-abutting AABBs as a collision — so without this a hole like that holds
## him up on its lip, standing on eight pixels of nothing with every drawn pixel
## of him over the gap. That is the picture this exists to stop.
##
## A hole in the floor takes him, so this needs no input: stand over one and he
## turns side-on and goes down it. His box is only narrowed while he is in it,
## which is what keeps him a full cell everywhere else — a permanently thinner
## Hooshang would slip through gaps nobody meant as a route. He comes back to
## full width by TRYING it — every frame, with the wide box, against the world —
## so nothing has to remember where the slot ended or notice him leaving it.
func _tick_squeeze() -> void:
	if squeezing:
		_try_stand_up()
		return
	if not is_on_floor():
		return
	var mid := _slot_under()
	if is_inf(mid):
		return
	squeezing = true
	_set_box_width(squeeze_width)
	# Put down the MIDDLE of the hole rather than dropped from wherever he
	# happened to be standing. Six in eight leaves a pixel either side, and
	# whether he fits should not come down to where his foot landed.
	global_position.x += mid
	# His run does not survive the drop. There is nowhere to run to in a one-cell
	# shaft, and carrying the speed in just bounces him off the far wall.
	velocity.x = 0.0
	state = State.FALL


## Back to full width the moment the world has room for it.
##
## `recovery_as_collision` is the whole of this and it is not optional. With it
## off — the default, and what this did — `test_move` runs Godot's depenetration
## first and only reports what is left over, so a box buried HALF A PIXEL in the
## brick either side is pushed back out and comes back clean. Measured on
## Level_1's shaft, the answer was not even monotonic: at the mouth, a 6 and a 7
## fitted, an 8 collided, and a 9 and a 10 "fitted" again.
##
## That is exactly the width he grew through. At 8 he happened to abut the two
## walls to the pixel, which is a contact and not a penetration, so there was
## nothing to recover and the collision was reported — the squeeze held and he
## went down the shaft on the strength of a coincidence. At 9 he penetrates,
## gets recovered, stands up on the lip, falls the tenth of a pixel gravity
## gives him, squeezes, stands up again, and rides that loop forever a whole
## body-height above the hole he is supposed to be dropping down.
##
## With recovery counted the answer is the plain one at every width and every
## depth: 6 and 7 fit that shaft, 8 and up do not.
func _try_stand_up() -> void:
	_set_box_width(_box_width)
	if test_move(global_transform, Vector2.ZERO, null, 0.08, true):
		_set_box_width(squeeze_width)   # still in it
		return
	squeezing = false


func _set_box_width(w: float) -> void:
	if _box != null:
		_box.size.x = w


## The centre of the one-cell hole he is standing over, as an offset from his
## own centre — or INF if what is under him is not one.
##
## Probed with the footing ray rather than read off the tilemap, because this has
## to work over a platform prop and a room seam as much as over painted brick and
## none of those are the same object. Both walls have to be FOUND: running out of
## probe on either side means he is at the edge of a drop, not bridging a slot,
## and a drop is not something you squeeze into.
func _slot_under() -> float:
	if _ground_under(0.0):
		return INF                          # solid under his middle: no hole
	var left := 0.0
	while left > -squeeze_probe and not _ground_under(left - squeeze_step):
		left -= squeeze_step
	if left <= -squeeze_probe:
		return INF
	var right := 0.0
	while right < squeeze_probe and not _ground_under(right + squeeze_step):
		right += squeeze_step
	if right >= squeeze_probe:
		return INF
	# The hole runs from one found wall to the other, a probe step either side of
	# the last clear reading.
	if right - left + squeeze_step < squeeze_width + squeeze_step:
		return INF                          # too tight even side-on
	return (left + right) * 0.5


## Slide him off a ledge he no longer has his footing on.
##
## Called only while he is on the floor. If there is ground within footing_width
## of his centre he is standing properly and nothing happens; otherwise he is
## overhanging and gets nudged the way he is already falling, until his hitbox
## clears the ledge and ordinary gravity takes him.
##
## Position is moved directly rather than through velocity. The slide is not
## something he is doing, so it must not be steerable, must not survive into the
## fall as momentum, and must not be scrubbed by his own ground deceleration on
## the frame it is applied — all three of which happen if it goes into velocity.x.
func _keep_footing() -> void:
	if footing_width <= 0.0 or _ground_under(0.0):
		return
	# Which side is still holding him up. Probed just BEYOND the hitbox rather
	# than at its edge: at maximum overhang his box meets the ledge along a
	# single line, and a probe sitting exactly on that line is asking whether a
	# tile boundary counts as solid — which it does not, reliably. A pixel
	# further out is unambiguously over the ledge or over open air, and without
	# that this whole check found no supported side and did nothing at all.
	var slip := 0.0
	var half := _box.size.x * 0.5 if _box != null else HALF_WIDTH
	var on_left := _ground_under(-(half + 1.0))
	var on_right := _ground_under(half + 1.0)
	# BRIDGING, not overhanging. Ground on both sides and none under his middle
	# is a slot in the floor, and he is standing across it with his weight on
	# both edges — nothing to slide off. Without this he gets shoved sideways at
	# ledge_slip_speed the moment he steps over a one-cell hole, which is both
	# wrong to look at and enough to push him off the slot he is trying to drop
	# down (see _tick_squeeze).
	if on_left and on_right:
		return
	if on_left:
		slip = 1.0            # ground behind on the left: he is going off to the right
	elif on_right:
		slip = -1.0
	if slip == 0.0:
		return                # nothing under him at all; gravity has this
	global_position.x += slip * ledge_slip_speed * get_physics_process_delta_time()


## Is there solid ground just below his feet, `dx` px to the side of his centre?
##
## A ray rather than test_move, because test_move uses the whole 9px-wide body
## and the whole point here is to ask about a narrower footprint than the one
## Godot supports him on.
func _ground_under(dx: float) -> bool:
	return _floor_collider_at(dx) != null


## The collider directly below his feet, `dx` px to the side of his centre — or
## null if the ray finds nothing there. Split out from _ground_under because
## is_on_solid_ground needs to know WHAT was found, not just that something was.
func _floor_collider_at(dx: float) -> Object:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dx, HALF_HEIGHT - 1.0)
	var query := PhysicsRayQueryParameters2D.create(
		from, from + Vector2(0.0, footing_width + 2.0), collision_mask)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return hit.get("collider") if not hit.is_empty() else null


## Is he on the floor, and is what he is standing on actually going to stay
## there? A CrumblingPlatform is on layer 1 like everything else he can stand
## on, so is_on_floor() alone cannot tell a real floor from a ledge that is
## about to give way out from under him. Used by Lemon's strawberry-rule
## landing check: a fruit grabbed on the way down should not bank on a panel
## that is itself mid-collapse.
##
## Probed at his centre AND both edges — the same spread _keep_footing uses —
## not just his centre. A single centre ray used to say "solid" every time it
## found NOTHING at all, on the theory that no collider in the way meant no
## crumbling one either. That is exactly backwards astride the SEAM between two
## adjacent CrumblingPlatforms: his centre ray drops straight through the gap
## between their boxes, finds nothing, and used to read that miss as solid
## ground — which is how walking from one collapsing platform onto another
## banked a lemon without his feet ever finding brick. A miss now counts for
## nothing; only an actual non-crumbling collider does, and the edge probes
## catch what the centre one fell through.
func is_on_solid_ground() -> bool:
	if not is_on_floor():
		return false
	var half := _box.size.x * 0.5 if _box != null else HALF_WIDTH
	for dx in [0.0, -half, half]:
		var collider := _floor_collider_at(dx)
		if collider != null and collider is not CrumblingPlatform:
			return true
	return false


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
		State.CLIMB:
			# The one clip drawn from BEHIND rather than in profile — he faces
			# into the ladder, away from the camera, which a side view cannot
			# show. flip_h above still applies to it harmlessly (a back view
			# mirrors near-symmetrically either way).
			#
			# One clip, played BACKWARDS for the way down rather than a second
			# generation — a climb is symmetric, reaching up to go up and
			# reaching up (in reverse) to lower himself down. speed_scale's
			# sign picks the direction; play("climb") is safe to call every
			# frame here (same-name replay does not reset the frame or
			# speed_scale — verified empirically, not from the docs), and
			# pausing right after it is what freezes him mid-reach the instant
			# he stops climbing rather than looping in place like a treadmill.
			visual.play("climb")
			# velocity.y < 0 is UP (screen -y): the clip was authored reaching
			# up, so that direction is forward; > 0 is down, played in reverse.
			visual.speed_scale = 1.0 if velocity.y < 0.0 else -1.0
			if is_zero_approx(velocity.y):
				visual.pause()
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
	if state == State.DEAD or invulnerable_timer > 0.0:
		return
	state = State.DEAD
	velocity = Vector2.ZERO
	visible = false
	# Snaps off rather than lingering into the respawn — the lemon it cost is
	# not refunded, same as every other run stat death does not undo.
	_lemon_glow_timer = 0.0
	_apply_lemon_glow()
	# Same snap for an eaten mushroom's power — its world-side effects (a
	# suppressed thought glow, see _end_mushroom_power) must not survive into
	# a room he has not earned the immunity in yet.
	if _mushroom_power_timer > 0.0:
		_mushroom_power_timer = 0.0
		_end_mushroom_power()
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
	jump_hold_timer = 0.0
	invulnerable_timer = 0.1
	# Full width again. A life that starts squeezed starts him thinner than the
	# grid, in a room that may have nothing narrow in it at all.
	squeezing = false
	_set_box_width(_box_width)
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


## Hand him a hard upward launch — a spring platform's bounce, not a jump he
## chose. Same shape as add_momentum (a method rather than a prop writing
## velocity.y itself, STYLE_GUIDE §4), but for the vertical axis: nothing else
## in player.gd currently injects vertical velocity from outside.
##
## Lands him in State.JUMP so the existing rise/fall/apex gravity flies the arc
## exactly like a real jump — no new gravity or height code. Deliberately does
## NOT set jump_hold_timer, so _apply_jump_hold() has nothing to hold: the
## bounce is one fixed impulse, un-extendable by holding the button, which is
## what keeps it reading as the platform launching him rather than an ordinary
## jump that happened to start high. Buffer/coyote timers are cleared so a jump
## queued just before landing can't fight the launch on the very next frame.
func bounce(vy: float) -> void:
	if state == State.DEAD:
		return
	velocity.y = -absf(vy)
	jump_hold_timer = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	state = State.JUMP


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


# --------------------------------------------------------------- ladders ----
# The API a Ladder drives him through (scenes/props/zones/ladder.gd). The
# ladder decides who is gripping it and when; this node is the only thing
# that moves him while he climbs.

func climbing() -> bool:
	return ladder_zone != null


## Grip a ladder: gravity off, steering locked to the rail at `center_x`, and
## vertical speed answers move_up/move_down directly (see _state_climb). The
## ladder calls this — touching it and reaching up or down — the same split
## enter_slide uses; this node only does the moving.
func enter_ladder(zone: Node, center_x: float) -> void:
	if state == State.DEAD or climbing():
		return
	ladder_zone = zone
	ladder_x = center_x
	velocity = Vector2.ZERO
	state = State.CLIMB


## Let go, if `zone` is the one holding him — mirrors exit_slide. The check
## matters for the same reason it does there: two ladders close enough to
## overlap should not let the one he already left steal the release.
func exit_ladder(zone: Node) -> void:
	if ladder_zone == zone:
		_clear_ladder()


func _clear_ladder() -> void:
	ladder_zone = null
	if state == State.CLIMB:
		state = State.FALL


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


## Hold the camera at a sustained rattle of `amplitude` px — the building groaning
## around him — until something sets it again. 0 turns it off.
##
## A THIRD verb rather than a long rumble(), because it is a different KIND of
## thing: shake() is one knock and rumble() is a run that ends, and those two
## share a tween where each call kills the last. This is a level, held and
## re-stated per frame by whoever is describing the room (CollapseAmbience), and
## it stacks with the other two instead of replacing them — see Juice.set_tremor.
func tremor(amplitude: float) -> void:
	juice.set_tremor(amplitude)


## Freeze him mid-scene: no input, no gravity, no state machine, exactly where he
## stands. Comes back with velocity cleared, so a hold during a fall doesn't hand
## control back to a player who is suddenly moving at terminal speed.
##
## `input_locked` alone is not this — that takes his controls away and leaves him
## falling, which is right for a cutscene he walks into and wrong for one where
## the floor is the thing being dramatic (or, same idea, one where he might
## still be carrying run speed or a jump arc the instant a trigger fires and
## visibly slides or sails through the first moment of it — see freeze()).
func hold(seconds: float) -> void:
	if seconds <= 0.0:
		return
	freeze()
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		return
	unfreeze()


## freeze()/unfreeze() split out of hold() so a beat of INDETERMINATE length —
## a Rumi conversation, dismissed at the player's own pace rather than after a
## fixed number of seconds — can use the exact same hard stop. hold() above is
## just these two calls either side of a timer.
##
## Re-entrant on the physics side (calling freeze() again while already frozen
## is a harmless no-op), but the pair is not designed to NEST with a bare
## `input_locked = ...` assignment in between — whichever call made this
## true is the one whose unfreeze() should run.
var _frozen := false
var _pre_freeze_locked := false


func freeze() -> void:
	if _frozen:
		return
	_frozen = true
	_pre_freeze_locked = input_locked
	input_locked = true
	velocity = Vector2.ZERO
	set_physics_process(false)


func unfreeze() -> void:
	if not _frozen:
		return
	_frozen = false
	set_physics_process(true)
	velocity = Vector2.ZERO
	input_locked = _pre_freeze_locked


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
	glow_light.texture_scale = (glow_radius_cells * 8.0) / TEXTURE_RADIUS


## The 'z' ability: spend one lemon for lemon_glow_time seconds of light.
## Ignored while one is already running rather than refreshing it — pressing
## again mid-glow costs nothing and buys nothing, so a nervous extra tap near
## the end can't be mistaken for a second purchase.
func _try_lemon_glow() -> void:
	if _lemon_glow_timer > 0.0:
		return
	if not Collectibles.spend(1):
		return
	_lemon_glow_timer = lemon_glow_time
	_apply_lemon_glow()


## Push the timer onto LemonGlowLight: off, steady, or blinking through the
## last lemon_glow_flicker_time seconds. Called every tick while the timer is
## running and once from _ready so the light matches a timer of 0 at rest.
##
## PAINT, NOT A LIGHT — LemonGlowLight is a Sprite2D, not a PointLight2D, and
## that is the fix for "the glow only shows up in shadow". A real Light2D
## MULTIPLIES the surface it falls on, so it visibly brightens an unlit
## stretch of room and does almost nothing crossing an already-lit patch near
## a lamp or ceiling panel — which reads as exactly that complaint, patchy and
## shadow-only, instead of a steady glow that follows him everywhere. It also
## competes for this renderer's per-canvas-item light cap (16, see
## DarkThought's own note on this), so a room already busy with fixtures can
## drop it in silence. An UNSHADED, ADDITIVELY BLENDED sprite adds flat
## instead, so it looks the same regardless of what is already lit beneath it,
## is exempt from that light cap, and cannot be crushed by CanvasModulate 0.05
## either (measured elsewhere in this project: the same sprite renders 0.047
## shaded vs 1.000 unshaded under it). The material is built once, here,
## rather than in the scene file, to keep the recipe in one place with the
## comment explaining it.
func _apply_lemon_glow() -> void:
	if lemon_glow_light == null:
		return
	if lemon_glow_light.material == null:
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		lemon_glow_light.material = mat
	const TEXTURE_RADIUS := 64.0
	lemon_glow_light.scale = Vector2.ONE * (lemon_glow_radius_cells * 8.0) / TEXTURE_RADIUS
	# What a light gets for free by multiplying the wall's own colour, an
	# additive sprite has to be scaled back down to match — at equal energy it
	# would otherwise land roughly 1/albedo too bright (same calibration
	# DarkThought's halo uses, off the same office-brick albedo).
	const PAINT_GAIN := 0.35
	var gain := lemon_glow_energy * PAINT_GAIN
	lemon_glow_light.modulate = Color(
		lemon_glow_color.r * gain, lemon_glow_color.g * gain,
		lemon_glow_color.b * gain, 1.0)
	var on := _lemon_glow_timer > 0.0
	var lit := on
	if on and _lemon_glow_timer <= lemon_glow_flicker_time:
		# Half the cycle lit, half dark. Driven off the timer itself rather
		# than an accumulating clock, so it can be set directly (as the test
		# does) without ticking through real seconds first.
		var phase := fmod(_lemon_glow_timer, 1.0 / lemon_glow_flicker_speed)
		lit = phase >= 0.5 / lemon_glow_flicker_speed
	lemon_glow_light.visible = lit


## Eat a mushroom's power. Its own timer, not a rebinding of anything else —
## a second mushroom simply refills it to the full duration rather than being
## ignored, unlike the lemon glow's "already running" rule: a mushroom is a
## free pickup out in the world, not a spent resource, so there is nothing to
## protect against wasting.
func consume_mushroom(type: Mushroom.MushroomType) -> void:
	mushroom_power_type = type
	_mushroom_power_timer = mushroom_power_time
	if type == Mushroom.MushroomType.BLACK_WHITE:
		DarkThought.set_glow_suppressed(get_tree(), true)
	flash(Color(2.2, 2.2, 2.6))


## True while an eaten mushroom's power makes a thought hazard harmless to
## touch — dark/light clouds pass through (dark_thought.gd's _on_body_entered
## override), a grey one dissolves on contact instead of killing (same
## override), and the paintable thought-hazard tiles stop killing
## (ldtk_world.gd's _in_thought_tile check).
func has_thought_immunity() -> bool:
	return _mushroom_power_timer > 0.0 \
		and mushroom_power_type == Mushroom.MushroomType.BLACK_WHITE


## The power's world-side effects, undone — called when its timer reaches 0,
## whether that is the countdown running out or a death cutting it short.
func _end_mushroom_power() -> void:
	if mushroom_power_type == Mushroom.MushroomType.BLACK_WHITE:
		DarkThought.set_glow_suppressed(get_tree(), false)


## Clamp the follow-camera to a level's bounds (pixels). Called by LevelBase.
func set_camera_limits(bounds: Rect2i) -> void:
	camera.limit_left = bounds.position.x
	camera.limit_top = bounds.position.y
	camera.limit_right = bounds.end.x
	camera.limit_bottom = bounds.end.y
