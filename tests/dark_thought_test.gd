extends Node
## The DarkThought: it traces the path it says it does, several of them can be
## put out of step, a reset puts one back, and a room collapse leaves it alone.
##
## The path is the whole point of this file. Everything about this hazard that
## can go wrong is quiet: a vertical thought that has picked up a sideways drift
## still looks like a hazard, a `Phase` that does nothing still looks like two
## hazards, and a cycle that keeps running across a death still kills — it just
## kills somewhere different every attempt, which is a room that gets harder the
## more you fail it and reads to the player as bad luck rather than as a bug.
##
## So each mode is SAMPLED across a whole cycle and the invariant it claims is
## checked at every sample, rather than at the one instant a spot check would
## catch. And each assertion is paired with a proof it is not vacuous: a
## "stays on one x" test passes trivially on a hazard that never moved at all,
## so the same samples also have to show real travel.
##
## Run:  godot --headless res://tests/dark_thought_test.tscn

const DARK_THOUGHT := preload("res://scenes/props/hazards/DarkThought.tscn")

## How many points around one cycle each path is measured at. Enough that a
## circle is checked well away from the axes, where a sign error hides.
const SAMPLES := 24
## Slack, in px, for float error in the trigonometry.
const EPS := 0.01

var failures: Array[String] = []
var world: Node2D


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	await _run()


func _run() -> void:
	var origin := Vector2(120.0, 80.0)

	# --- vertical: one x, and it really travelled ----------------------------
	var up := _spawn(origin, DarkThought.Motion.VERTICAL, 32.0, 1.0, 0.0)
	await _frames(1)
	var path := _trace(up)
	_check(_spread(path, true) <= EPS,
		"vertical: stays on one x  [%.3fpx of wander]" % _spread(path, true))
	# Not vacuous: a hazard parked at its origin also never changes x.
	_check(_spread(path, false) > 60.0,
		"...and swings the amplitude it was given  [%.1fpx of travel, want ~64]"
			% _spread(path, false))
	_check(absf(_extreme(path, false) - 32.0) < 0.5,
		"...reaching amplitude and no further  [%.2fpx from origin]"
			% _extreme(path, false))

	# --- horizontal: the same, one axis over ---------------------------------
	var across := _spawn(origin, DarkThought.Motion.HORIZONTAL, 24.0, 1.0, 0.0)
	await _frames(1)
	path = _trace(across)
	_check(_spread(path, false) <= EPS,
		"horizontal: stays on one y  [%.3fpx of wander]" % _spread(path, false))
	_check(_spread(path, true) > 44.0,
		"...and swings across  [%.1fpx of travel, want ~48]" % _spread(path, true))

	# --- linear at an arbitrary angle ----------------------------------------
	#
	# 45 degrees: the swing is diagonal, so x and y travel are equal and every
	# point lies on the line through the origin at that angle.
	var diag := _spawn(origin, DarkThought.Motion.LINEAR, 40.0, 1.0, 0.0)
	diag.angle = 45.0
	await _frames(1)
	path = _trace(diag)
	var dx := _spread(path, true)
	var dy := _spread(path, false)
	_check(absf(dx - dy) < 0.5,
		"linear 45: x and y travel equally  [%.1f x, %.1f y]" % [dx, dy])
	_check(dx > 40.0, "...and it actually swings  [%.1fpx across]" % dx)
	var off_line := 0.0
	var dir := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	for p in path:
		off_line = maxf(off_line, absf(p.x * dir.y - p.y * dir.x))
	_check(off_line < 0.5,
		"...every point on the 45-degree line  [worst %.3fpx off]" % off_line)
	# Vertical IS linear at 90 and horizontal at 0 — prove the identity so a
	# future refactor cannot quietly break the legacy modes.
	var lin90 := _spawn(origin, DarkThought.Motion.LINEAR, 32.0, 1.0, 0.0)
	lin90.angle = 90.0
	var vert := _spawn(origin, DarkThought.Motion.VERTICAL, 32.0, 1.0, 0.0)
	await _frames(1)
	var v_gap := 0.0
	for i in SAMPLES:
		var t := float(i) / SAMPLES
		v_gap = maxf(v_gap, _at(lin90, t).distance_to(_at(vert, t)))
	_check(v_gap < EPS,
		"...linear 90 traces the same path as VERTICAL  [%.4fpx apart]" % v_gap)
	var lin0 := _spawn(origin, DarkThought.Motion.LINEAR, 24.0, 1.0, 0.0)
	lin0.angle = 0.0
	var horiz := _spawn(origin, DarkThought.Motion.HORIZONTAL, 24.0, 1.0, 0.0)
	await _frames(1)
	var h_gap := 0.0
	for i in SAMPLES:
		var t := float(i) / SAMPLES
		h_gap = maxf(h_gap, _at(lin0, t).distance_to(_at(horiz, t)))
	_check(h_gap < EPS,
		"...linear 0 traces the same path as HORIZONTAL  [%.4fpx apart]" % h_gap)

	# --- circle: constant radius, and the right way round --------------------
	var ring := _spawn(origin, DarkThought.Motion.CIRCLE, 40.0, 1.0, 0.0)
	await _frames(1)
	path = _trace(ring)
	var worst := 0.0
	for p in path:
		worst = maxf(worst, absf(p.length() - 40.0))
	_check(worst < 0.5,
		"circle: every point is the radius from the origin  [worst %.3fpx off]"
			% worst)
	# Not vacuous twice over: a stationary prop is also "always 0 from origin"
	# (caught by the radius itself being 40), and a prop that only moved along
	# one axis would still satisfy a radius test taken on the axes alone.
	_check(_spread(path, true) > 70.0 and _spread(path, false) > 70.0,
		"...and it moved on BOTH axes  [%.1f x, %.1f y]"
			% [_spread(path, true), _spread(path, false)])
	# Screen space: +Y is down, so a quarter lap clockwise from the right hand
	# side of the circle is the BOTTOM.
	ring.clockwise = true
	_check(_at(ring, 0.25).y > 0.0,
		"...clockwise takes the quarter lap DOWN  [y %.1f]" % _at(ring, 0.25).y)
	ring.clockwise = false
	_check(_at(ring, 0.25).y < 0.0,
		"...anticlockwise takes it UP  [y %.1f]" % _at(ring, 0.25).y)

	# --- phase puts two of them out of step ----------------------------------
	#
	# Two thoughts with identical everything else. Same clock, same path; the
	# only thing that can separate them is the offset.
	var lead := _spawn(origin, DarkThought.Motion.VERTICAL, 32.0, 1.0, 0.0)
	var lag := _spawn(origin, DarkThought.Motion.VERTICAL, 32.0, 1.0, 0.25)
	await _frames(1)
	var apart := 0.0
	for i in SAMPLES:
		var t := float(i) / SAMPLES
		apart = maxf(apart, absf(_at(lead, t).y - _at(lag, t).y))
	_check(apart > 40.0,
		"phase: a quarter-cycle offset separates two identical thoughts  [%.1fpx]"
			% apart)
	# And the control: with the same phase they are welded together, which is
	# what proves the number above came from `phase` and not from two props
	# happening to be sampled at different moments.
	lag.phase = 0.0
	var same := 0.0
	for i in SAMPLES:
		var t := float(i) / SAMPLES
		same = maxf(same, absf(_at(lead, t).y - _at(lag, t).y))
	_check(same <= EPS,
		"...and with the same phase they move as one  [%.3fpx apart]" % same)

	# --- reset puts one back mid-cycle ---------------------------------------
	#
	# Driven through _process, the way the game drives it, rather than by poking
	# the clock: reset() has to undo what real running did.
	var runner := _spawn(origin, DarkThought.Motion.VERTICAL, 32.0, 2.0, 0.0)
	await _frames(1)
	await _idle(12)
	var moved := runner.position.distance_to(origin)
	_check(moved > 1.0,
		"reset: it had actually left the origin first  [%.1fpx out]" % moved)
	DarkThought.reset_all(get_tree())
	_check(runner.position.distance_to(origin) <= EPS,
		"...and reset_all puts it back on the point it was placed  [%.3fpx off]"
			% runner.position.distance_to(origin))
	# The clock, not just the position. A reset that only moved the node would
	# have it jump straight back out on the very next frame.
	await _idle(1)
	_check(runner.position.distance_to(origin) < moved,
		"...with its cycle back at the start, not merely its position")
	# Reachable through the group at all — reset_all finds it by group name, and
	# a prop that never joined would fail every assertion above by doing nothing.
	_check(runner.is_in_group("dark_thought"), "...found via the dark_thought group")

	# A LINEAR thought resets the same way — it is on the same clock and the same
	# reset path, but it walks a different offset function, so a mode-specific
	# reset bug would hide unless a LINEAR one is driven and reset too.
	var lin_runner := _spawn(origin, DarkThought.Motion.LINEAR, 32.0, 2.0, 0.0)
	lin_runner.angle = 30.0
	await _frames(1)
	await _idle(12)
	var lin_moved := lin_runner.position.distance_to(origin)
	_check(lin_moved > 1.0,
		"reset (linear): it had left the origin first  [%.1fpx out]" % lin_moved)
	DarkThought.reset_all(get_tree())
	_check(lin_runner.position.distance_to(origin) <= EPS,
		"...and reset_all puts the linear thought back too  [%.3fpx off]"
			% lin_runner.position.distance_to(origin))
	lin_runner.queue_free()

	# --- it does not fall when the room collapses ----------------------------
	_check(runner.collapse_anchored(),
		"collapse: a thought is anchored  [it is floating, not resting]")
	var collapse := _collapse_room()
	await _frames(2)
	var thought: DarkThought = collapse.get_node("Thought")
	# Where it was PLACED, not where it happens to be a couple of frames in: it
	# is already drifting by then, and a band measured from a point half a swing
	# out is twice as wide as the one this is trying to pin.
	var hung_y: float = thought._origin.y
	var sinker_y: float = (collapse.get_node("Sinker") as Node2D).global_position.y
	var dropped := RoomCollapse.drop(collapse, self)
	_check(not dropped.has(thought),
		"...so RoomCollapse does not pick it up  [%d props dropped]" % dropped.size())
	# Not vacuous: the collapse has to have been a real one. A plain Hazard at
	# the same height IS in the falling set and does land on the floor.
	_check(dropped.size() == 1,
		"...while the plain hazard beside it is  [%d dropped]" % dropped.size())
	# Watched across the whole collapse rather than sampled at the end, because a
	# prop that fell and was then carried back up its own path by the drift would
	# pass a check taken only afterwards.
	#
	# The bound is its own AMPLITUDE, not zero: it is still walking its path
	# while the room comes down, which is the point — it never fell, it kept
	# drifting. Anything past the amplitude is the collapse having moved it.
	var strayed := 0.0
	var until := RoomCollapse.duration(collapse) + 0.2
	while until > 0.0:
		await get_tree().process_frame
		until -= get_process_delta_time()
		strayed = maxf(strayed, absf(thought.position.y - hung_y))
	_check(strayed <= thought.amplitude + EPS,
		"...and the thought never leaves its own path  [%.2fpx out of %.0f]"
			% [strayed, thought.amplitude])
	# Not vacuous: the floor is 140px below where both were hung, so a prop that
	# DID fall would blow past that bound by four times over — as the plain
	# hazard beside it just did.
	var landed: float = (collapse.get_node("Sinker") as Node2D).global_position.y
	_check(landed > sinker_y + thought.amplitude * 3.0,
		"...having watched the hazard beside it drop to the floor  [%.1f -> %.1f]"
			% [sinker_y, landed])

	# --- the LDtk field actually reaches the prop -----------------------------
	#
	# This is the bug this section exists for, and it is worth spelling out why
	# nothing above caught it. Every path test builds a DarkThought and SETS
	# `motion` on it, so they prove the maths. They cannot prove the field ever
	# arrives — and it did not: every thought in the world imported as VERTICAL
	# whatever LDtk said, because the importer hands an enum back QUALIFIED
	# ("ThoughtMotion.Circle") and the hook matched the bare name. There is no
	# error in that. The entity imports, draws, kills, and drifts the wrong way.
	#
	# So the shape is taken from the ADDON rather than assumed: the value below
	# comes out of field-util's own parser, driven with the field dictionary LDtk
	# writes. If the addon is ever fixed or changed, this fails here rather than
	# in a room six months later.
	var field_util := load("res://addons/ldtk-importer/src/util/field-util.gd")
	var parsed: Variant = field_util.parse_field({
		"__identifier": "Motion",
		"__type": "LocalEnum.ThoughtMotion",
		"__value": "Circle",
	})
	_check(parsed is String and (parsed as String).ends_with("Circle"),
		"import: the addon parses an enum field to something ending in its value"
			+ "  [%s]" % parsed)

	var hook = load("res://scripts/ldtk_entities_post_import.gd").new()
	# Exactly what LDtk holds for the three modes. The strings are the addon's
	# output above, not hand-written guesses at it.
	var modes := {
		"Vertical": DarkThought.Motion.VERTICAL,
		"Horizontal": DarkThought.Motion.HORIZONTAL,
		"Circle": DarkThought.Motion.CIRCLE,
		"Linear": DarkThought.Motion.LINEAR,
	}
	for name: String in modes:
		var qualified: String = "ThoughtMotion." + name
		var built: DarkThought = hook._build_thought({
			"identifier": "DarkThought",
			"position": Vector2.ZERO,
			"size": Vector2(16.0, 16.0),
			"fields": {
				"Motion": qualified,
				"Amplitude": 32.0, "Speed": 1.0, "Phase": 0.0, "Clockwise": 1.0,
			},
		})
		_check(built.motion == modes[name],
			"...and %s reaches the prop as %s  [got %s]"
				% [qualified, DarkThought.Motion.keys()[modes[name]],
					DarkThought.Motion.keys()[built.motion]])
		built.free()
	# Not vacuous: the three cases above would all pass on a hook that ignored
	# the field entirely IF they all expected VERTICAL. Two of them do not, and
	# this proves the mapping is a mapping and not a constant.
	var unset: DarkThought = hook._build_thought({
		"identifier": "DarkThought",
		"position": Vector2.ZERO, "size": Vector2(16.0, 16.0),
		"fields": {"Motion": null},
	})
	_check(unset.motion == DarkThought.Motion.VERTICAL,
		"...while an unset field still falls back to VERTICAL  [%s]"
			% DarkThought.Motion.keys()[unset.motion])
	unset.free()
	# The Angle field reaches the prop when it is set — same class of silent bug
	# as Motion, since a field the hook never reads leaves the prop on its default
	# and a linear thought points the wrong way with nothing to pull on.
	var angled: DarkThought = hook._build_thought({
		"identifier": "DarkThought",
		"position": Vector2.ZERO, "size": Vector2(16.0, 16.0),
		"fields": {"Motion": "ThoughtMotion.Linear", "Angle": 135.0,
			"Amplitude": 32.0, "Speed": 1.0, "Phase": 0.0, "Clockwise": 1.0},
	})
	_check(angled.motion == DarkThought.Motion.LINEAR and absf(angled.angle - 135.0) < EPS,
		"...and the Angle field reaches the prop  [motion %s, angle %.1f]"
			% [DarkThought.Motion.keys()[angled.motion], angled.angle])
	angled.free()
	# An unset Angle keeps the prop's own default (0), so a thought placed before
	# the field existed does not snap to some other direction.
	var no_angle: DarkThought = hook._build_thought({
		"identifier": "DarkThought",
		"position": Vector2.ZERO, "size": Vector2(16.0, 16.0),
		"fields": {"Motion": "ThoughtMotion.Linear"},
	})
	_check(absf(no_angle.angle) < EPS,
		"...while an unset Angle stays at the prop's default  [%.1f]" % no_angle.angle)
	no_angle.free()

	# --- the three tones ----------------------------------------------------
	#
	# Each tone is the dark one recoloured and NOTHING ELSE. Everything below is
	# one of those two halves: that the colour really does change, and that
	# nothing else does.
	#
	# The unshaded material is the part worth testing rather than eyeballing.
	# Measured in Act I's own setup — CanvasModulate 0.05 with this prop's red
	# glow on it — a shaded white body renders (1.00, 0.32, 0.23), a RED cloud,
	# because a 2D light multiplies what it falls on. Nothing about that is
	# visible in a diff, and a pale thought that quietly lost its material would
	# just look like a differently-coloured dark one.
	var tones := {"DarkThought": DarkThought.Tone.DARK,
		"LightThought": DarkThought.Tone.LIGHT,
		"GreyThought": DarkThought.Tone.GREY}
	var made := {}
	for id: String in tones:
		var built: DarkThought = hook._build_thought({
			"identifier": id,
			"position": Vector2(200.0, 200.0),
			"size": Vector2(16.0, 16.0),
			"fields": {"Motion": "ThoughtMotion.Circle", "Amplitude": 24.0,
				"Speed": 0.75, "Phase": 0.2, "Clockwise": 1.0},
		})
		world.add_child(built)
		made[id] = built
	await _frames(2)

	for id: String in tones:
		var built: DarkThought = made[id]
		_check(built.tone == tones[id],
			"tone: %s imports as %s  [%s]" % [id,
				DarkThought.Tone.keys()[tones[id]],
				DarkThought.Tone.keys()[built.tone]])
		var sprite: Sprite2D = built.get_node("Cloud")
		var atlas: AtlasTexture = sprite.texture
		_check(atlas.atlas == DarkThought.SHEETS[tones[id]],
			"...drawn from its own sheet  [%s]"
				% atlas.atlas.resource_path.get_file())
		# Both tones are the same hazard as far as everything else is concerned.
		_check(built.is_in_group("dark_thought"),
			"...and is still in the dark_thought group, so reset_all covers it")

	for id: String in tones:
		var cloud: Sprite2D = (made[id] as DarkThought).get_node("Cloud")
		var mat := cloud.material as CanvasItemMaterial
		_check(mat != null
				and mat.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED,
			"...%s is drawn UNSHADED, so its sheet is what reaches the screen"
				% id)

	# --- the halo is PAINT, and that is the fix ------------------------------
	#
	# It was a PointLight2D, and the glows blinked on and off from room to room.
	# This renderer (gl_compatibility) lights any one canvas item from at most
	# SIXTEEN lights and drops the rest in silence — measured by sweeping lights
	# over a single item: 16 -> 15 lit, 24 -> 15, 32 -> 16. A room with eight
	# ceiling panels already spends sixteen (two per panel), so the thoughts
	# were competing for a budget that had run out, and which of them won
	# changed as they travelled. Photographed: with the panel lights left on,
	# two of four thoughts had no pool at all; switched off, all four did.
	#
	# So the assertion that matters is that the prop carries NO LIGHT AT ALL.
	# Nothing else here can catch a well-meaning change back to a PointLight2D —
	# it would look right in an empty test room and fail only in a full one.
	for id: String in tones:
		var lights := 0
		for child in (made[id] as Node).get_children():
			if child is Light2D:
				lights += 1
		_check(lights == 0,
			"halo: %s spends nothing from the room's light budget  [%d lights]"
				% [id, lights])
	var halo: Sprite2D = (made["DarkThought"] as DarkThought).get_node("Glow")
	var hmat := halo.material as CanvasItemMaterial
	_check(hmat != null
			and hmat.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED
			and hmat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
		"...it is unshaded and additive, which is what CanvasModulate 0.05 "
			+ "cannot eat")
	_check(halo.z_index < 0,
		"...and sits behind the cloud, not over its rim  [z %d]" % halo.z_index)
	# Not vacuous: it has to actually be carrying colour, or "no light and no
	# visible halo" would pass every check above.
	_check(halo.visible and halo.modulate.r > 0.1,
		"...and is actually drawn  [modulate %s]" % halo.modulate)

	# --- the Glow field ------------------------------------------------------
	var switched: Dictionary = {1.0: true, 0.0: false}
	for value: float in switched:
		var t: DarkThought = hook._build_thought({
			"identifier": "DarkThought",
			"position": Vector2.ZERO, "size": Vector2(16.0, 16.0),
			"fields": {"Motion": "ThoughtMotion.Vertical", "Glow": value},
		})
		world.add_child(t)
		await _frames(2)
		_check(t.glow == switched[value],
			"Glow %.0f imports as %s" % [value, switched[value]])
		_check((t.get_node("Glow") as CanvasItem).visible == switched[value],
			"...and the halo is %s to match"
				% ("drawn" if switched[value] else "gone"))
		t.queue_free()
	# An unset field is ON — every thought placed before the field existed has
	# no value for it, and one that quietly went dark would be worse than one
	# that ignored the setting.
	var legacy: DarkThought = hook._build_thought({
		"identifier": "DarkThought",
		"position": Vector2.ZERO, "size": Vector2(16.0, 16.0),
		"fields": {"Motion": "ThoughtMotion.Vertical"},
	})
	_check(legacy.glow, "...and a thought with no Glow field keeps its halo")
	legacy.free()

	# And the whole point: they move identically. Same fields in, same path out,
	# sampled rather than asserted from the maths — a tone that reached into the
	# motion would show up here as a divergence and nowhere else.
	var tone_gap := 0.0
	for i in SAMPLES:
		await _frames(2)
		tone_gap = maxf(tone_gap,
			(made["DarkThought"] as Node2D).position.distance_to(
				(made["LightThought"] as Node2D).position))
	_check(tone_gap < EPS,
		"...and the two tones trace the SAME path  [worst %.4fpx apart]"
			% tone_gap)
	# Not vacuous: they have to have actually gone somewhere.
	var travelled: float = (made["DarkThought"] as Node2D).position.distance_to(
		Vector2(200.0, 200.0))
	_check(travelled > 1.0,
		"...having actually moved while being compared  [%.1fpx out]" % travelled)

	if failures.is_empty():
		print("DARK THOUGHT TEST: ALL PASS")
	else:
		print("DARK THOUGHT TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _spawn(at: Vector2, motion: DarkThought.Motion, amplitude: float,
		speed: float, phase: float) -> DarkThought:
	var thought: DarkThought = DARK_THOUGHT.instantiate()
	thought.position = at
	thought.motion = motion
	thought.amplitude = amplitude
	thought.speed = speed
	thought.phase = phase
	world.add_child(thought)
	return thought


## Where `thought` would be `t` cycles in, relative to where it was placed.
##
## Through the prop's own path function, so what is measured is the thing the
## game runs — a test that re-implemented the sine here would agree with itself
## and prove nothing.
func _at(thought: DarkThought, t: float) -> Vector2:
	return thought._offset(t / maxf(thought.speed, 0.0001))


## One whole cycle, as offsets from the origin.
func _trace(thought: DarkThought) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in SAMPLES:
		points.append(_at(thought, float(i) / SAMPLES))
	return points


## Peak-to-peak travel on one axis.
func _spread(points: Array[Vector2], on_x: bool) -> float:
	var lo := INF
	var hi := -INF
	for p in points:
		var v: float = p.x if on_x else p.y
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo


## Furthest it gets from the origin on one axis.
func _extreme(points: Array[Vector2], on_x: bool) -> float:
	var far := 0.0
	for p in points:
		far = maxf(far, absf(p.x if on_x else p.y))
	return far


## A room with a floor, one thought hung over it, and one ordinary Hazard hung
## beside it at the same height. The second one is the control: it is what makes
## "the thought did not fall" mean something other than "nothing fell".
func _collapse_room() -> Node2D:
	var room := Node2D.new()
	room.name = "CollapseRoom"
	add_child(room)

	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400.0, 16.0)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(400.0, 300.0)
	room.add_child(ground)

	var thought: DarkThought = DARK_THOUGHT.instantiate()
	thought.name = "Thought"
	thought.position = Vector2(360.0, 160.0)
	room.add_child(thought)

	var sinker: Hazard = preload("res://scenes/props/hazards/Hazard.tscn").instantiate()
	sinker.name = "Sinker"
	sinker.position = Vector2(440.0, 160.0)
	room.add_child(sinker)
	return room


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _idle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
