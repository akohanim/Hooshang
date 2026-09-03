extends Node
## ConveyorBelt: a stretch of floor that walks.
##
## The belt is only allowed to move him while he is STANDING on it, and it is
## only allowed to ADD to what he is already doing. Both halves fail silently in
## play: a belt that drags him through the air turns every jump across the room
## into a guess, and a belt that overwrites his velocity instead of adding to it
## looks perfectly fine until the first time somebody tries to walk back up it
## and simply cannot.
##
## Driven by the real player in the real world scene, with real input actions —
## "he can still walk against it" is a claim about the input path, and writing
## velocity by hand would test nothing about it. Distances are measured in
## physics frames, since that is what the carry is quantised to.
## Run:  godot --headless res://tests/conveyor_test.tscn

const BELT_SCENE := preload("res://scenes/props/zones/ConveyorBelt.tscn")
## Somewhere with floor under it, in room 1 — the room's own PlayerStart, which
## is by definition standing room. Same spot slide_test.gd measures from.
const FLOOR := Vector2(72.0, 248.0)

var failures: Array[String] = []
var world: LdtkWorld
var player: Player
var belt: ConveyorBelt
var tick := 60.0
var walk_velocity := 0.0  # his run speed at the end of the last _walk(), key still down


func _ready() -> void:
	tick = float(Engine.physics_ticks_per_second)
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	await _frames(30)
	player = world.player
	player.input_locked = false
	player.has_dash = true

	# --- the belts actually placed in the world ---
	# Checked BEFORE this test adds one of its own. Everything below drives a
	# belt the test built, which says nothing about whether the LDtk entity name
	# still reaches the importer — and renaming an entity is exactly the change
	# that silently drops every instance of it on the floor.
	var placed: Array[Node] = []
	_collect_belts(world, placed)
	_check(placed.size() > 0,
		"the world's own ConveyorBelt entities imported  [%d]" % placed.size())
	# What the game BUILT against what LDtk says was PLACED, counted per
	# direction. Read straight out of the .ldtk rather than off the nodes: a
	# node cannot say which entity it came from (metadata set in the import hook
	# does not survive being packed into the .scn, the same way a signal
	# connection does not), and asserting that every belt runs right was only
	# ever true while only one entity existed.
	var made := {ConveyorBelt.Direction.LEFT: 0, ConveyorBelt.Direction.RIGHT: 0}
	for p in placed:
		made[(p as ConveyorBelt).direction] += 1
	var want := _belts_in_ldtk()
	_check(made[ConveyorBelt.Direction.RIGHT] == want["right"]
			and made[ConveyorBelt.Direction.LEFT] == want["left"],
		"and each entity built the belt it names  [made %d right / %d left, "
			% [made[ConveyorBelt.Direction.RIGHT], made[ConveyorBelt.Direction.LEFT]]
			+ "placed %d / %d]" % [want["right"], want["left"]])

	# --- what the prefab promises before anything touches it ---
	belt = BELT_SCENE.instantiate()
	_check(belt.direction == ConveyorBelt.Direction.RIGHT, "a fresh belt runs Right")
	_check(is_equal_approx(belt.speed, 60.0), "at 60 px/s  [%.0f]" % belt.speed)
	_check(is_equal_approx(belt.drift(), 60.0), "drift is +speed  [%.0f]" % belt.drift())
	belt.direction = ConveyorBelt.Direction.LEFT
	_check(is_equal_approx(belt.drift(), -60.0),
		"and -speed running Left  [%.0f]" % belt.drift())
	belt.direction = ConveyorBelt.Direction.RIGHT

	# A belt long enough to be carried along without running out of it. Placed
	# from where he ACTUALLY comes to rest rather than from a guessed floor
	# height: the entity sits on the floor row, so its top edge is his feet.
	await _settle(FLOOR)
	belt.size = Vector2(192.0, 16.0)
	world.rooms[0].add_child(belt)
	belt.global_position = Vector2(
		FLOOR.x, player.global_position.y + 6.0 + belt.size.y * 0.5)
	await _frames(6)

	# --- standing on it ---
	await _stand()
	_check(belt.riders.has(player), "standing on the belt he is inside it")
	_check(belt.carrying(player), "and it is carrying him")

	var right := await _carried_over(30)
	_check(absf(right - _expect(30)) <= 2.0,
		"a Right belt carries him right at its speed  [%+.1fpx, want %+.1f]" % [
			right, _expect(30)])
	_check(absf(player.velocity.x) < 1.0,
		"and never writes his velocity to do it  [%.1f px/s]" % player.velocity.x)

	# Started further along the belt: there is a wall a dozen pixels to the left
	# of the room's PlayerStart, and a carry that stops because it ran out of
	# room is not a carry that failed.
	belt.direction = ConveyorBelt.Direction.LEFT
	var left := await _carried_over(30, FLOOR + Vector2(48.0, 0.0))
	_check(absf(left + _expect(30)) <= 2.0,
		"a Left belt carries him left  [%+.1fpx, want %+.1f]" % [left, -_expect(30)])

	belt.direction = ConveyorBelt.Direction.RIGHT
	belt.speed = 120.0
	var fast := await _carried_over(30)
	_check(absf(fast - _expect(30)) <= 3.0,
		"twice the speed carries him twice as far  [%+.1fpx, want %+.1f]" % [
			fast, _expect(30)])
	belt.speed = 60.0

	# --- he can still walk against it ---
	# The belt ADDS, it does not own him: 90 px/s of run into a 60 px/s belt is
	# 30 px/s of progress, slow but real. A belt that clamped his velocity
	# instead would pin him here forever, which is the failure this catches.
	await _stand()
	var upstream := await _walk("move_left", 24)
	_check(upstream < -2.0,
		"walking against the belt he still makes ground  [%+.1fpx]" % upstream)
	# Sampled while the key is still down (walk_velocity), not after: his run
	# decays the instant it is released, and that would pass for free.
	_check(walk_velocity <= -player.max_run_speed + 1.0,
		"because his own run is untouched by it  [%.0f of %.0f px/s]" % [
			walk_velocity, -player.max_run_speed])
	var downstream := await _walk("move_right", 24)
	_check(downstream > upstream + 8.0,
		"and going with it he is faster than going against it  [%+.1f vs %+.1f]" % [
			downstream, upstream])

	# --- airborne over it, it does nothing ---
	# The trigger is opened up first so he stays INSIDE the belt for the whole
	# jump. That is the point: "not carried" has to be because his feet left the
	# belt, not because he left the box.
	belt.rider_reach = 64.0
	await _stand()
	Input.action_press("jump")
	await _frames(4)
	var air_start: float = player.global_position.x
	var inside := belt.riders.has(player)
	var airborne := not player.is_on_floor()
	var carried_in_air := belt.carrying(player)
	var air_speed: float = player.velocity.x
	await _frames(10)
	var air_drift: float = player.global_position.x - air_start
	Input.action_release("jump")
	_check(inside and airborne, "jumping, he is airborne and still inside the belt")
	_check(not carried_in_air, "so the belt is not carrying him")
	# He DOES move — he left a moving floor and took its speed with him, which is
	# the point of the launch. What must not happen is the belt topping that up
	# frame after frame while he is over it: the handover is one payment on the
	# way out, so his speed can only fall from here.
	_check(air_drift > 0.0 and player.velocity.x <= air_speed + 0.5,
		"he carries the belt's speed on, and the belt adds no more  "
			+ "[%+.1fpx, %+.0f -> %+.0f px/s]" % [
				air_drift, air_speed, player.velocity.x])
	await _frames(30)
	belt.rider_reach = 12.0

	# --- a corpse is not carried ---
	# Same reasoning as the death-count fix: nothing should be moving him
	# between dying and respawning, least of all into the next room's hazard.
	await _stand()
	player.die()
	await _frames(2)
	_check(not belt.carrying(player), "a dead player is not carried, even standing on it")
	player.respawn(FLOOR)
	await _frames(8)

	# --- jumping off a belt takes the belt with you ---
	# Riding, the belt moves the floor under him rather than his velocity, which
	# is right until his feet leave it — at which point dropping the belt's speed
	# feels like the machine switching off the moment you ask it for anything.
	#
	# The control jump is the SAME belt with speed 0, not a patch of ordinary
	# floor somewhere else in the room: same geometry, same spot, same everything
	# except the one number under test.
	belt.speed = 0.0
	var plain := await _leap()
	var plain_takeoff := _takeoff_speed
	belt.speed = 60.0
	var launched := await _leap()
	_check(_takeoff_speed - plain_takeoff >= 50.0,
		"the belt's speed is handed over on takeoff  [%+.0f vs %+.0f px/s]" % [
			_takeoff_speed, plain_takeoff])
	# A dead-stop jump, no direction held: air drag pulls velocity back towards
	# the input, which is nothing, so most of the boost is spent in the first
	# few frames. It is still a longer jump, and this is the FLOOR of the effect
	# rather than what a player will feel.
	_check(launched - plain >= 8.0,
		"and a standing jump off a running belt carries further  [%+.1fpx vs %+.1fpx]"
			% [launched, plain])
	# Holding the way the belt runs is how anybody actually leaves one, and it is
	# where the boost lives: air control now has 150 px/s to bleed off instead of
	# 90, so it stays above his own top speed for most of the arc.
	belt.speed = 0.0
	var plain_run := await _leap("move_right")
	var plain_run_takeoff := _takeoff_speed
	belt.speed = 60.0
	var boosted_run := await _leap("move_right")
	var boosted_run_takeoff := _takeoff_speed
	_check(boosted_run - plain_run >= 15.0,
		"and running off one, further again  [%+.1fpx vs %+.1fpx]" % [
			boosted_run, plain_run])
	# Leaving in the belt's own direction pays over the odds — with_the_belt.
	# Asserted against the property rather than a hardcoded 72, so retuning the
	# bonus retunes this with it.
	var paid := boosted_run_takeoff - plain_run_takeoff
	var owed: float = belt.speed * belt.launch_transfer * (1.0 + belt.with_the_belt)
	_check(absf(paid - owed) <= 2.0,
		"jumping WITH the belt pays %d%% over its speed  [%+.0f, want %+.0f px/s]" % [
			int(round(belt.with_the_belt * 100.0)), paid, owed])

	# --- a dash is the same move on a belt as off it ---
	# Dash distance is tuned to clear specific gaps, so it cannot depend on which
	# way the floor under it happens to be running: a 60 px/s belt would add or
	# subtract 9px over the 0.15s dash, which is the difference between clearing
	# a gap and dying in it. Measured only for as long as the dash lasts, so what
	# is compared is the dash and not the drift afterwards.
	belt.speed = 0.0
	var dash_alone := await _dash_distance()
	belt.speed = 60.0
	belt.direction = ConveyorBelt.Direction.RIGHT
	var dash_with := await _dash_distance()
	belt.direction = ConveyorBelt.Direction.LEFT
	var dash_against := await _dash_distance()
	belt.direction = ConveyorBelt.Direction.RIGHT
	_check(absf(dash_with - dash_alone) <= 1.0,
		"dashing along a belt covers a normal dash  [%.1fpx vs %.1fpx]" % [
			dash_with, dash_alone])
	_check(absf(dash_against - dash_alone) <= 1.0,
		"and dashing INTO one covers exactly the same  [%.1fpx vs %.1fpx]" % [
			dash_against, dash_alone])
	# The other way, so this cannot be "jumps drift right" dressed up.
	belt.direction = ConveyorBelt.Direction.LEFT
	var leftward := await _leap()
	belt.direction = ConveyorBelt.Direction.RIGHT
	_check(leftward < plain,
		"a Left belt throws him the other way  [%+.1fpx vs %+.1fpx]" % [leftward, plain])
	# And it is a transition, not a state: a jump ACROSS a belt he never stood on
	# must not be topped up frame after frame while he passes over it.
	await _settle(FLOOR)
	player.global_position = belt.global_position + Vector2(-64.0, -40.0)
	player.velocity = Vector2.ZERO
	await _frames(2)
	var aloft: float = player.velocity.x
	await _frames(6)
	_check(absf(player.velocity.x - aloft) < 1.0,
		"passing over one without landing collects nothing  [%+.1f -> %+.1f]" % [
			aloft, player.velocity.x])
	await _settle(FLOOR)

	# --- a belt is FLOOR, not merely a trigger ---
	# THE BUG: the belt was an Area2D and nothing else, so a belt strung across a
	# gap was a machine the player dropped straight through. Every check above
	# stands him on a belt laid over the room's OWN floor, which is precisely the
	# arrangement in which a working belt and an intangible one are identical —
	# so this one is hung in the air on purpose.
	# Prove the spot is EMPTY first. The first draft of this hung the belt where
	# room 1's ceiling is, so he came to rest on the ceiling and "he landed on
	# the belt" passed against a belt that held nothing at all.
	var air := FLOOR + Vector2(0.0, -40.0)
	_release_all()
	player.global_position = air + Vector2(0.0, -24.0)
	player.velocity = Vector2.ZERO
	await _frames(40)
	_check(player.global_position.y > air.y,
		"nothing holds him at the test spot to begin with  [%.0fpx]"
			% (player.global_position.y - air.y))

	var shelf: ConveyorBelt = BELT_SCENE.instantiate()
	shelf.size = Vector2(96.0, 16.0)
	world.rooms[0].add_child(shelf)
	shelf.global_position = air
	await _frames(4)
	_release_all()
	player.global_position = air + Vector2(0.0, -24.0)
	player.velocity = Vector2.ZERO
	await _frames(40)
	var landed: float = shelf.global_position.y - player.global_position.y
	_check(player.is_on_floor() and landed > 0.0,
		"he lands ON a belt strung across a gap  [%.0fpx above it, on_floor %s]" % [
			landed, player.is_on_floor()])
	# ...and the escape hatch still works, for a belt laid over real floor where
	# a second surface would be a phantom ledge.
	shelf.solid = false
	await _frames(30)
	_check(player.global_position.y > shelf.global_position.y,
		"and drops through one told it is not floor  [%.0fpx]"
			% (player.global_position.y - shelf.global_position.y))
	shelf.queue_free()
	await _frames(2)

	# --- the LDtk side ---
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()
	var built: ConveyorBelt = importer._build_conveyor_belt({
		"position": Vector2(8.0, 4.0), "size": Vector2i(64, 16),
		"fields": {"speed": 90.0}}, ConveyorBelt.Direction.LEFT)
	_check(built.position == Vector2(8.0, 4.0) and built.size == Vector2(64.0, 16.0),
		"the importer places and sizes it from LDtk  [%s %s]" % [built.position, built.size])
	_check(built.direction == ConveyorBelt.Direction.LEFT and is_equal_approx(built.drift(), -90.0),
		"a ConveyorBelt_Left runs left  [drift %+.0f]" % built.drift())
	var rightward: ConveyorBelt = importer._build_conveyor_belt({
		"position": Vector2.ZERO, "size": Vector2i(32, 16),
		"fields": {"speed": 45.0}}, ConveyorBelt.Direction.RIGHT)
	_check(rightward.direction == ConveyorBelt.Direction.RIGHT
			and is_equal_approx(rightward.drift(), 45.0),
		"and a ConveyorBelt_Right runs right  [drift %+.0f]" % rightward.drift())
	# Direction comes from WHICH ENTITY was placed, so there is no field left to
	# contradict it — the split exists precisely so a Left belt cannot be carrying
	# a stale "Right" in its fields. Only `speed` is still per-instance, because
	# two belts in one room can legitimately want different speeds.
	var bare: ConveyorBelt = importer._build_conveyor_belt(
		{"position": Vector2.ZERO, "size": Vector2i(32, 16), "fields": {}},
		ConveyorBelt.Direction.RIGHT)
	_check(bare.direction == ConveyorBelt.Direction.RIGHT and is_equal_approx(bare.speed, 60.0),
		"an unset speed falls back to the prefab, not to zero  [%s, %.0f]" % [
			"RIGHT" if bare.direction == ConveyorBelt.Direction.RIGHT else "LEFT", bare.speed])
	# The old single "ConveyorBelt" entity ran right, and rooms 8 and 9 are full
	# of them. The importer still answers to that name for exactly that reason.
	var legacy: ConveyorBelt = importer._build_conveyor_belt(
		{"position": Vector2.ZERO, "size": Vector2i(32, 16),
		 "fields": {"direction": "ConveyorDirection.Right", "speed": 60.0}},
		ConveyorBelt.Direction.RIGHT)
	_check(legacy.direction == ConveyorBelt.Direction.RIGHT,
		"a belt placed under the old name still runs right")
	var backwards: ConveyorBelt = importer._build_conveyor_belt({
		"position": Vector2.ZERO, "size": Vector2i(32, 16),
		"fields": {"speed": -80.0}}, ConveyorBelt.Direction.LEFT)
	_check(is_equal_approx(backwards.speed, 80.0) and is_equal_approx(backwards.drift(), -80.0),
		"a negative speed is a magnitude, not a stop  [%.0f, drift %+.0f]" % [
			backwards.speed, backwards.drift()])
	# The builder's belts never enter a tree, so nothing else will ever free
	# them; left alone they are the whole of the "RIDs leaked at exit" report,
	# which is the sort of noise that gets a real leak ignored later.
	for orphan in [built, rightward, bare, legacy, backwards]:
		orphan.free()

	if failures.is_empty():
		print("CONVEYOR TEST: ALL PASS")
	else:
		print("CONVEYOR TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


# ------------------------------------------------------------------ moves ----

## How far the belt should carry him in `frames` physics frames.
func _expect(frames: int) -> float:
	return belt.speed * float(frames) / tick


## Put him down at `where` and let him settle, so every measurement starts from
## a player standing still on the floor rather than mid-fall.
func _settle(where: Vector2) -> void:
	_release_all()
	player.global_position = where
	player.velocity = Vector2.ZERO
	await _frames(12)
	# Teleporting him onto the belt drops him the last few pixels, and those are
	# frames spent AIRBORNE over a running belt — which now, correctly, hands its
	# speed over. Real play never does this; a measurement that starts with a
	# leftover boost in him is measuring the teleport. Cleared here so every
	# figure below starts from a player standing still.
	player.velocity.x = 0.0
	player.boost_timer = 0.0
	await _frames(1)


## Back to the middle of the belt, standing still.
func _stand() -> void:
	await _settle(FLOOR)


## How far he moves in `frames` frames with no input at all: the carry, alone.
## Horizontal ground covered by one jump off the belt, in px, optionally holding
## a direction the whole way.
##
## Also records the takeoff speed into `_takeoff_speed` — the distance is what
## the player feels, the speed is what actually changed, and a test that measured
## only one of them could not say which.
var _takeoff_speed := 0.0

func _leap(hold := "") -> float:
	await _stand()
	if hold != "":
		Input.action_press(hold)
		await _frames(10)   # up to speed before he leaves the ground
	var start: float = player.global_position.x
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	# Sampled just after takeoff, before air drag has had time to eat it.
	_takeoff_speed = player.velocity.x
	await _frames(28)
	var moved: float = player.global_position.x - start
	_release_all()
	await _settle(FLOOR)
	return moved


## Ground covered by one rightward dash, measured for exactly as long as the
## dash owns him — px.
##
## Neutral dash off `facing` rather than holding a direction: a held key adds his
## own run to the number and would bury the very thing under test.
func _dash_distance() -> float:
	await _stand()
	player.facing = 1
	player.dash_available = true
	player.dash_cooldown_timer = 0.0
	Input.action_press("dash")
	# Start the tape when the DASH state does, not when the key goes down: the
	# press takes a frame or two to register, and those are frames he spends
	# standing on a running belt. Measuring from the press charged the dash with
	# 2px of ordinary belt carry and made all three readings differ by exactly
	# that — the artifact looked precisely like the bug.
	var guard := 0
	while player.state != Player.State.DASH and guard < 20:
		guard += 1
		await get_tree().physics_frame
	Input.action_release("dash")
	var start: float = player.global_position.x
	# Sampled every frame and kept only while the dash is still running. Reading
	# the position after the loop instead would include the frame AFTER the dash
	# ends — a frame in which the belt is legitimately carrying him again, worth
	# exactly 1px at 60 px/s, which is indistinguishable from the bug.
	var last := start
	guard = 0
	while guard < 40:
		guard += 1
		await get_tree().physics_frame
		if player.state != Player.State.DASH:
			break
		last = player.global_position.x
	await _settle(FLOOR)
	return last - start


func _carried_over(frames: int, from := FLOOR) -> float:
	await _settle(from)
	var start: float = player.global_position.x
	await _frames(frames)
	return player.global_position.x - start


## How far he gets holding one direction for `frames` frames, from a standstill
## in the middle of the belt. His run speed at the end of the hold is left in
## `walk_velocity` — it has to be read before the key comes up.
func _walk(action: String, frames: int) -> float:
	await _stand()
	var start: float = player.global_position.x
	Input.action_press(action)
	await _frames(frames)
	var moved: float = player.global_position.x - start
	walk_velocity = player.velocity.x
	Input.action_release(action)
	await _frames(10)
	return moved


func _release_all() -> void:
	for action in ["jump", "dash", "move_left", "move_right"]:
		Input.action_release(action)


## How many belts of each direction the LDtk project actually places, read from
## the source project rather than from the imported result — this is the "should"
## side of the comparison, so it has to come from somewhere the importer did not
## touch.
func _belts_in_ldtk() -> Dictionary:
	var out := {"left": 0, "right": 0}
	var raw := FileAccess.get_file_as_string("res://ldtk/hooshang_act1.ldtk")
	var project = JSON.parse_string(raw)
	if project == null or not project.has("levels"):
		return out
	for level in project["levels"]:
		for layer in level.get("layerInstances", []):
			for entity in layer.get("entityInstances", []):
				match str(entity.get("__identifier", "")):
					"ConveyorBelt_Left": out["left"] += 1
					"ConveyorBelt_Right", "ConveyorBelt": out["right"] += 1
	return out


## Every ConveyorBelt the LDtk import built, anywhere in the world.
func _collect_belts(node: Node, out: Array[Node]) -> void:
	if node is ConveyorBelt:
		out.append(node)
	for child in node.get_children():
		_collect_belts(child, out)


func _check(ok: bool, msg: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
