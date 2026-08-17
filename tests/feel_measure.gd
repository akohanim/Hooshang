extends Node
## Measurement harness for the jump arc. NOT a pass/fail test — it prints the
## numbers a feel retune has to be judged against, so "bouncier" can be checked
## rather than felt for.
##
## The Jump/Gravity exports are tuned against real level geometry and the
## comments in player.gd quote measured figures (a ~33px apex clearing a 2-cell
## pillar, a jump+up-dash clearing a 4-cell platform on most timings). Those
## measurements are what this reproduces, so a retune can prove it moved airtime
## without moving reach.
##
## Run:  godot --headless --path . res://tests/feel_measure.tscn

var level: Node2D
var player: Player
var _floor_y := 0.0

## The platform a jump+up-dash has to clear, in px (4 cells of the 16px grid).
const DASH_TARGET := 64.0
## The pillar a plain full jump has to clear (2 cells).
const JUMP_TARGET := 32.0


func _ready() -> void:
	level = load("res://scenes/levels/TestLevel.tscn").instantiate()
	add_child(level)
	player = level.get_node("Player")
	await _frames(40)
	_floor_y = player.global_position.y

	print("\n=== JUMP ARC ===")
	await _plain_jump("full jump   (held)", 60)

	# The whole point of a hold-style variable jump is that how long you press
	# for picks the height, so the useful measurement is the WHOLE ladder rather
	# than three samples off it. A window that saturates after five frames has
	# two heights in it however the exports read.
	print("\n=== HOLD LADDER  (apex by frames held) ===")
	for held in [1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 18]:
		await _plain_jump("hold %2df" % held, held)

	print("\n=== RUNNING JUMP ===")
	await _running_jump()

	print("\n=== JUMP + UP-DASH  (20 dash timings) ===")
	await _dash_sweep()

	print("\n=== FALL ===")
	await _terminal_fall()

	print("")
	get_tree().quit(0)


## Apex height above the floor, and total airtime, for a jump whose button is
## held for `hold` physics frames.
func _plain_jump(label: String, hold: int) -> void:
	await _reset()
	var y0 := player.global_position.y
	Input.action_press("jump")
	var apex := y0
	var frames := 0
	var released := false
	for i in 300:
		await _frames(1)
		if i >= hold and not released:
			Input.action_release("jump")
			released = true
		apex = minf(apex, player.global_position.y)
		frames += 1
		if i > 4 and player.is_on_floor():
			break
	if not released:
		Input.action_release("jump")
	var height := y0 - apex
	print("  %-22s apex %6.1f px   airtime %5.3f s (%d frames)%s"
		% [label, height, frames / 60.0, frames,
			"   [clears 32px pillar]" if height >= JUMP_TARGET else ""])


## How far a full-speed running jump carries him horizontally, launch to landing.
func _running_jump() -> void:
	await _reset()
	Input.action_press("move_right")
	await _frames(25)          # up to max_run_speed (~6 frames) with margin
	var vx := player.velocity.x
	var x0 := player.global_position.x
	var y0 := player.global_position.y
	Input.action_press("jump")
	var apex := y0
	var frames := 0
	for i in 300:
		await _frames(1)
		apex = minf(apex, player.global_position.y)
		frames += 1
		if i > 4 and player.is_on_floor():
			break
	Input.action_release("jump")
	Input.action_release("move_right")
	print("  running jump           %6.1f px across   apex %5.1f px   airtime %5.3f s   (launch vx %.1f)"
		% [player.global_position.x - x0, y0 - apex, frames / 60.0, vx])


## The apex of a jump + upward dash, swept across when the dash is pressed.
##
## A sweep rather than one number on purpose: player.gd's dash_speed comment
## records that tuning this to a single best-case margin is wrong, because the
## platform then reads as impossible in play. What matters is how many of the
## timings clear it, not the best one.
func _dash_sweep() -> void:
	var peaks: Array[float] = []
	for delay in 20:
		await _reset()
		var y0 := player.global_position.y
		Input.action_press("jump")
		await _frames(delay)
		Input.action_press("move_up")
		Input.action_press("dash")
		await _frames(2)
		Input.action_release("dash")
		var apex := y0
		for i in 200:
			await _frames(1)
			apex = minf(apex, player.global_position.y)
			if i > 10 and player.is_on_floor():
				break
		Input.action_release("move_up")
		Input.action_release("jump")
		peaks.append(y0 - apex)
	var cleared := 0
	var lo := 9999.0
	var hi := 0.0
	var sum := 0.0
	for p in peaks:
		if p >= DASH_TARGET:
			cleared += 1
		lo = minf(lo, p)
		hi = maxf(hi, p)
		sum += p
	print("  apex %.1f - %.1f px  (mean %.1f)   clears the 64px platform on %d of %d timings"
		% [lo, hi, sum / peaks.size(), cleared, peaks.size()])
	var row := PackedStringArray()
	for p in peaks:
		row.append("%.0f" % p)
	print("  per-timing: %s" % " ".join(row))


## How long he takes to reach terminal velocity from a standing drop, and what
## that terminal speed actually is.
func _terminal_fall() -> void:
	await _reset()
	player.global_position = Vector2(player.global_position.x, _floor_y - 400.0)
	player.velocity = Vector2.ZERO
	player.state = Player.State.FALL
	var frames := 0
	var top := 0.0
	for i in 200:
		await _frames(1)
		frames += 1
		top = maxf(top, player.velocity.y)
		if i > 2 and player.is_on_floor():
			break
	print("  peak fall speed %.1f px/s   (reached in %.3f s of falling)"
		% [top, frames / 60.0])


## Put him back on the flat starting ground with every feel timer cleared.
func _reset() -> void:
	Input.action_release("jump")
	Input.action_release("move_up")
	Input.action_release("move_right")
	Input.action_release("dash")
	player.respawn(level.get_node("SpawnPoint").global_position)
	for i in 90:
		await _frames(1)
		if player.is_on_floor() and i > 10:
			break


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
