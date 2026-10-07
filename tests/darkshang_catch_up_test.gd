extends Node
## Deterministic pursuit at real physics cadence, with an unboosted control.
var failures := 0
var player: Player
var shadow: Darkshang
const STEP := 1.0 / 60.0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func _ready() -> void:
	SaveGame.slot = -1
	player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	shadow = preload("res://scenes/props/chase/Darkshang.tscn").instantiate()
	shadow.auto_start = false
	add_child(shadow)
	shadow.set_physics_process(false)
	shadow.buffer.set_physics_process(false)
	shadow._player = player
	shadow.entry_hold_distance = 0
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		seed_chase(direction, 240.0)
		shadow.catch_up_distance = 0
		advance(direction * 240.0, 180)
		var control := shadow.gap()
		seed_chase(direction, 240.0)
		shadow.catch_up_distance = 160
		var biggest_step := advance(direction * 240.0, 180)
		check(control > 280 and shadow.gap() < 175, "fast escape closes from %.1f to %.1f (%s)" % [control, shadow.gap(), direction])
		check(biggest_step < 8, "catch-up moves continuously along the trail")
		check(shadow.read_delay >= shadow.catch_up_min_delay, "catch-up preserves minimum reaction delay")
	seed_chase(Vector2.LEFT, 600.0)
	advance(Vector2.LEFT * 600.0, 300)
	check(is_equal_approx(shadow.read_delay, shadow.catch_up_min_delay), "sustained extreme separation stops at the minimum delay")
	seed_chase(Vector2.LEFT, 72.0)
	advance(Vector2.LEFT * 72.0, 180)
	check(is_equal_approx(shadow.read_delay, shadow.follow_delay), "ordinary running gets no boost")
	seed_chase(Vector2.LEFT, 240.0)
	advance(Vector2.LEFT * 240.0, 120)
	var boosted := shadow.read_delay
	advance(Vector2.LEFT * 72.0, 300)
	check(boosted < shadow.follow_delay and is_equal_approx(shadow.read_delay, shadow.follow_delay), "normal delay returns after the gap closes")
	seed_chase(Vector2.LEFT, 240.0)
	player.input_locked = true
	shadow._physics_process(STEP)
	check(is_equal_approx(shadow.read_delay, shadow.follow_delay), "locked player cannot trigger catch-up")
	player.input_locked = false
	shadow.entry_hold_distance = 16
	shadow.reset_to_checkpoint(player.global_position)
	var parked := shadow.global_position
	for i in 120: shadow._physics_process(STEP)
	check(shadow._holding_entry and shadow.global_position == parked, "entry hold keeps the shadow parked")
	check(is_equal_approx(shadow.read_delay, shadow.follow_delay), "respawn clears shortened catch-up delay")
	seed_chase(Vector2.LEFT, 240.0)
	shadow.state = Darkshang.State.SURGING
	shadow._surge_timer = 1.0
	shadow.read_delay = 0.6
	shadow._physics_process(STEP)
	check(is_equal_approx(shadow.read_delay, 0.6), "active surge keeps its authored delay")
	print("DARKSHANG CATCH-UP: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func seed_chase(direction: Vector2, speed: float) -> void:
	player.global_position = Vector2.ZERO
	player.input_locked = false
	player.state = Player.State.FALL
	shadow.route_direction = direction
	shadow.reset_to_checkpoint(Vector2.ZERO)
	shadow._holding_entry = false
	shadow.visible = true
	shadow._grace_timer = 1000.0
	shadow.buffer.clear_and_seed(Vector2.ZERO, -direction, speed)
	shadow.global_position = shadow.buffer.get_position_at_delay(shadow.read_delay)

func advance(velocity: Vector2, frames: int) -> float:
	var biggest_step := 0.0
	for i in frames:
		player.global_position += velocity * STEP
		shadow.buffer.record(player.global_position)
		var before := shadow.global_position
		shadow._physics_process(STEP)
		biggest_step = maxf(biggest_step, shadow.global_position.distance_to(before))
	return biggest_step
