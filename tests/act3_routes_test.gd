extends Node
## Proves every Act III room is solvable with REAL INPUT — no velocity or
## position writes during a move. Routes come from tools/build_act3_world.py
## (resources/levels/act3_routes.json, drawn in tools/act3_rooms.py): each room
## is a list of steps from one point to the next — a standing point, a point in
## the water, or through a portal into the next room.
##
## The prison's harness (tests/prison_wings_routes_test.gd) taught the method,
## and this adds the sea's moves to it:
##   swim       steer in 2D through the step's waypoints (`path`)
##   divechain  the same, pressing the Dive toward the next waypoint whenever it
##              is back (bubble and bell chains)
##   float      bob at the surface, then the step's Dive / air dash at a frame
##   jump/run/walk  as on land
## A step may also list `dive` and `dash` directions, searched over a few frames.
##
## Two passes per room:
##   1. SEARCH each step on its own from its start point; the trial count is
##      printed, and a step that only works from the exact pixel is FRAGILE.
##   2. REPLAY the found inputs back to back from the room's start, so bubbles,
##      crumbling planks, thoughts and the ink are met the way a player meets them.
##
## Story beats are switched off (memories marked remembered, Rumi's triggers
## spent) — they lock the player, and they are covered by their own tests.
##
## Headless:  Godot --headless --path . --fixed-fps 60 res://tests/act3_routes_test.tscn
## Subset:    ... res://tests/act3_routes_test.tscn -- Act3_Level_5 Act3_Level_6 [--trace]
##
## --playthrough  the whole act as ONE run, the way a player meets it: after the
##   search, a fresh world with the story ON, starting at the shore with nothing
##   but the dash, plays every room's found inputs back to back. He reaches each
##   room only by crossing its portal; conversations are held through with
##   `skip_dialogue`; a death sends him back to the step nearest his checkpoint;
##   the floor's stillness is waited out standing still; and the ascent, the
##   office and the real sea are walked to the act's results screen and on to
##   the title. Any room reached any other way is a failure.
const DASH_FRAMES := [3, 7, 11, 16, 22]
const DIVE_FRAMES := [1, 6, 14, 26, 40, 60]
const JUMP_HOLDS := [60, 16, 7]
const SETTLE := 8
var world: SeaWorld
var player: Player
var room: Node2D
var failures := 0
var trials := 0
var used_frames := 0
var trace := false
var fragile := 0
var playthrough := false
## --from <room>: start the play-through there (opened cold, as the chapter
## browser does) instead of at the shore. For iterating on one room.
var play_from := ""
## Set by perform() when a story beat took his controls mid-step.
var interrupted := false
var _skip_frames := 0


func _ready() -> void:
	get_tree().create_timer(7200.0, true, false, true).timeout.connect(func():
		print("ACT3_ROUTES: TIMEOUT"); get_tree().quit(3))
	SaveGame.unbind()
	Sfx.muted = true
	var routes_text := FileAccess.get_file_as_string("res://resources/levels/act3_routes.json")
	var routes: Dictionary = JSON.parse_string(routes_text)
	var only := OS.get_cmdline_user_args()
	trace = "--trace" in only
	if trace:
		only.remove_at(only.find("--trace"))
	playthrough = "--playthrough" in only
	if playthrough:
		only.remove_at(only.find("--playthrough"))
	var use_cache := "--cache" in only
	if use_cache:
		only.remove_at(only.find("--cache"))
	var from_at := only.find("--from")
	if from_at >= 0 and from_at + 1 < only.size():
		play_from = only[from_at + 1]
		only.remove_at(from_at + 1)
		only.remove_at(from_at)
	LdtkWorld.debug_start_room = "Act3_Level_0"
	world = load("res://ldtk/Act3World.tscn").instantiate()
	world.set_meta("no_beats", true)
	Screen.set_scene(world)
	await frames(30)
	player = world.player
	player.has_dash = true
	_check_rumi_pillars()
	_quiet_story()
	var names := routes.keys()
	names.sort_custom(func(a, b): return LdtkWorld.index_in_name(a) < LdtkWorld.index_in_name(b))
	var plans := {}
	# --cache: reuse the inputs an earlier run found, as long as the routes they
	# were found for have not changed. Skips the search, the slow part.
	var cached := _load_plans(routes_text) if use_cache else {}
	for name: String in names:
		if not only.is_empty() and name not in only:
			continue
		if cached.has(name):
			plans[name] = cached[name]
			continue
		room = null
		for r in world.rooms:
			if str(r.name) == name:
				room = r
		if room == null:
			check(false, "%s exists" % name)
			continue
		player.has_swim_dash = LdtkWorld.index_in_name(name) >= LdtkWorld.index_in_name("Act3_Level_4")
		var steps: Array = routes[name]
		var found: Array = []
		var ok := true
		print("== %s" % name)
		for i in steps.size():
			var params = await search(steps[i], "%s step %d" % [name, i + 1])
			if params == null:
				ok = false
				break
			found.append(params)
		if ok:
			plans[name] = found
			if not playthrough:
				await replay(name, steps, found)
	if use_cache:
		_save_plans(routes_text, plans)
	if playthrough:
		await play_through(routes, plans, names)
	print("ACT3_ROUTES: %d failures, %d fragile steps, %d trials" % [failures, fragile, trials])
	get_tree().quit(0 if failures == 0 else 1)


const PLAN_CACHE := "user://act3_route_plans.json"


## The routes, the rooms AND the movement they were found with: a redrawn room,
## a slower stroke or a longer Dive makes every cached input a guess.
func _plan_key(routes_text: String) -> String:
	return (routes_text + FileAccess.get_md5("res://ldtk/hooshang_act3.ldtk") + "|%s|%s|%s|%s|%s|%s" % [player.swim_speed, player.swim_accel,
		player.swim_max_sink_speed, player.swim_dash_speed, player.swim_dash_time, player.max_run_speed]).md5_text()


func _load_plans(routes_text: String) -> Dictionary:
	if not FileAccess.file_exists(PLAN_CACHE):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAN_CACHE))
	if not data is Dictionary or str(data.get("routes_md5", "")) != _plan_key(routes_text):
		print("  (plan cache is stale or missing; searching)")
		return {}
	print("  (reusing %d rooms' inputs from %s)" % [(data.plans as Dictionary).size(), PLAN_CACHE])
	return data.plans


func _save_plans(routes_text: String, plans: Dictionary) -> void:
	var merged := _load_plans(routes_text)
	merged.merge(plans, true)
	var f := FileAccess.open(PLAN_CACHE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"routes_md5": _plan_key(routes_text), "plans": merged}))


## Every Rumi trigger is a tall pillar; in the sea's stacked rooms one that
## pokes through a floor or ceiling fires its scene in the wrong room (room 4's
## gift used to go off in room 3). sea_import.gd clips them; this holds it.
func _check_rumi_pillars() -> void:
	for r in world.rooms:
		var bounds := world.room_rect(r).grow(0.5)
		for node in r.find_children("*", "Area2D", true, false):
			if not node is LdtkRumiTrigger:
				continue
			for shape in node.get_children():
				if shape is CollisionShape2D and (shape as CollisionShape2D).shape is RectangleShape2D:
					var size := ((shape as CollisionShape2D).shape as RectangleShape2D).size
					var area := Rect2((shape as Node2D).global_position - size * 0.5, size)
					check(bounds.encloses(area), "%s's Rumi trigger stays inside its room (%s vs %s)" % [r.name, area, bounds])


## Memories and Rumi lock the player for a conversation; the route is about the
## platforming, so they are marked done before anything runs.
func _quiet_story() -> void:
	for m in get_tree().get_nodes_in_group("sea_memory"):
		(m as SeaMemory).done = true
	for t in get_tree().get_nodes_in_group("rumi_trigger"):
		t.set("_fired", true)
	for r in world.rooms:
		for n in r.find_children("*", "Area2D", true, false):
			if n is LdtkRumiTrigger:
				n.set("_fired", true)


# ------------------------------------------------------------------ search --

func search(step: Dictionary, label: String):
	var options := options_for(step)
	var tried := 0
	var fallback = null
	for opt: Dictionary in options:
		tried += 1
		trials += 1
		await stand_at(step)
		var result := await perform(step, opt, false)
		if trace:
			print("    try %s -> %s at %s state %s" % [_describe(opt), result,
				player.global_position - room.global_position, player.state_name()])
		if not result:
			continue
		opt["frames"] = used_frames + 1
		var robust := true
		if not step.get("hurry", false) and not step.to.has("portal"):
			for nudge in [-3.0, 3.0]:
				await stand_at(step, nudge)
				if not await perform(step, opt, false):
					robust = false
					break
		if robust:
			print("  ok   %-24s after %4d/%d tries  %s" % [label, tried, options.size(), _describe(opt)])
			return opt
		if fallback == null:
			fallback = opt
	if fallback != null:
		print("  FRAGILE %-21s only exact-pixel inputs work: %s" % [label, _describe(fallback)])
		fragile += 1
		return fallback
	check(false, "%s: no input reaches %s from %s (%d tries)" % [label, step.to, step.from, tried])
	return null


## Every input the search may try for a step: start delays, moves, jump holds,
## and Dive and dash directions at a few timings.
func options_for(step: Dictionary) -> Array:
	var options: Array = []
	var delays: Array = [0]
	if step.has("wait"):
		delays = range(0, int(step.wait), 10)
	var moves: Array = step.get("moves", ["jump"]).duplicate()
	if "jump" in moves and not "run" in moves:
		moves.insert(moves.find("jump") + 1, "run")
	var dashes: Array = step.get("dash", [])
	var dives: Array = step.get("dive", [])
	for delay in delays:
		for move: String in moves:
			# For a Dive chain, `hold` is the stall threshold instead: Dive again
			# once his speed toward the next waypoint drops under it (20 = only
			# when a current has stopped him, 999 = the moment it is back).
			var holds: Array = JUMP_HOLDS if move in ["jump", "run"] else ([20, 60, 999] if move == "divechain" else [4])
			for hold in holds:
				var dive_opts: Array = [["", -1]]
				for d: String in dives:
					for f in DIVE_FRAMES:
						dive_opts.append([d, f])
				var dash_opts: Array = [["", -1]]
				for d: String in dashes:
					for f in DASH_FRAMES:
						dash_opts.append([d, f])
				for dv: Array in dive_opts:
					for ds: Array in dash_opts:
						options.append({"delay": delay, "move": move, "hold": hold,
							"dive": dv[0], "dive_frame": dv[1], "dash": ds[0], "dash_frame": ds[1]})
	return options


func _describe(opt: Dictionary) -> String:
	var s: String = "%s(hold %d)" % [opt.move, opt.hold]
	if opt.dive != "":
		s += " dive %s@%d" % [opt.dive, opt.dive_frame]
	if opt.dash != "":
		s += " dash %s@%d" % [opt.dash, opt.dash_frame]
	if opt.delay > 0:
		s += " after %d" % opt.delay
	return s


func stand_at(step: Dictionary, nudge := 0.0) -> void:
	await settle_dead()
	if world.current_room != room:
		world._enter_room(room, true)
		await frames(2)
	CrumblingPlatform.reset_all(get_tree())
	DarkThought.reset_all(get_tree())
	AirBubble.reset_all(get_tree())
	InkFlood.reset_all(get_tree())
	release()
	var f: Dictionary = step.from
	var at := room.global_position + Vector2(float(f.x) + nudge, float(f.y))
	if not f.get("water", false):
		at.y -= Player.HALF_HEIGHT
	player.respawn(at)
	player.input_locked = false
	await frames(3)


func settle_dead() -> void:
	release()
	for i in 240:
		if player.state != Player.State.DEAD and not world._transitioning:
			return
		await frames(1)


# ----------------------------------------------------------------- perform --

func _waypoints(step: Dictionary) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for c in step.get("path", []):
		pts.append(room.global_position + Vector2(float(c[0]) * 8.0 + 4.0, float(c[1]) * 8.0 + 4.0))
	var to: Dictionary = step.to
	# Into a portal: carry on 12px past the last waypoint in the direction it
	# was heading, so the swimmer crosses the seam rather than stopping short.
	# Toward whichever room edge the last waypoint is nearest: that is the edge
	# the portal is on.
	if to.has("portal") and pts.size() >= 1:
		var last := pts[pts.size() - 1]
		var r := world.room_rect(room)
		var edges := {Vector2.LEFT: last.x - r.position.x, Vector2.RIGHT: r.end.x - last.x,
			Vector2.UP: last.y - r.position.y, Vector2.DOWN: r.end.y - last.y}
		var best := Vector2.DOWN
		for e: Vector2 in edges:
			if edges[e] < edges[best]:
				best = e
		pts.append(last + best * (edges[best] + 16.0))
	if to.has("x") and to.has("y"):
		var goal := room.global_position + Vector2(float(to.x), float(to.y))
		if not to.get("water", false):
			goal.y -= Player.HALF_HEIGHT
		pts.append(goal)
	return pts


func _dir_name_to_vec(d: String) -> Vector2:
	var v := Vector2.ZERO
	if "r" in d: v.x += 1
	if "l" in d: v.x -= 1
	if "u" in d: v.y -= 1
	if "d" in d: v.y += 1
	return v


func _press_dir(v: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if v.x > 0.0: Input.action_press("move_right")
	if v.x < 0.0: Input.action_press("move_left")
	if v.y < 0.0: Input.action_press("move_up")
	if v.y > 0.0: Input.action_press("move_down")


## One attempt at one step from wherever the player stands now.
func perform(step: Dictionary, opt: Dictionary, live: bool) -> bool:
	# Waiting for the right moment, a swimmer HOLDS station — in a current,
	# idling is drifting, and a player swims against it while they wait.
	var hold_at := player.global_position
	if step.from.get("water", false):
		hold_at = room.global_position + Vector2(float(step.from.x), float(step.from.y))
	for i in int(opt.delay):
		if player.state == Player.State.DEAD:
			release()
			if live:
				print("      died WAITING at %s" % (player.global_position - room.global_position))
			return false
		if player.swimming():
			var d := hold_at - player.global_position
			_press_dir(Vector2(0.0 if absf(d.x) < 2.0 else signf(d.x), 0.0 if absf(d.y) < 2.0 else signf(d.y)))
		await frames(1)
	release()
	var to: Dictionary = step.to
	var pts := _waypoints(step)
	var wp := 0
	var goal_x: float = room.global_position.x + float(step.get("steer", to.get("x", step.from.x)))
	var steer_x: float = room.global_position.x + float(step.steer_first) if step.has("steer_first") else goal_x
	var start_room: Node = world.current_room
	var move: String = opt.move
	var swimmy := move in ["swim", "divechain", "float"]
	var airborne := false
	var air_frames := -1
	var floor_frames := 0
	var dash_release := -1
	var dive_release := -1
	var run_jump_at := -1
	if move == "jump":
		Input.action_press("jump")
	used_frames = 0
	for i in int(step.get("frames", 1500 if swimmy else 600)):
		used_frames = i
		var pos := player.global_position
		# Steering.
		if swimmy and player.swimming() and move != "float":
			while wp < pts.size() - 1 and pos.distance_to(pts[wp]) < 6.0:
				wp += 1
			var aim := Vector2.ZERO
			if wp < pts.size():
				var d := pts[wp] - pos
				aim = Vector2(0.0 if absf(d.x) < 2.5 else signf(d.x), 0.0 if absf(d.y) < 2.5 else signf(d.y))
			if dive_release < 0 or i > dive_release:
				_press_dir(aim)
			var toward := player.velocity.dot((pts[wp] - pos).normalized()) if wp < pts.size() else 0.0
			# 20/60: only once a current is holding him back; 999: whenever back.
			var held := player.current_flow() != Vector2.ZERO or float(opt.hold) > 500.0
			if move == "divechain" and player.has_swim_dash and player.swim_dash_available \
					and not player.diving() and aim != Vector2.ZERO and wp < pts.size() \
					and toward < float(opt.hold) and held:
				var to_wp := pts[wp] - pos
				var q := Vector2(roundf(to_wp.normalized().x), roundf(to_wp.normalized().y))
				_press_dir(q)
				Input.action_press("dash")
				dive_release = i + 2
		elif not player.swimming() or move in ["walk", "run", "jump"]:
			var target_x := pts[wp].x if swimmy and wp < pts.size() else steer_x
			Input.action_release("move_left"); Input.action_release("move_right")
			if not player.swimming() or not swimmy:
				if absf(target_x - pos.x) > 2.5:
					Input.action_press("move_right" if target_x > pos.x else "move_left")
		if move == "run" and run_jump_at < 0 and airborne:
			Input.action_press("jump")
			run_jump_at = i
		if move == "run" and run_jump_at >= 0 and i == run_jump_at + int(opt.hold):
			Input.action_release("jump")
		if move == "jump" and i == int(opt.hold):
			Input.action_release("jump")
		if opt.dive != "" and i == int(opt.dive_frame) and player.swimming():
			_press_dir(_dir_name_to_vec(str(opt.dive)))
			Input.action_press("dash")
			dive_release = i + 6
		if opt.dash != "" and air_frames == int(opt.dash_frame) and not player.swimming():
			_press_dir(_dir_name_to_vec(str(opt.dash)))
			Input.action_press("dash")
			dash_release = i + 6
		if i == dash_release or i == dive_release:
			for a in ["dash", "move_up", "move_down"]:
				Input.action_release(a)
		elif move == "divechain" and i == dive_release - 1:
			Input.action_release("dash")
		await frames(1)
		if trace and i % 6 == 0:
			var thoughts := ""
			for t in get_tree().get_nodes_in_group("dark_thought"):
				if room.is_ancestor_of(t):
					thoughts += " T%s c%.2f" % [((t as Node2D).global_position - room.global_position).round(), (t as DarkThought)._clock]
			print("      f%d %s %s v%s%s" % [i, player.global_position - room.global_position, player.state_name(), player.velocity, thoughts])
		if player.state == Player.State.DEAD:
			release()
			return false
		if world.current_room != start_room:
			# A portal: wait out the slide, then judge where it went.
			for k in 60:
				if not world._transitioning:
					break
				await frames(1)
			release()
			return to.has("portal") and str(world.current_room.name) == str(to.portal)
		if world._transitioning:
			continue
		if live and player.input_locked:
			release()
			interrupted = true
			return false
		var on_floor := player.is_on_floor() and not player.swimming()
		if not on_floor and not player.swimming():
			airborne = true
		if airborne and not player.swimming():
			air_frames += 1
		if player.swimming():
			air_frames = -1
		var local := player.global_position - room.global_position
		if to.get("water", false) and player.swimming() and i > 4 \
				and local.distance_to(Vector2(float(to.x), float(to.y))) <= float(to.get("tol", 12)):
			release()
			return true
		if to.has("x") and not to.get("water", false) and on_floor:
			floor_frames += 1
			var feet := local.y + Player.HALF_HEIGHT
			var hit := absf(local.x - float(to.x)) <= float(to.get("tol", 8)) and absf(feet - float(to.y)) <= 3.0
			if hit and floor_frames >= 2:
				release()
				return true
			if floor_frames >= 14 and not hit and absf(player.velocity.x) < 3.0 and i > 24 \
					and player.state in [Player.State.IDLE, Player.State.RUN] and move != "swim":
				release()
				return false
		else:
			floor_frames = 0
	release()
	return false


# ------------------------------------------------------------- playthrough --

func play_through(routes: Dictionary, plans: Dictionary, names: Array) -> void:
	print("== PLAYTHROUGH: a fresh arrival, story on, from the shore to the results")
	release()
	LdtkWorld.debug_start_room = play_from
	if play_from != "":
		names = names.filter(func(n): return LdtkWorld.index_in_name(n) >= LdtkWorld.index_in_name(play_from))
	# What Act II's ending hands over: its world state, which carries the dash.
	SaveGame._pending = {"world_state": {"has_dash": true}}
	world = load("res://ldtk/Act3World.tscn").instantiate()
	Screen.set_scene(world)
	await frames(10)
	player = world.player
	_deaths_seen = Deaths.total
	if play_from == "":
		check(not player.has_swim_dash, "PLAYTHROUGH: a fresh arrival starts without the Dive")
	var seen := world.story.keys()
	for name: String in names:
		if not plans.has(name):
			check(false, "PLAYTHROUGH: %s has no proven route to play" % name)
			return
		if not await until_control("arriving in %s" % name):
			return
		if str(world.current_room.name) != name:
			check(false, "PLAYTHROUGH: expected to have crossed into %s, but he is in %s at %s" % [name,
				world.current_room.name, player.global_position - world.current_room.global_position])
			return
		room = world.current_room
		check(not player.swimming() or player.state in [Player.State.SWIM, Player.State.DASH],
			"PLAYTHROUGH: crossing into %s left him %s while still in the water" % [name, player.state_name()])
		if name == "Act3_Level_21":
			# The floor of the sea: stand still and let every thought pass.
			release()
			if not await until_flag("floor", 3600):
				return
		if not await play_room(name, routes[name], plans[name]):
			return
		var scenes := world.story.keys().filter(func(k): return k not in seen and str(k).begins_with("scene:"))
		seen = world.story.keys()
		print("  PLAYED %s -> %s %s" % [name, world.current_room.name, scenes if not scenes.is_empty() else ""])
		# Every scene set in this room has played by the time he leaves it.
		for scene: String in Act3Beats.SCENES:
			if Act3Beats.SCENES[scene] == name:
				check(bool(world.story.get("scene:" + scene, false)),
					"PLAYTHROUGH: %s's scene '%s' played before he left the room" % [name, scene])
		if name == "Act3_Level_4":
			check(player.has_swim_dash, "PLAYTHROUGH: he leaves the gift's room with the Dive")
	await play_ending()


## One room's found inputs, from wherever the last portal put him.
func play_room(name: String, steps: Array, found: Array) -> bool:
	var i := 0
	var deaths := 0
	var stalls := 0
	# What a player does after a death: try the step again, differently. The
	# found input first, then the step's other searched inputs in turn, always
	# from wherever the real run has left him.
	var tries := {}
	# After a beat stops him mid-step he is already partway along it: carry on
	# from there rather than walking back to its start (often a ledge above).
	var resume_here := false
	while i < steps.size():
		if not await until_control("%s step %d" % [name, i + 1]):
			return false
		if world.current_room != room:
			check(false, "PLAYTHROUGH: %s step %d left the room early, into %s" % [name, i + 1, world.current_room.name])
			return false
		if resume_here:
			resume_here = false
		elif not steps[i].get("hurry", false) or i == 0:
			if not steps[i].from.get("water", false):
				await approach(steps[i])
				await settle()
			else:
				await approach_water(steps[i])
		var opt: Dictionary = found[i].duplicate()
		var k: int = tries.get(i, 0)
		if k > 0:
			var alternatives := options_for(steps[i])
			opt = alternatives[(k - 1) % alternatives.size()].duplicate()
		var proven := opt.duplicate()
		if steps[i].has("wait"):
			opt.delay = _phase_delay(steps[i], proven)
			if trace:
				var clocks := []
				for t in get_tree().get_nodes_in_group("dark_thought"):
					clocks.append("%s:%.2f" % [t.get_path(), (t as DarkThought)._clock])
				print("      phase delay %d (input %s) clocks %s" % [opt.delay, _describe(proven), clocks])
		interrupted = false
		if await perform(steps[i], opt, true):
			i += 1
			stalls = 0
			continue
		var at := player.global_position - room.global_position
		if interrupted:
			print("    %s step %d: a beat took his controls at %s — carrying on" % [name, i + 1, at])
			# Close to the step's start (a memory sitting on it), go back and
			# make the step as proven; well along it, carry on from there.
			var f: Dictionary = steps[i].from
			var start := Vector2(float(f.x), float(f.y) - (0.0 if f.get("water", false) else Player.HALF_HEIGHT))
			resume_here = start.distance_to(at) > 24.0
			continue
		if player.state == Player.State.DEAD or _died_recently():
			deaths += 1
			tries[i] = tries.get(i, 0) + 1
			print("    %s step %d: died at %s (death %d, next try %s)" % [name, i + 1, at, deaths,
				_describe(options_for(steps[i])[(tries[i] - 1) % options_for(steps[i]).size()])])
			if deaths > 24:
				check(false, "PLAYTHROUGH: %s step %d kills him every time from a real arrival (last at %s)" % [name, i + 1, at])
				return false
			await settle_dead()
			# The world puts the room's hazards back two frames AFTER the
			# respawn (LdtkWorld._on_player_died waits out the return-door
			# check first); a phase read before then is a lap out of step.
			await frames(4)
			i = _nearest_step(steps)
			continue
		stalls += 1
		tries[i] = tries.get(i, 0) + 1
		print("    %s step %d: missed, ended at %s %s" % [name, i + 1, at, player.state_name()])
		if stalls > 6:
			check(false, "PLAYTHROUGH: %s step %d (%s) cannot be made from where a real run leaves him: %s %s" % [name,
				i + 1, steps[i].to, at, player.state_name()])
			return false
	return true


var _deaths_seen := 0
func _died_recently() -> bool:
	var now: int = Deaths.total
	var died := now > _deaths_seen
	_deaths_seen = now
	return died


## After a respawn, the step whose start is nearest where he stands.
func _nearest_step(steps: Array) -> int:
	var best := 0
	var best_d := INF
	var here := player.global_position - room.global_position
	for k in steps.size():
		var f: Dictionary = steps[k].from
		var p := Vector2(float(f.x), float(f.y) - (0.0 if f.get("water", false) else Player.HALF_HEIGHT))
		var d := p.distance_to(here)
		if d < best_d:
			best_d = d
			best = k
	return best


## The last three rooms are the story's: up through the white, out of the
## office door, down the beach into the water — then the results and the title.
func play_ending() -> void:
	print("  ending: in %s, waiting for control" % world.current_room.name)
	if not await until_control("the ascent"):
		return
	print("  ending: swimming up the ascent")
	check(str(world.current_room.name) == "Act3_Level_23", "PLAYTHROUGH: the pond's portal leads to the ascent")
	for i in 900:
		if bool(world.story.get("scene:ascent", false)) or str(world.current_room.name) != "Act3_Level_23":
			break
		_press_dir(Vector2.UP)
		await frames(1)
	release()
	check(bool(world.story.get("scene:ascent", false)), "PLAYTHROUGH: swimming up the ascent starts its scene")
	print("  ending: ascent started, waiting for the office")
	if not await until_flag("office", 3600):
		return
	print("  ending: in the office, walking to the door")
	check(str(world.current_room.name) == "Act3_Level_24", "PLAYTHROUGH: the ascent wakes him in the office")
	if not await walk_right_until(func(): return str(world.current_room.name) == "Act3_Level_25", "the office door"):
		return
	print("  ending: in the parking lot / real sea, walking to the water")
	if not await walk_right_until(func(): return bool(world.story.get("scene:sea", false)), "the real sea"):
		return
	print("  ending: the sea scene played, waiting for the results")
	# The results screen pauses the tree, this node with it. A player's presses
	# still reach it; this node has to keep running to make them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var results: Node = null
	for i in 3600:
		results = _results_screen()
		if results != null:
			break
		pump_skip()
		await frames(1)
	release_skip()
	check(results != null, "PLAYTHROUGH: the end of the act reaches the results screen")
	if results == null:
		return
	print("  ending: results up, pressing on to the title")
	# Leaving the results opens the title. With no title screen in the tree (this
	# test launched the world itself) MainMenu.open() changes scene, which frees
	# THIS node at the end of the frame, so the report is made from inside the
	# signal, before that happens.
	results.continued.connect(func():
		print("  PLAYED the ending: ascent, office, real sea, results, on to the title")
		print("ACT3_ROUTES: %d failures, %d fragile steps, %d trials" % [failures, fragile, trials])
		get_tree().quit(0 if failures == 0 else 1))
	for k in 4:
		for pressed in [true, false]:
			var ev := InputEventAction.new()
			ev.action = &"jump"
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await frames(20)
	check(false, "PLAYTHROUGH: the results screen lets him leave for the title")


func walk_right_until(done: Callable, what: String) -> bool:
	for i in 3600:
		if done.call():
			release()
			return true
		if player.input_locked or world._transitioning:
			release()
			pump_skip()
		else:
			release_skip()
			Input.action_press("move_right")
		await frames(1)
	release()
	check(false, "PLAYTHROUGH: walking right never reached %s (room %s, at %s)" % [what, world.current_room.name,
		player.global_position - world.current_room.global_position])
	return false


func _results_screen() -> Node:
	for child in get_tree().root.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("act_results.gd"):
			return child
	return null


## Hold `skip_dialogue` through whatever the story is doing until he has his
## controls back.
func until_control(what: String) -> bool:
	for i in 7200:
		var busy := player.input_locked or world._transitioning or player.state == Player.State.DEAD
		if not busy and i > 0:
			release_skip()
			return true
		release()
		pump_skip()
		await frames(1)
	release_skip()
	check(false, "PLAYTHROUGH: he never got his controls back (%s; room %s at %s)" % [what, world.current_room.name,
		player.global_position - world.current_room.global_position])
	return false


func until_flag(scene: String, max_frames: int) -> bool:
	for i in max_frames:
		if bool(world.story.get("scene:" + scene, false)):
			release_skip()
			print("  ok   scene %s after %d frames" % [scene, i])
			return true
		pump_skip()
		await frames(1)
	release_skip()
	check(false, "PLAYTHROUGH: scene '%s' never finished (room %s)" % [scene, world.current_room.name])
	return false


## Press ~1.2s, let go a moment, again: DialogueBox wants a fresh press for a
## conversation that opened while the button was already held.
func pump_skip() -> void:
	_skip_frames += 1
	if _skip_frames % 80 < 74:
		Input.action_press("skip_dialogue")
	else:
		Input.action_release("skip_dialogue")


func release_skip() -> void:
	Input.action_release("skip_dialogue")
	_skip_frames = 0


# ------------------------------------------------------------------ replay --

func replay(name: String, steps: Array, found: Array) -> void:
	await stand_at(steps[0])
	for i in steps.size():
		var opt: Dictionary = found[i].duplicate()
		if i > 0 and not steps[i].get("hurry", false):
			if not steps[i].from.get("water", false):
				await approach(steps[i])
				await settle()
			else:
				await approach_water(steps[i])
		if steps[i].has("wait"):
			opt.delay = _phase_delay(steps[i], found[i])
		var ok := await perform(steps[i], opt, true)
		print("    replay step %d -> %s at %s %s" % [i + 1, ok, player.global_position - room.global_position, player.state_name()])
		if not ok:
			check(false, "%s continuous replay breaks at step %d (%s) — ended at %s, %s, room %s" % [name, i + 1,
				steps[i].to, player.global_position - room.global_position, player.state_name(), world.current_room.name])
			return
	print("  REPLAY %s: start to finish in one continuous run" % name)


## The search measured its delay from a fresh room clock (3 settle frames in);
## live, every thought in the room has been running since the room was entered.
## Wait for the same phase of the step's period to come round.
func _phase_delay(step: Dictionary, opt: Dictionary) -> int:
	var period := maxi(int(step.wait), 1)
	var clock := 0.0
	for t in get_tree().get_nodes_in_group("dark_thought"):
		if room.is_ancestor_of(t):
			clock = (t as DarkThought)._clock
			break
	var now := int(round(clock * 60.0))
	return posmod(3 + int(opt.delay) - now, period)


## Line up on a land step's start the way a player does before a jump.
func approach(step: Dictionary) -> void:
	var x: float = room.global_position.x + float(step.from.x)
	for attempt in 40:
		var dx := x - player.global_position.x
		if absf(dx) < 2.0 or player.swimming():
			break
		Input.action_release("move_left"); Input.action_release("move_right")
		Input.action_press("move_right" if dx > 0 else "move_left")
		if absf(dx) > 16.0:
			for k in 600:
				if absf(x - player.global_position.x) <= 10.0 or signf(x - player.global_position.x) != signf(dx) \
						or player.input_locked or player.state == Player.State.DEAD:
					break
				await frames(1)
		else:
			await frames(2)
		release()
		for k in 30:
			if absf(player.velocity.x) < 1.0:
				break
			await frames(1)
	release()


## Swim to a water step's start and come to rest there, as the search did.
func approach_water(step: Dictionary) -> void:
	var at := room.global_position + Vector2(float(step.from.x), float(step.from.y))
	for k in 240:
		var d := at - player.global_position
		if d.length() < 2.0 or not player.swimming():
			break
		_press_dir(Vector2(0.0 if absf(d.x) < 1.5 else signf(d.x), 0.0 if absf(d.y) < 1.5 else signf(d.y)))
		await frames(1)
	release()


func settle() -> void:
	release()
	await frames(SETTLE)
	for i in 40:
		if absf(player.velocity.x) < 1.0 and (player.is_on_floor() or player.swimming()):
			break
		await frames(1)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "dash"]:
		Input.action_release(a)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL ", message)
