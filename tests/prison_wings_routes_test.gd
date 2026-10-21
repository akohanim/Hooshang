extends Node
## Proves every prison wing room is solvable with REAL INPUT — no velocity or
## position writes during a move. Routes come from tools/build_prison_wings.py
## (resources/levels/prison_wings_routes.json): each room is a list of steps
## from one standing point to the next landing (or into water, through a
## portal, onto a key).
##
## Two passes per room:
##   1. SEARCH. Each step is solved on its own: the player is stood at its
##      start and the harness tries jump lengths, dash timings/directions,
##      auto wall-kicks and (for a moving thought) start delays until one
##      lands. The trial count is printed — a step that needs hundreds of
##      tries before ANY input works is a step that is too tight.
##   2. REPLAY. The found inputs run back to back from the room's spawn with
##      no teleports, so crumbling stones, lever countdowns and thought
##      phases are all exercised the way a player meets them.
##
## Headless:  Godot --headless --path . --fixed-fps 60 res://tests/prison_wings_routes_test.tscn
## One room:  ... res://tests/prison_wings_routes_test.tscn -- Prison_G03
const DASH_FRAMES := [3, 7, 11, 16, 22]
const JUMP_HOLDS := [60, 16, 7]
## A player catches their breath on solid ground (or bobs up in water) before
## the next move; only a step marked `hurry` (it starts on something crumbling)
## goes straight on.
const SETTLE := 8
var world: Node
var player: Player
var room: Node2D
var failures := 0
var trials := 0
var used_frames := 0
var trace := false
var fragile := 0


func _ready() -> void:
	get_tree().create_timer(3600.0, true, false, true).timeout.connect(func(): print("PRISON_ROUTES: TIMEOUT"); get_tree().quit(3))
	SaveGame.unbind()
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/prison_wings_routes.json"))
	var only := OS.get_cmdline_user_args()
	trace = "--trace" in only
	if trace: only.remove_at(only.find("--trace"))
	world = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_Hub"
	Screen.set_scene(world)
	await frames(30)
	player = world.player
	player.has_dash = true
	for name: String in routes:
		if not only.is_empty() and name not in only: continue
		room = null
		for r in world.rooms:
			if str(r.name) == name.get_slice("#", 0): room = r
		if room == null:
			check(false, "%s exists" % name)
			continue
		var steps: Array = routes[name]
		var found: Array = []
		var ok := true
		for i in steps.size():
			var params = await search(steps[i], "%s step %d" % [name, i + 1])
			if params == null:
				ok = false
				break
			found.append(params)
		if ok:
			await replay(name, steps, found)
	print("PRISON_ROUTES: %d failures, %d fragile steps, %d trials" % [failures, fragile, trials])
	get_tree().quit(0 if failures == 0 else 1)


# ------------------------------------------------------------------ search --

func search(step: Dictionary, label: String):
	var options: Array = []
	var delays: Array = [0]
	if step.has("wait"): delays = range(0, int(step.wait), 10)
	var moves: Array = step.get("moves", ["jump"]).duplicate()
	# A jump can also be taken the way players take most of them: run off
	# the edge and jump in the coyote window.
	if "jump" in moves and not "run" in moves: moves.insert(moves.find("jump") + 1, "run")
	var dirs: Array = step.get("dash", [])
	for delay in delays:
		for move: String in moves:
			var holds: Array = JUMP_HOLDS if move in ["jump", "run"] else [4]
			for hold in holds:
				options.append({"delay": delay, "move": move, "hold": hold, "dash": "", "dash_frame": -1})
				for dir: String in dirs:
					for f in DASH_FRAMES:
						options.append({"delay": delay, "move": move, "hold": hold, "dash": dir, "dash_frame": f})
	var tried := 0
	var fallback = null
	for opt: Dictionary in options:
		tried += 1
		trials += 1
		await stand_at(step)
		var result := await perform(step, opt, false)
		if trace: print("    try %s -> %s at %s state %s" % [_describe(opt), result, player.global_position - room.global_position, player.state_name()])
		if not result: continue
		opt["frames"] = used_frames + 1
		# A real player never stands on the exact pixel. Keep looking for an
		# input that also works a few pixels either side of the start.
		var robust := true
		if not step.get("hurry", false) and not step.to.has("portal"):
			for nudge in [-3.0, 3.0]:
				await stand_at(step, nudge)
				if not await perform(step, opt, false):
					robust = false
					break
		if robust:
			print("  ok   %-26s after %3d/%d tries  %s" % [label, tried, options.size(), _describe(opt)])
			return opt
		if fallback == null: fallback = opt
	if fallback != null:
		print("  FRAGILE %-23s only exact-pixel inputs work: %s" % [label, _describe(fallback)])
		fragile += 1
		return fallback
	check(false, "%s: no input reaches %s from %s (%d tries)" % [label, step.to, step.from, tried])
	return null


func _describe(opt: Dictionary) -> String:
	var s: String = "%s(hold %d)" % [opt.move, opt.hold]
	if opt.dash != "": s += " dash %s@%d" % [opt.dash, opt.dash_frame]
	if opt.delay > 0: s += " after %d" % opt.delay
	return s


func stand_at(step: Dictionary, nudge := 0.0) -> void:
	await settle_dead()
	if world.current_room != room:
		world._enter_room(room, true)
		await frames(2)
	CrumblingPlatform.reset_all(get_tree())
	for prop in world.props:
		if prop.kind == "Patrol": prop.clock = 0.0
	release()
	if step.has("timer"): world.timers.start(str(step.timer), true)
	player.respawn(room.global_position + Vector2(float(step.from[0]) + nudge, float(step.from[1]) - Player.HALF_HEIGHT))
	player.input_locked = false
	await frames(3)


func settle_dead() -> void:
	release()
	for i in 240:
		if player.state != Player.State.DEAD and not world._transitioning: return
		await frames(1)


# ----------------------------------------------------------------- perform --

## One attempt at one step from wherever the player stands now.
func perform(step: Dictionary, opt: Dictionary, live: bool) -> bool:
	for i in int(opt.delay): await frames(1)
	var to: Dictionary = step.to
	var goal_x: float = room.global_position.x + float(step.get("steer", to.get("x", step.from[0])))
	# A spring step steers onto the spring first, then toward the goal.
	var steer_x: float = room.global_position.x + float(step.steer_first) if step.has("steer_first") else goal_x
	var start_room: Node = world.current_room
	var move: String = opt.move
	var airborne := false
	var air_frames := -1
	var swim_left := -1
	var kick_dir := 0
	var kick_frames := 999
	var floor_frames := 0
	var dash_release := -1
	if move == "jump" or move == "kick": Input.action_press("jump")
	var run_jump_at := -1
	if move == "dive": Input.action_press("move_down")
	var prev_vy := 0.0
	used_frames = 0
	for i in int(step.get("frames", 300)):
		used_frames = i
		var x := player.global_position.x
		# Steering: away from the wall just kicked, otherwise toward the goal.
		var aim := 0
		# After a wall kick, hold away (as a player does) until the far wall or a
		# beat has passed, then head for the goal again.
		if kick_frames < 40 and player._near_wall_dir() != kick_dir: aim = kick_dir
		elif step.get("steer_air", false) and player.swimming(): aim = 0
		elif absf(steer_x - x) > 2.5: aim = 1 if steer_x > x else -1
		Input.action_release("move_left"); Input.action_release("move_right")
		if aim > 0: Input.action_press("move_right")
		elif aim < 0: Input.action_press("move_left")
		if move == "run" and run_jump_at < 0 and airborne:
			Input.action_press("jump")
			run_jump_at = i
		if move == "run" and run_jump_at >= 0 and i == run_jump_at + int(opt.hold): Input.action_release("jump")
		if move != "run" and i == int(opt.hold): Input.action_release("jump")
		# Dash timing counts from leaving the ground (or the water).
		var counted := air_frames if move != "kick" else swim_left
		if opt.dash != "" and counted == int(opt.dash_frame):
			_press_dash(str(opt.dash))
			dash_release = i + 6
		if i == dash_release:
			for a in ["dash", "move_up", "move_down"]: Input.action_release(a)
		if step.get("wall", false) and airborne and not player.is_on_floor() and player.state != Player.State.DASH \
				and kick_frames > 8 and player._near_wall_dir() != 0:
			kick_dir = -player._near_wall_dir()
			Input.action_release("jump")
			await frames(1)
			Input.action_press("jump")
			kick_frames = 0
		if kick_frames == 10: Input.action_release("jump")
		await frames(1)
		kick_frames += 1
		if live and trace and i % 4 == 0:
			print("      f%d %s %s v%s" % [i, player.global_position - room.global_position, player.state_name(), player.velocity])
		if steer_x != goal_x and player.velocity.y < -250.0 and prev_vy > -150.0 and player.state != Player.State.DASH:
			steer_x = goal_x
		prev_vy = player.velocity.y
		if player.state == Player.State.DEAD:
			release()
			return false
		if world.current_room != start_room:
			release()
			return to.has("portal") and str(world.current_room.name) == str(to.portal)
		if world._transitioning: continue
		var on_floor := player.is_on_floor() and not player.swimming()
		if not on_floor and not player.swimming(): airborne = true
		if airborne: air_frames += 1
		if player.swimming(): swim_left = -1
		elif swim_left >= 0 or move == "kick": swim_left += 1
		if to.has("key") and str(to.key) in world.collected and player.is_on_floor() and _near_key(str(to.key)):
			release()
			return true
		var local := player.global_position - room.global_position
		if to.has("swim") and player.swimming() and (airborne or move in ["dive", "swim"]) and i > 6 \
				and absf(local.x - float(to.x)) <= float(to.get("tol", 12)):
			release()
			return true
		if on_floor and (airborne or move in ["walk", "run"]):
			floor_frames += 1
			var feet := local.y + Player.HALF_HEIGHT
			var hit := absf(local.x - float(to.get("x", -999))) <= float(to.get("tol", 8)) and absf(feet - float(to.get("y", -999))) <= 3.0
			if hit and floor_frames >= 2:
				release()
				return true
			# Standing still somewhere that is not the goal: this attempt is over.
			# (Landing short and walking the rest of the way is fine.)
			if floor_frames >= 12 and not hit and absf(player.velocity.x) < 3.0 and i > 20 \
					and player.state in [Player.State.IDLE, Player.State.RUN]:
				release()
				return false
		else:
			floor_frames = 0
	release()
	return false


## Standing where the key was — the key may already be banked from the search.
func _near_key(id: String) -> bool:
	for prop in world.props:
		if prop.kind == "Key" and prop.key_id == id:
			return prop.global_position.distance_to(player.global_position) < 20.0
	return false


func _press_dash(dir: String) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(a)
	if "r" in dir: Input.action_press("move_right")
	if "l" in dir: Input.action_press("move_left")
	if "u" in dir: Input.action_press("move_up")
	if "d" in dir: Input.action_press("move_down")
	Input.action_press("dash")


# ------------------------------------------------------------------ replay --

func replay(name: String, steps: Array, found: Array) -> void:
	await stand_at(steps[0])
	# Thoughts start where a player entering the room finds them.
	for prop in world.props:
		if prop.kind == "Patrol": prop.clock = 0.0
	var holds := {}
	for i in steps.size():
		if steps[i].has("wait"):
			holds[int(steps[i].get("wait_at", i))] = i
	for i in steps.size():
		var opt: Dictionary = found[i].duplicate()
		if steps[i].has("wait") and int(steps[i].get("wait_at", i)) != i:
			opt.delay = 0
		if i > 0 and not steps[i].get("hurry", false):
			await approach(steps[i])
			await settle()
		if holds.has(i):
			# Wait HERE (somewhere solid) so the timed step meets its thought at
			# the phase the search found, counting the legs still to run first.
			var target: int = holds[i]
			var ahead := 0
			for k in range(i, target):
				ahead += int(found[k].get("frames", 0))
				if not steps[k + 1].get("hurry", false): ahead += SETTLE
			opt.delay = _phase_delay(steps[target], found[target], ahead)
		if steps[i].has("wait"):
			var c := 0.0
			for prop in world.props:
				if prop.kind == "Patrol" and prop.get_parent().get_parent() == room: c = prop.clock
			var P := int(steps[i].wait)
			print("    phase check step %d: now %d + delay %d -> %d, search had %d (mod %d)" % [i + 1, int(round(c * 60.0)), int(opt.delay),
				posmod(int(round(c * 60.0)) + int(opt.delay), P), posmod(3 + int(found[i].delay), P), P])
		var ok := await perform(steps[i], opt, true)
		print("    replay step %d -> %s at %s %s" % [i + 1, ok, player.global_position - room.global_position, player.state_name()])
		if not ok:
			check(false, "%s continuous replay breaks at step %d (%s) — ended at %s, %s, room %s" % [name, i + 1, steps[i].to,
				player.global_position - room.global_position, player.state_name(), world.current_room.name])
			return
	print("  REPLAY %s: entrance to goal in one continuous run" % name)


## The search found a delay measured from a fresh room clock; live, the room
## clock is wherever the run has got it to (plus `ahead` frames of legs still to
## run before the timed one). Wait until the same phase comes round.
func _phase_delay(step: Dictionary, opt: Dictionary, ahead: int) -> int:
	var period := maxi(int(step.wait), 1)
	var clock := 0.0
	for prop in world.props:
		if prop.kind == "Patrol" and prop.get_parent().get_parent() == room: clock = prop.clock
	var now := int(round(clock * 60.0)) + ahead
	# A search attempt starts 3 settle frames + its delay after a clock reset.
	return posmod(3 + int(opt.delay) - now, period)


## Line up on the step's start the way a player does before a jump: walk (or
## swim) over to it on whatever he is standing in, then stop.
func approach(step: Dictionary) -> void:
	var x: float = room.global_position.x + float(step.from[0])
	for attempt in 40:
		var dx := x - player.global_position.x
		if absf(dx) < 2.0: break
		Input.action_release("move_left"); Input.action_release("move_right")
		Input.action_press("move_right" if dx > 0 else "move_left")
		if absf(dx) > 16.0:
			# Walk most of the way, letting go early enough to slide in.
			while absf(x - player.global_position.x) > 10.0 and signf(x - player.global_position.x) == signf(dx):
				await frames(1)
		else:
			await frames(2)  # the last few pixels in taps
		release()
		await _stop()
	release()


## Until he has actually come to rest (child Hooshang takes ~14 frames to stop).
func _stop() -> void:
	for i in 40:
		if absf(player.velocity.x) < 1.0 and (player.is_on_floor() or player.swimming()): break
		await frames(1)


func settle() -> void:
	release()
	await frames(SETTLE)
	await _stop()
	# Water: let him float back up to the surface rather than kicking from depth.
	for i in 120:
		if not player.swimming(): break
		var surface: float = world.surface_y_at(player.global_position)
		if is_finite(surface) and player.global_position.y - surface < 12.0 and absf(player.velocity.y) < 10.0: break
		await frames(1)


func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame


func release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "dash"]: Input.action_release(a)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL ", message)
