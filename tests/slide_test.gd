extends Node
## SlideZone: floor that will not hold him.
##
## Four things have to be true, and every one of them is invisible until you are
## playing the room: inside the zone his steering is throttled, a drag builds
## along the angle, jump and dash do nothing — and ALL of that goes away again on
## the way out. The last one is the one worth a test: a zone that forgets to give
## control back does not look broken where it happened, it looks like the game
## broke two rooms later.
##
## Driven with real input actions (Input.action_press) rather than by writing
## velocity, because "jump does nothing" is a claim about the input path, and
## setting velocity by hand would test nothing about it.
## Run:  godot --headless res://tests/slide_test.tscn

## Typed as Area2D rather than SlideZone throughout, and reached through the
## scene rather than the class name. A `class_name` only exists once the EDITOR
## has scanned for it, so a headless run started before that scan cannot parse a
## script that names the new type — which does not fail loudly, it fails as a
## test that loads, dies on a parse error, and then sits there forever with no
## scene left alive to call quit().
const ZONE_SCENE := preload("res://scenes/props/zones/SlideZone.tscn")
## Room 1 is a plain box: floor along y=248, walls at x=48 and x=272 (read off
## the LDtk collision grid, not guessed). Everything below stands on that line.
##
## IN is under the zone. OUT is clear of it and still on the floor — an earlier
## version stood him 200px to the left, which is outside the room entirely, so
## "he can jump" measured a man falling into the void.
const IN := Vector2(100.0, 248.0)
const OUT := Vector2(180.0, 248.0)
## Zone width. Wide enough that half a second of sliding does not carry him out
## of it mid-measurement, and narrow enough to leave OUT clear.
const ZONE_SIZE := Vector2(96.0, 48.0)

var failures: Array[String] = []
var world: LdtkWorld
var player: Player
var zone: Area2D


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	await _frames(30)
	# The opening cutscene owns room 1: it locks input, fades up from black and
	# waits on button presses. This test presses jump to measure jumps, which
	# would double as dismissing its dialogue — the two would be indistinguishable
	# and the failures unreadable. Nothing here is about the story, so the beats
	# go, and the fade goes with them (it is their child).
	var beats := world.get_node_or_null("Act1Beats")
	if beats != null:
		beats.free()
	player = world.player
	player.input_locked = false
	player.has_dash = true

	# A zone over the middle of room 1's floor, wide enough to stand in.
	zone = ZONE_SCENE.instantiate()
	zone.size = ZONE_SIZE
	world.rooms[0].add_child(zone)
	zone.global_position = IN + Vector2(0.0, -8.0)
	await _frames(5)

	_check(zone.direction().is_equal_approx(Vector2.RIGHT.rotated(deg_to_rad(60.0))),
		"the default angle is 60 degrees, down and to the right  [%s]" % zone.direction())

	# --- outside it, he is himself ---
	await _stand(OUT)
	_check(not player.sliding(), "clear of the zone he is not sliding")
	var free_jump := await _jump_height()
	_check(free_jump > 8.0, "and can jump  [rose %.0fpx]" % free_jump)

	# --- inside it ---
	await _stand(IN)
	_check(player.sliding(), "standing in the zone puts him in a slide")
	_check(is_equal_approx(player.slide_control, zone.control_strength),
		"his steering drops to control_strength  [%.2f]" % player.slide_control)

	# The drag builds. Sampled twice, because the number that matters is not how
	# fast he ends up but that it keeps GROWING — a slide that reaches its speed
	# on the first frame is a conveyor belt.
	#
	# Both samples come from ONE continuous slide. Standing him fresh for each
	# reading is what an earlier version did, and by the second one the slide had
	# carried him out of its own zone: the drag read 0 and the growth check failed
	# on a slide that was working perfectly.
	await _stand(IN)
	await _frames(3)
	var early: float = player.slide_speed
	await _frames(12)
	var later: float = player.slide_speed
	_check(later > early and early > 0.0,
		"the drag builds along the angle  [%.0f -> %.0f px/s]" % [early, later])
	_check(player.slide_speed <= player.max_slide_speed + 0.01,
		"never past the player's own ceiling  [%.0f of %.0f]" % [
			player.slide_speed, player.max_slide_speed])

	# Measured as ground travel, not as velocity along the angle. On the flat
	# floor of this test room a 60-degree drag spends most of itself pressing him
	# INTO the floor, which the collision then eats — so the along-the-angle
	# velocity reads low even though the slide is working perfectly. What the
	# player experiences, and what this asserts, is that his feet are carried.
	# Sampled while he is still INSIDE. Half a second of this carries him out the
	# far side, at which point the zone correctly lets go and his velocity
	# correctly decays to nothing — which reads as the slide having done nothing
	# at all.
	await _stand(IN)
	var from_x: float = player.global_position.x
	await _frames(15)
	var carried: float = player.global_position.x - from_x
	_check(carried > 8.0 and player.velocity.x > 0.0,
		"and it carries him downhill with no input  [%.0fpx, %.0f px/s]" % [
			carried, player.velocity.x])

	# --- jump and dash are gone ---
	await _stand(IN)
	var slide_jump := await _jump_height()
	_check(slide_jump <= 2.0, "jump does nothing in the zone  [rose %.0fpx]" % slide_jump)
	await _stand(IN)
	var dashed := await _tried_dash()
	_check(not dashed, "and neither does dash  [state %s]" % player.state_name())

	# --- and he gets it all back ---
	await _stand(IN)
	_check(player.sliding(), "in the zone again")
	await _stand(OUT)
	_check(not player.sliding(), "stepping out ends the slide")
	_check(player.slide_control == 1.0 and player.slide_speed == 0.0,
		"steering and drag are both cleared  [control %.2f, drag %.0f]" % [
			player.slide_control, player.slide_speed])
	var after_jump := await _jump_height()
	_check(after_jump > 8.0, "and he can jump again  [rose %.0fpx]" % after_jump)

	# --- dying inside it does not carry the slide into the next life ---
	await _stand(IN)
	_check(player.sliding(), "sliding once more, to die in it")
	player.die()
	await _frames(4)
	player.respawn(OUT)
	await _frames(4)
	_check(not player.sliding() and player.slide_control == 1.0,
		"respawning clear of it gives control back  [sliding %s, control %.2f, at %s]" % [
			player.sliding(), player.slide_control, player.global_position])

	# ...and a checkpoint UNDER the zone still gets a slide. He never crosses the
	# boundary on that path, so body_entered never fires, and the zone has to
	# notice him standing in it. Without that he keeps full control inside a
	# chute — which reads as the slide being broken, in the one room where the
	# designer most wanted it.
	player.die()
	await _frames(4)
	player.respawn(IN)
	await _frames(12)
	_check(player.sliding(),
		"respawning INSIDE it starts sliding again  [state %s]" % player.state_name())

	# Each die() above also left the WORLD's own respawn pending, and it fires
	# Player.death_time later — this test does its own respawn immediately and
	# then the level does another one on its own clock. At 0.15s that landed
	# before anything else was measured. At 1s it lands in the MIDDLE of the next
	# section and teleports him to the checkpoint mid-measurement, which reads as
	# "he fell through the slide". Drain it rather than race it.
	await get_tree().create_timer(player.death_time + 0.3).timeout

	# --- the LDtk side: fields, and what happens without them ---
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()
	var built: Area2D = importer._build_slide_zone({
		"position": Vector2(8.0, 4.0), "size": Vector2i(64, 32),
		"fields": {"angle": 30.0, "control_strength": 0.5, "speed_ramp": 90.0}})
	_check(built.position == Vector2(8.0, 4.0) and built.size == Vector2(64.0, 32.0),
		"the importer places and sizes it from LDtk  [%s %s]" % [built.position, built.size])
	_check(is_equal_approx(built.angle, 30.0)
			and is_equal_approx(built.control_strength, 0.5)
			and is_equal_approx(built.speed_ramp, 90.0),
		"and reads all three fields  [%.0f, %.2f, %.0f]" % [
			built.angle, built.control_strength, built.speed_ramp])
	# An unset field arrives as null. Falling back to the prefab's defaults is
	# what keeps a zone placed before the fields existed behaving like a slide,
	# rather than like a zone with an angle of zero and no push.
	var bare: Area2D = importer._build_slide_zone({
		"position": Vector2.ZERO, "size": Vector2i(32, 16), "fields": {}})
	_check(is_equal_approx(bare.angle, 60.0)
			and is_equal_approx(bare.control_strength, 0.35),
		"an unset field falls back to the default, not to zero  [%.0f, %.2f]" % [
			bare.angle, bare.control_strength])

	# --- a slide is FLOOR, and it is VISIBLE ---
	# THE BUG, both halves of it: the zone was a trigger volume that drew nothing
	# in game, so a slide placed anywhere but exactly on top of existing floor
	# tiles was an invisible hole. Every check above puts the zone over room 1's
	# own floor, which is the one arrangement where an intangible zone and a
	# working one behave identically — so this one is hung in the air.
	# Prove the spot is EMPTY first. The first draft of this hung the zone where
	# room 1's ceiling is, so he came to rest on the ceiling and "he landed on
	# the slide" passed against a zone that held nothing at all.
	var air := IN + Vector2(0.0, -40.0)
	_release_all()
	player.global_position = air + Vector2(0.0, -24.0)
	player.velocity = Vector2.ZERO
	await _frames(40)
	_check(player.global_position.y > air.y,
		"nothing holds him at the test spot to begin with  [%.0fpx]"
			% (player.global_position.y - air.y))

	var chute: SlideZone = ZONE_SCENE.instantiate()
	chute.size = Vector2(96.0, 16.0)
	world.rooms[0].add_child(chute)
	chute.global_position = air
	await _frames(4)
	var surface: Node2D = chute.get_node("Surface")
	_check(surface.get_child_count() == 6,
		"a 6-cell slide draws 6 cells of slick floor  [got %d]"
			% surface.get_child_count())
	_release_all()
	player.global_position = chute.global_position + Vector2(0.0, -24.0)
	player.velocity = Vector2.ZERO
	await _frames(40)
	var landed: float = chute.global_position.y - player.global_position.y
	_check(player.is_on_floor() and landed > 0.0,
		"he lands ON a slide strung across a gap  [%.0fpx above it, on_floor %s]" % [
			landed, player.is_on_floor()])
	# ...and the escape hatch still works, for a zone laid over real floor where
	# a second surface would be a phantom ledge.
	chute.solid = false
	await _frames(4)
	_check(surface.get_child_count() == 0,
		"turned off, it draws nothing  [got %d]" % surface.get_child_count())
	await _frames(30)
	_check(player.global_position.y > chute.global_position.y,
		"and he drops through it  [%.0fpx]"
			% (player.global_position.y - chute.global_position.y))
	chute.queue_free()
	await _frames(2)

	if failures.is_empty():
		print("SLIDE TEST: ALL PASS")
	else:
		print("SLIDE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


# ------------------------------------------------------------------ moves ----

## Put him down at `where` and let him settle, so every measurement starts from
## a player standing still on the floor rather than mid-fall.
func _stand(where: Vector2) -> void:
	_release_all()
	player.global_position = where
	player.velocity = Vector2.ZERO
	# Short on purpose: he only has a couple of pixels to fall, and inside the
	# zone every settling frame is a frame the slide is already carrying him
	# towards the far edge.
	await _frames(6)


## How far he rises from a jump press, in px. 0 = the press did nothing.
func _jump_height() -> float:
	var start: float = player.global_position.y
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(14)
	var risen: float = start - player.global_position.y
	await _frames(20)   # back on the floor before anything else is measured
	return risen


## Did a dash press actually start a dash?
func _tried_dash() -> bool:
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	var dashed := player.state_name() == "DASH"
	await _frames(20)
	return dashed


func _release_all() -> void:
	for action in ["jump", "dash", "move_left", "move_right"]:
		Input.action_release(action)


func _check(ok: bool, msg: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		failures.append(msg)


## PHYSICS frames, not idle ones. Everything this test measures — overlaps,
## jump arcs, the drag — happens in the physics step, and headless runs idle
## frames faster than physics frames: an early version waited "4 frames" after a
## respawn and got barely one physics step, which read as the zone failing to let
## go of a player it had already let go of.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
