extends Node
## Regression: a wall on only ONE side must never produce a wall-slide that
## treats the OTHER, wall-less side as real.
##
## Reported directly from play: a spot in Level_1 with a wall on the right
## and open air on the left kept sliding him as though a wall stood on the
## left too. Root cause was two compounding bugs in the squeeze/chimney path
## (player.gd's _post_move and _state_wall_slide) -- NOT the ordinary
## single-wall slide, which is real physics contact and was already sound:
##
## 1. _near_wall_dir() short-circuits on whichever side it checks FIRST
##    (left) and never looks at the other side once it finds something
##    there. That is the right question for its original caller
##    (_state_air's wall-jump buffer: "is there a wall on EITHER side to
##    kick off"), and the wrong one for deciding whether the squeeze
##    wall-slide's premise -- "he is against both walls at once, there is no
##    steering off either" -- actually holds. A one-cell slot that is only
##    two-sided for a few pixels (a stair tread's lip ending right where a
##    real wall keeps going) reads as walled the whole time he is near the
##    lip, and locks wall_dir onto the side about to vanish rather than the
##    wall that is actually there.
##
## 2. The continuation check for that state deliberately skips is_on_wall()
##    while squeezing -- it HAS to: a genuine one-cell chimney has ~1px of
##    clearance either side and is_on_wall() is false the entire descent
##    (see chimney_test.gd). So once wall_dir locked onto the wrong side,
##    nothing caught it. Worse, _state_wall_slide()'s own nudge
##    (velocity.x = wall_dir * 20, unconditional even while squeezing) is
##    what pinned him against the fading side's last sliver of contact and
##    dragged him sideways toward it -- toward open air, away from the wall
##    that was actually there.
##
## The fix: _walled_both_sides() (checks BOTH sides, no short-circuit)
## replaces _near_wall_dir() for the squeeze path specifically, at both entry
## and continuation, and the wall-ward nudge in _state_wall_slide() no longer
## applies while squeezing -- a chimney already centres him via
## _tick_squeeze() and there is no lateral force that should need correcting.
##
## Run:  godot --headless res://tests/wall_slide_test.tscn

const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")

var failures: Array[String] = []
var world: Node2D
var player: Player


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	player = PLAYER.instantiate()
	world.add_child(player)
	await _run()
	_finish()


func _wall(x: float, y: float, w: float, h: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(x + w * 0.5, y + h * 0.5)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	cs.shape = shape
	body.add_child(cs)
	world.add_child(body)
	return body


func _run() -> void:
	await _check_single_wall(1000.0, 1, "move_right")   # wall on the RIGHT only
	await _check_single_wall(2000.0, -1, "move_left")   # wall on the LEFT only
	await _check_no_entry_away_from_wall()
	await _check_asymmetric_chimney()


## A tall wall on exactly one side, nothing on the other. Falling next to it
## while holding INTO it must wall-slide on the side the wall is actually on,
## never the other, and is_on_wall() must be true throughout -- the ordinary
## (non-squeeze) path is real physics contact and has no excuse to drift.
func _check_single_wall(ox: float, side: int, hold_action: String) -> void:
	_wall(ox + (0.0 if side > 0 else -8.0), 0.0, 8.0, 300.0)
	await _frames(2)
	player.respawn(Vector2(ox - side * 4.0, 10.0))
	player.velocity = Vector2(0, 20)
	Input.action_press(hold_action)
	var saw_slide := false
	var bad_dir := false
	var off_wall := false
	for f in 150:
		await _frames(1)
		if player.state == Player.State.WALL_SLIDE:
			saw_slide = true
			if player.wall_dir != side:
				bad_dir = true
			if not player.is_on_wall():
				off_wall = true
		if player.global_position.y > 280.0:
			break
	Input.action_release(hold_action)
	var label := "right" if side > 0 else "left"
	_check(saw_slide, "wall-slides against a wall on the %s  [side=%d]" % [label, side])
	_check(not bad_dir, "...always with wall_dir on that same side  [%d]" % side)
	_check(not off_wall, "...and always genuinely touching it (is_on_wall)")


## Wall on the LEFT only, but he is holding RIGHT (away from it) the whole
## time. He must never wall-slide at all -- there is nothing on his right to
## slide against, and pressing away from the only real wall must not be read
## as pressing into one.
func _check_no_entry_away_from_wall() -> void:
	var ox := 3000.0
	_wall(ox - 8.0, 0.0, 8.0, 300.0)
	await _frames(2)
	player.respawn(Vector2(ox + 4.0, 10.0))
	player.velocity = Vector2(0, 20)
	Input.action_press("move_right")
	var entered := false
	for f in 150:
		await _frames(1)
		if player.state == Player.State.WALL_SLIDE:
			entered = true
		if player.global_position.y > 280.0:
			break
	Input.action_release("move_right")
	_check(not entered,
		"holding away from the only wall never triggers a wall-slide")


## THE bug, reproduced directly. A one-cell shaft mouth that is two-sided for
## only 8px -- a stair tread's lip -- before only ONE wall (deep, real)
## continues. Nothing is held; the squeeze/chimney path alone decides what
## happens. He must never drift toward the side that stopped being a wall:
## _tick_squeeze() centres him in the mouth and there is no legitimate force
## that should move him off that centre by more than a fraction of a pixel,
## whether he is genuinely between two short-lived walls or, past the lip,
## simply falling straight down the one real one.
func _check_asymmetric_chimney() -> void:
	var ox := 4000.0
	_wall(ox - 16.0, 92.0, 16.0, 8.0)    # short lip: only 8px, then nothing
	_wall(ox + 8.0, 92.0, 16.0, 400.0)   # real wall: continues all the way down
	await _frames(2)
	player.respawn(Vector2(ox + 4.0, 60.0))
	player.velocity = Vector2(0, 10)
	var start_x := player.global_position.x
	var max_drift := 0.0
	var reached_bottom := false
	for f in 250:
		await _frames(1)
		max_drift = maxf(max_drift, absf(player.global_position.x - start_x))
		if player.global_position.y > 500.0:
			reached_bottom = true
			break
	_check(reached_bottom, "falls all the way through without getting stuck")
	_check(max_drift < 1.0,
		"never drifts toward the side that stopped being a wall  [%.2fpx]" % max_drift)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures.append(what)


func _finish() -> void:
	if failures.is_empty():
		print("WALL SLIDE TEST: ALL PASS")
	else:
		print("WALL SLIDE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
