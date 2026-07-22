extends Node
## Level 2 traversal calibration + regression. Drives the player through each of
## the three jumps with the INTENDED input and checks it lands on the next
## platform; also checks that a plain jump is NOT enough for jumps 2 & 3 (they
## genuinely require the dash) and that a short hop fails jump 1.
## Run:  godot --headless res://tests/level2_test.tscn

var failures: Array[String] = []
var level: Node2D
var player: Player

# Right edge of each take-off platform (px) and each target platform's landable
# top surface + x-range (px). Mirrors tools/gen_level2.py.
const TAKEOFF = {1: 102, 2: 190, 3: 318}          # x just shy of P0/P1/P2 edge
const TOP_Y = {1: 218, 2: 194, 3: 170}            # player origin y on P0/P1/P2
const TARGET = {
	1: {"x0": 128, "x1": 192, "surf": 200},       # P1
	2: {"x0": 240, "x1": 320, "surf": 176},       # P2
	3: {"x0": 414, "x1": 518, "surf": 160},       # P3 (sub-tile gap 94px, rise 2t)
}
const REPORT := false   # true = print landings without asserting (for tuning)


func _ready() -> void:
	level = load("res://scenes/levels/act1_office/Level2.tscn").instantiate()
	add_child(level)
	player = level.get_node("Player")
	level.kill_y = 100000.0   # disable the kill plane so a miss just falls (no auto-respawn)
	_run()


func _run() -> void:
	Game.test_mode = true  # exercise progression without swapping scenes
	await _frames(20)
	_check(player.has_dash, "dash is available from the start of Level 2")
	_check(Game.current_index == 1, "Level 2 registers as the current level")
	_check(player.is_on_floor() and player.global_position.x < 160.0,
		"spawns on the starting platform")

	var j1 := await _attempt(1, "jump", 16, 0)
	_assert_on(j1, 1, "JUMP 1 — a max-height plain jump clears it")
	var j1s := await _attempt(1, "jump", 4, 0)
	_assert_missed(j1s, "JUMP 1 — a short hop falls short")

	var j2 := await _attempt(2, "jumpdash", 6, 4)
	_assert_on(j2, 2, "JUMP 2 — jump + dash clears it")
	var j2p := await _attempt(2, "jump", 16, 0)
	_assert_missed(j2p, "JUMP 2 — a plain jump is NOT enough (dash required)")

	# Jump 3 is at the limit: only a near-perfect apex dash clears the 10-tile gap.
	var j3 := await _attempt(3, "jumpdash", 6, 19)
	_assert_on(j3, 3, "JUMP 3 — a near-perfect apex jump+dash clears it")
	var j3e := await _attempt(3, "jumpdash", 6, 6)
	_assert_missed(j3e, "JUMP 3 — dashing too early falls short (perfection required)")
	var j3p := await _attempt(3, "jump", 16, 0)
	_assert_missed(j3p, "JUMP 3 — a plain jump is NOT enough")

	# The exit at the top of P3 finishes the run (Level 2 is the last level).
	player.respawn(Vector2(480, 148))
	var done := false
	for i in 40:
		await _frames(1)
		if Game.completed:
			done = true
			break
	_check(done, "reaching the exit finishes the run")

	if failures.is_empty():
		print("LEVEL2 TEST: ALL PASS")
	else:
		print("LEVEL2 TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Launch from platform `p`'s right edge at top speed and run the maneuver.
## Returns the resting Vector2 (or a far-down point if it fell). `mode` =
## "jump" (hold jump_hold frames) or "jumpdash" (dash up-forward after delay).
func _attempt(p: int, mode: String, jump_hold: int, dash_delay: int) -> Vector2:
	player.respawn(Vector2(TAKEOFF[p], TOP_Y[p]))
	await _frames(4)                       # settle at rest on the platform edge
	player.velocity.x = player.max_run_speed
	Input.action_press("move_right")
	Input.action_press("jump")
	if mode == "jumpdash":
		await _frames(dash_delay)
		Input.action_release("jump")
		Input.action_press("move_up")
		Input.action_press("dash")
		await _frames(2)
		Input.action_release("dash")
		await _frames(4)
		Input.action_release("move_up")
	else:
		await _frames(jump_hold)
		Input.action_release("jump")

	var result := Vector2(0, 9999)
	for i in 130:
		await _frames(1)
		if player.global_position.y > 300.0:   # fell into the pit
			result = player.global_position
			break
		if i > 5 and player.is_on_floor():
			result = player.global_position
			break
	Input.action_release("move_right")
	if REPORT:
		print("  P%d %-9s hold=%d delay=%d -> (%.0f, %.0f) floor=%s" % [
			p, mode, jump_hold, dash_delay, result.x, result.y, player.is_on_floor()])
	return result


func _assert_on(pos: Vector2, target: int, name: String) -> void:
	var t: Dictionary = TARGET[target]
	var on_surf: bool = absf(pos.y - float(t.surf) + 6.0) < 6.0
	var in_x: bool = pos.x >= float(t.x0) - 2.0 and pos.x <= float(t.x1) + 2.0
	var ok: bool = player.is_on_floor() and on_surf and in_x
	_check(ok or REPORT, "%s  [landed (%.0f,%.0f)]" % [name, pos.x, pos.y])


func _assert_missed(pos: Vector2, name: String) -> void:
	_check(pos.y > 300.0 or REPORT, "%s  [ended (%.0f,%.0f)]" % [name, pos.x, pos.y])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
