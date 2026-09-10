extends Node
## Pond: a swimmable body of water. Falling in switches him to SWIM, buoyancy
## carries him up when he does nothing, jump pops him toward the surface
## without launching a real jump, dash and the normal ground/air physics are
## gone until he is out, and leaving through either edge (or dying inside it)
## hands full control straight back — the same "control comes back" contract
## slide_test.gd already proves for SlideZone, aimed at the newer zone.
##
## Built on a bare Node2D with a directly-instantiated Player, the same shape
## mystery_box_test.gd/magic_carpet_test.gd use, rather than loading the whole
## Act2World — a pond zone itself needs no floor collision (see pond.gd's own
## class doc), but proving jump comes BACK once he is clear of the water
## needs somewhere solid for him to land on first, so OUT gets one small
## StaticBody2D floor of its own.
##
## Run:  godot --headless res://tests/pond_test.tscn

const POND_SCENE := preload("res://scenes/props/zones/Pond.tscn")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")

## Comfortably inside a mid-sized pond, and IN itself deep enough that a
## surface pop or a settling frame can't accidentally carry him clear of the
## box mid-measurement.
const POND_SIZE := Vector2(96.0, 64.0)
const POND_POS := Vector2(400.0, 400.0)
const IN := POND_POS
const OUT := POND_POS + Vector2(0.0, 200.0)  # well clear, below the box
const FLOOR_SIZE := Vector2(400.0, 40.0)

## A BANK against the pond's right edge, its top flush with the waterline —
## the shape Act 2's own painted water actually has (measured off
## Act_2_Level_0's tilemap: a brick pit whose walls run the full depth and
## stop level with the surface). There is deliberately no submerged shelf to
## land on here, because there is none there: the climb-out has to be a move
## he makes out of the water, not a landing physics happens to hand him.
## Full depth, not just the top few cells: a wall that stops partway down
## leaves open water beside it, and "pushing into the bank from the bottom"
## would then measure him swimming straight OUT of the pond rather than
## being refused the climb.
const BANK_SIZE := Vector2(40.0, POND_SIZE.y)
## Far enough left of the bank that he has to actually SWIM into it, so the
## check covers the approach and not just a contrived touching start.
const NEAR_BANK := Vector2(430.0, 375.0)
const DEEP_BY_BANK := Vector2(430.0, 425.0)

var failures: Array[String] = []
var world: Node2D
var player: Player
var pond: Area2D


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	player = PLAYER.instantiate()
	world.add_child(player)
	player.input_locked = false
	player.has_dash = true

	# A floor under OUT only — its top surface sits exactly at OUT's own y
	# plus his half-height, so centring him on OUT rests his feet on it with
	# no fall to wait out (jump/coyote both key off is_on_floor(), which a man
	# hanging in a fall a few px above ground would not yet have).
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1  # world
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = RectangleShape2D.new()
	floor_shape.shape.size = FLOOR_SIZE
	floor_body.add_child(floor_shape)
	floor_body.position = OUT + Vector2(0.0, Player.HALF_HEIGHT + FLOOR_SIZE.y * 0.5)
	world.add_child(floor_body)

	var bank := StaticBody2D.new()
	bank.collision_layer = 1  # world
	bank.collision_mask = 0
	var bank_shape := CollisionShape2D.new()
	bank_shape.shape = RectangleShape2D.new()
	bank_shape.shape.size = BANK_SIZE
	bank.add_child(bank_shape)
	# Left face on the pond's right edge; equal heights put its top face
	# exactly on the waterline.
	bank.position = POND_POS + Vector2(POND_SIZE.x * 0.5 + BANK_SIZE.x * 0.5, 0.0)
	world.add_child(bank)

	pond = POND_SCENE.instantiate()
	pond.size = POND_SIZE
	world.add_child(pond)
	pond.global_position = POND_POS
	await _frames(4)

	# --- outside it, he is himself ---
	await _settle(OUT)
	_check(not player.swimming(), "clear of the pond he is not swimming")
	var free_jump := await _jump_rise()
	_check(free_jump > 8.0, "and can jump  [rose %.0fpx]" % free_jump)

	# --- falling into it switches him to SWIM, with no input needed ---
	_release_all()
	player.global_position = POND_POS + Vector2(0.0, -60.0)
	player.velocity = Vector2(0.0, 40.0)  # already falling
	await _frames(20)
	_check(player.swimming() and player.state_name() == "SWIM",
		"falling into it starts a swim  [state %s]" % player.state_name())

	# --- a big jump-in speed is caught immediately, not bled off gradually ---
	await _settle(OUT)  # clear of the pond, plain FALL, before diving back in
	await _wait_out_exit_water()  # OUT's floor plays the climb-out clip too
	_release_all()
	player.global_position = POND_POS  # already inside when the fast fall lands
	player.velocity = Vector2(0.0, 400.0)  # jumped in from well above
	# A plain global_position assignment (not move_and_slide) lags Pond's own
	# overlap monitoring cache by a couple of physics steps — CLAUDE.md's own
	# documented gotcha on this exact teleport pattern — so enter_swim() does
	# not fire on the very next frame. Measured: frame 0 still reads the raw
	# 400, frame 1 shows plain FALL's own max_fall_speed clamp (unrelated to
	# swimming) already cutting it to 220, and enter_swim()'s OWN clamp to
	# swim_max_sink_speed only lands on frame 2.
	await _frames(3)
	_check(player.swimming() and player.velocity.y <= player.swim_max_sink_speed + 0.5,
		"a fast entry is capped the instant he hits the water, not eased in over time  [%.1f px/s]"
			% player.velocity.y)

	# --- buoyancy: doing nothing drifts him up ---
	await _settle(IN)
	await _frames(20)
	_check(player.velocity.y < -1.0,
		"neutral input rises on buoyancy alone  [%.1f px/s]" % player.velocity.y)
	_check(absf(player.velocity.y - (-player.swim_buoyancy)) < 3.0,
		"...settling near swim_buoyancy, not runaway or zero  [%.1f vs -%.1f]" % [
			player.velocity.y, player.swim_buoyancy])
	_check(player.visual.animation == "swim_idle",
		"...and plays the idle float, not the active stroke  [got '%s']" % player.visual.animation)

	# --- paddling: input steers him in every direction ---
	await _settle(IN)
	Input.action_press("move_right")
	await _frames(20)
	_check(player.visual.animation == "swim",
		"holding a direction switches to the active stroke  [got '%s']" % player.visual.animation)
	Input.action_release("move_right")
	_check(player.velocity.x > 10.0,
		"holding right builds rightward speed  [%.1f px/s]" % player.velocity.x)
	await _frames(10)

	await _settle(IN)
	Input.action_press("move_up")
	await _frames(15)
	var up_speed: float = player.velocity.y
	Input.action_release("move_up")
	_check(up_speed < -player.swim_buoyancy,
		"holding up rises faster than buoyancy alone  [%.1f vs -%.1f]" % [
			up_speed, player.swim_buoyancy])

	await _settle(IN)
	Input.action_press("move_down")
	await _frames(30)
	var down_speed: float = player.velocity.y
	Input.action_release("move_down")
	_check(down_speed <= player.swim_max_sink_speed + 0.5,
		"holding down is capped at swim_max_sink_speed  [%.1f of %.1f]" % [
			down_speed, player.swim_max_sink_speed])

	# --- orientation: the visual's own body axis tilts to face the stroke,
	# not just its stroke-reach axis (which would keep him upright even
	# swimming sideways — see _swim_visual_angle's own doc for why that
	# reading is wrong) ---
	await _settle(IN)
	Input.action_press("move_right")
	await _frames(30)
	_check(absf(player.visual.rotation - PI / 2.0) < 0.05,
		"swimming right lays him horizontal, head leading  [%.1f deg]"
			% rad_to_deg(player.visual.rotation))
	Input.action_release("move_right")

	await _settle(IN)
	Input.action_press("move_up")
	await _frames(30)
	_check(absf(player.visual.rotation) < 0.05,
		"swimming straight up keeps the clip's own upright pose  [%.1f deg]"
			% rad_to_deg(player.visual.rotation))
	Input.action_release("move_up")

	await _settle(IN)
	Input.action_press("move_up")
	Input.action_press("move_right")
	await _frames(30)
	_check(absf(player.visual.rotation - PI / 4.0) < 0.05,
		"a diagonal stroke tilts exactly halfway between  [%.1f deg]"
			% rad_to_deg(player.visual.rotation))
	Input.action_release("move_up")
	Input.action_release("move_right")

	await _settle(IN)
	await _frames(40)
	_check(absf(player.visual.rotation) < 0.05,
		"letting go levels the idle float back out  [%.1f deg]"
			% rad_to_deg(player.visual.rotation))

	# --- jump underwater pops him up without becoming a real jump ---
	await _settle(IN)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(player.state_name() == "SWIM",
		"jump underwater stays in SWIM, not JUMP  [state %s]" % player.state_name())
	_check(player.velocity.y < -50.0,
		"...and gives him a real kick toward the surface  [%.1f px/s]" % player.velocity.y)

	# --- dash does nothing while swimming ---
	await _settle(IN)
	var dashed := await _tried_dash()
	_check(not dashed, "dash does nothing in the water  [state %s]" % player.state_name())

	# --- and he gets it all back on the way out ---
	await _settle(OUT)
	_check(not player.swimming(), "stepping clear of the pond ends the swim")
	# OUT's floor sits right where he lands, so this is exactly "reached a
	# bank" (see player.gd's exit-swim-grace doc) — the climb-out clip should
	# hold control for a beat rather than handing it back instantly.
	_check(player.state_name() == "EXIT_WATER",
		"...and reaching solid ground plays the climb-out clip  [state %s]" % player.state_name())
	await _wait_out_exit_water()
	_check(player.state_name() != "EXIT_WATER", "...which lets go on its own")
	var after_jump := await _jump_rise()
	_check(after_jump > 8.0, "and he can jump again once it finishes  [rose %.0fpx]" % after_jump)

	# --- the OTHER climb-out: swimming into a bank, with nothing to land on ---
	#
	# The grace-window path just above can only dress up a landing physics was
	# already going to make. Against a real bank there is no such landing (see
	# BANK_SIZE's own note), and this is the path that has to carry him out:
	# treading water at the surface, pushing into the brick.
	await _settle(NEAR_BANK)
	_check(player.swimming(), "treading water beside a bank, he is swimming")
	Input.action_press("move_right")
	var reached_climb := await _wait_for_state("EXIT_WATER", 60)
	_check(reached_climb, "swimming INTO a bank commits the climb-out  [state %s]"
		% player.state_name())
	await _wait_out_exit_water()
	Input.action_release("move_right")
	await _frames(6)
	_check(not player.swimming(), "...and it actually gets him out of the water")
	_check(player.is_on_floor() and player.global_position.y < POND_POS.y - POND_SIZE.y * 0.5,
		"...standing on top of the bank, above the waterline  [y %.1f, surface %.1f]"
			% [player.global_position.y, POND_POS.y - POND_SIZE.y * 0.5])

	# ...but ONLY from the surface. Without the depth gate the same press
	# would haul him up a submerged wall like a ladder from the pond floor.
	await _settle(DEEP_BY_BANK)
	Input.action_press("move_right")
	await _frames(45)
	Input.action_release("move_right")
	_check(player.state_name() == "SWIM",
		"pushing into that same bank from DEPTH does not climb it  [state %s]"
			% player.state_name())

	# --- he floats at a RESTING depth, and holds it without flickering ---
	#
	# Both halves regression-guard the same defect, which is worth stating
	# plainly because it presented as three unrelated bugs in play: buoyancy
	# used to be unconditionally upward with nothing to settle against, so he
	# rose until his own centre left the water, dropped to FALL, fell back in,
	# and repeated ~3x/second. That flicker is what slid him down walls (WALL_
	# SLIDE is only reachable from FALL), what let real gravity sink him to
	# the floor a frame at a time, and what snapped the sprite between the
	# swim and fall clips several times a second.
	await _settle(POND_POS + Vector2(0.0, -POND_SIZE.y * 0.5 + 2.0))
	await _frames(60)
	# Typed by hand: `pond` is held as a plain Area2D here, so surface_y_at is
	# duck-typed and infers as Variant (the same reason player.gd reaches it
	# through has_method rather than a class check).
	var depth: float = player.global_position.y - pond.surface_y_at(player.global_position)
	_check(absf(depth - player.swim_float_depth) < 1.5,
		"an idle float settles at swim_float_depth below the surface  [%.1fpx, want %.1f]"
			% [depth, player.swim_float_depth])
	var churn := await _state_churn(120)
	_check(churn == 0, "...and holds it without flickering out of SWIM  [%d state changes in 120 frames]"
		% churn)

	# --- dying inside it does not carry the swim into the next life ---
	await _settle(IN)
	_check(player.swimming(), "swimming once more, to die in it")
	player.die()
	await _frames(4)
	player.respawn(OUT)
	await _frames(4)
	_check(not player.swimming(), "respawning clear of it gives control back  [at %s]"
		% player.global_position)

	# ...and a checkpoint UNDER the pond still starts a swim. He never crosses
	# the boundary on that path, so body_entered never fires (there is no such
	# signal wired here anyway — see pond.gd's own note on why this polls
	# instead) — the pond has to notice him standing in it, and respawn() has
	# to have actually cleared swim_zone or this reads as stuck in FALL
	# forever (see player.gd's respawn() note on exactly this bug).
	player.die()
	await _frames(4)
	player.respawn(IN)
	await _frames(12)
	_check(player.swimming(),
		"respawning INSIDE it starts swimming again  [state %s]" % player.state_name())
	await get_tree().create_timer(player.death_time + 0.2).timeout

	# --- the LDtk side: fields, and what happens without them ---
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()
	var built: Area2D = importer._build_pond({
		"position": Vector2(8.0, 4.0), "size": Vector2i(64, 32),
		"fields": {"FishCount": 5.0}})
	_check(built.position == Vector2(8.0, 4.0) and built.size == Vector2(64.0, 32.0),
		"the importer places and sizes it from LDtk  [%s %s]" % [built.position, built.size])
	_check(built.fish_count == 5,
		"...and reads FishCount, rounded from the float field  [%d]" % built.fish_count)
	var bare: Area2D = importer._build_pond({
		"position": Vector2.ZERO, "size": Vector2i(32, 16), "fields": {}})
	_check(bare.fish_count == 3,
		"an unset FishCount falls back to the prefab default, not zero  [%d]"
			% bare.fish_count)
	built.free()
	bare.free()

	# --- the water is visibly laid out, and fish are actually spawned ---
	var water: Node2D = pond.get_node("Water")
	var expected_cols := int(round(POND_SIZE.x / 8.0))
	var expected_rows := int(round(POND_SIZE.y / 8.0))
	_check(water.get_child_count() == expected_cols * expected_rows,
		"the water sheet tiles the whole box  [%d cells, expected %d]" % [
			water.get_child_count(), expected_cols * expected_rows])
	var fish_root: Node2D = pond.get_node("Fish")
	_check(fish_root.get_child_count() == pond.fish_count,
		"fish_count fish are actually spawned  [%d]" % fish_root.get_child_count())
	for child in fish_root.get_children():
		_check(child is Fish, "...and each one is a real Fish  [%s]" % child)

	if failures.is_empty():
		print("POND TEST: ALL PASS")
	else:
		print("POND TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


# ------------------------------------------------------------------ moves ----

## Put him down at `where`, clear of input, and let him settle so every
## measurement starts from a known, grounded-or-swimming state rather than
## mid-fall — generous on frames since OUT is a real floor he has to actually
## land on (unlike a slide zone's own floor, which needs no travel time at
## all when he is dropped exactly onto it).
func _settle(where: Vector2) -> void:
	_release_all()
	player.global_position = where
	player.velocity = Vector2.ZERO
	await _frames(10)


## How far he rises from a jump press, in px — the PEAK height reached over a
## generous window, not a single late snapshot. A snapshot taken too long
## after a short hold can land after the whole hop has already finished and
## he is back on the floor, which reads as "the press did nothing" for a jump
## that worked perfectly; the peak cannot be fooled by measuring late.
func _jump_rise() -> float:
	var start: float = player.global_position.y
	var peak: float = start
	Input.action_press("jump")
	for i in 6:
		await _frames(1)
		peak = minf(peak, player.global_position.y)
	Input.action_release("jump")
	for i in 20:
		await _frames(1)
		peak = minf(peak, player.global_position.y)
	await _frames(10)  # back on the floor before anything else is measured
	return start - peak


## Did a dash press actually start a dash?
func _tried_dash() -> bool:
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	var dashed := player.state_name() == "DASH"
	await _frames(10)
	return dashed


## Waits out a possible EXIT_WATER beat (player.gd), bounded rather than an
## unconditional sleep since most call sites here never trigger it at all (a
## checkpoint respawn, say, explicitly clears the grace timer).
func _wait_out_exit_water() -> void:
	for i in 60:
		if player.state_name() != "EXIT_WATER":
			return
		await _frames(1)


## Run up to `frames` physics steps, stopping the moment he reaches `want`.
## Bounded rather than a fixed wait so a climb-out that never commits fails
## as a missing state rather than as whatever he happens to be doing later.
func _wait_for_state(want: String, frames: int) -> bool:
	for i in frames:
		if player.state_name() == want:
			return true
		await _frames(1)
	return player.state_name() == want


## How many times his state changes over `frames` — the direct measure of the
## surface flicker, which is a state machine oscillating rather than any one
## wrong value that could be asserted on its own.
func _state_churn(frames: int) -> int:
	var prev := player.state_name()
	var changes := 0
	for i in frames:
		await _frames(1)
		var now := player.state_name()
		if now != prev:
			changes += 1
			prev = now
	return changes


func _release_all() -> void:
	for action in ["jump", "dash", "move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _check(ok: bool, msg: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		failures.append(msg)


## PHYSICS frames, not idle ones — see slide_test.gd's own note on why.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
