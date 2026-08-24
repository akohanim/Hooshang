extends Node
## The 8px conical spikes: they build on all four surfaces, and the lethal part
## of them is the CONES and not the whole cell.
##
## The kill region is the whole point of this file. Hazard.KILL_MARGIN insets 2px
## from every side, which is a sensible leniency on a 16px glass strip and is
## nonsense on an 8px cell — applied across 5px of cone it would leave a single
## pixel. ConeSpikes therefore uses its own TIP_LENIENCY on the across axis, and
## the two things that can go wrong with that are both silent:
##
##   - too generous, and the kill box swallows the BASE, so standing on the
##     safe-looking rubble at the bottom of the cell kills you;
##   - too mean, and the box shrinks to nothing and the hazard stops being one —
##     it still imports, still draws, and simply never fires.
##
## So the box is measured against the art's own two bands, and then checked
## THROUGH THE PHYSICS SERVER with a probe body rather than only in arithmetic:
## a rect this file computes agreeing with a rect this file expects proves
## nothing about what Godot will actually report as an overlap.
##
## Run:  godot --headless res://tests/cone_spikes_test.tscn

const CONE_SPIKES := preload("res://scenes/props/hazards/ConeSpikes.tscn")

var failures: Array[String] = []
var world: Node2D


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	await _run()


func _run() -> void:
	# --- all four facings build ----------------------------------------------
	#
	# Named by where the strip is STUCK, with the facing being where the points
	# aim — the pairing a direction field would let somebody get backwards.
	var facings := {
		"floor": ConeSpikes.Facing.UP,
		"ceiling": ConeSpikes.Facing.DOWN,
		"left wall": ConeSpikes.Facing.RIGHT,
		"right wall": ConeSpikes.Facing.LEFT,
	}
	for label in facings:
		var facing: ConeSpikes.Facing = facings[label]
		var wall: bool = facing == ConeSpikes.Facing.RIGHT \
			or facing == ConeSpikes.Facing.LEFT
		var spikes := _spawn(facing, Vector2(ConeSpikes.CELL, 5.0 * ConeSpikes.CELL)
			if wall else Vector2(5.0 * ConeSpikes.CELL, ConeSpikes.CELL))
		await _frames(2)
		var cones: Node2D = spikes.get_node("Cones")
		_check(cones.get_child_count() == 5,
			"%s: a five-cell strip lays five tiles  [%d]"
				% [label, cones.get_child_count()])
		# Every tile must come off that facing's OWN sheet. Four sheets and one
		# lookup is exactly the wiring a copy-paste gets wrong, and a ceiling
		# strip drawn from the floor sheet is upside down and lethal anyway.
		var wrong := 0
		for cell in cones.get_children():
			var atlas: AtlasTexture = (cell as Sprite2D).texture
			if atlas.atlas != ConeSpikes.SHEETS[facing]:
				wrong += 1
		_check(wrong == 0, "%s: ...all from that facing's sheet  [%d stray]"
			% [label, wrong])
		# The kill box leans towards the points, never the surface behind them.
		var shape: CollisionShape2D = _shape_of(spikes)
		var lean := shape.position.y if not wall else shape.position.x
		var want_negative: bool = facing == ConeSpikes.Facing.UP \
			or facing == ConeSpikes.Facing.LEFT
		_check((lean < 0.0) == want_negative and absf(lean) > 0.0,
			"%s: the kill box sits towards the points  [offset %.1f]" % [label, lean])
		spikes.queue_free()
		await _frames(1)

	# --- the lethal band is the cones, not the cell --------------------------
	var spikes := _spawn(ConeSpikes.Facing.UP,
		Vector2(ConeSpikes.CELL, ConeSpikes.CELL))
	await _frames(2)
	var box := _kill_rect(spikes)
	# In this prop's local space the cell spans -4..+4. The cones occupy the
	# first CONE_HEIGHT of that from the top; the base is everything under them.
	var cell_top := -ConeSpikes.CELL * 0.5
	var cone_bottom := cell_top + ConeSpikes.CONE_HEIGHT
	var cell_bottom := ConeSpikes.CELL * 0.5
	_check(is_equal_approx(box.end.y, cone_bottom),
		"the kill box stops exactly where the cones do  [%.1f, cones end %.1f]"
			% [box.end.y, cone_bottom])
	_check(box.position.y > cell_top,
		"...and starts below the very tip  [%.1f, cell top %.1f]"
			% [box.position.y, cell_top])
	_check(box.size.y > 1.0,
		"...and is still thick enough to be a hazard  [%.1fpx]" % box.size.y)
	# Not vacuous: the base is a real band, and the box has to miss all of it.
	_check(cell_bottom - cone_bottom >= 2.0,
		"the base is a band worth missing  [%.1fpx of the cell]"
			% (cell_bottom - cone_bottom))

	# --- and the physics server agrees ---------------------------------------
	#
	# A probe body on the player's own layer, small enough to sit inside one 8px
	# band. The real player is 12px tall and cannot fit in a 3px base, so a test
	# that used him could only ever prove the cones kill, never that the base
	# does not.
	var probe := _probe()
	world.add_child(probe)
	probe.global_position = spikes.global_position \
		+ Vector2(0.0, cone_bottom - 1.5)          # inside the cones
	await _frames(3)
	_check(spikes.get_overlapping_bodies().has(probe),
		"a body among the cones is detected")
	probe.global_position = spikes.global_position \
		+ Vector2(0.0, (cone_bottom + cell_bottom) * 0.5)   # inside the base
	await _frames(3)
	_check(not spikes.get_overlapping_bodies().has(probe),
		"a body standing in the base is NOT  [that is what makes the base safe]")

	# --- a longer strip stretches along, not across --------------------------
	spikes.size = Vector2(5.0 * ConeSpikes.CELL, ConeSpikes.CELL)
	await _frames(2)
	var long_box := _kill_rect(spikes)
	_check(is_equal_approx(long_box.size.y, box.size.y),
		"a five-cell strip is no deeper than a one-cell one  [%.1f vs %.1f]"
			% [long_box.size.y, box.size.y])
	_check(long_box.size.x > box.size.x * 3.0,
		"...it got longer instead  [%.1f vs %.1f]" % [long_box.size.x, box.size.x])

	if failures.is_empty():
		print("CONE SPIKES TEST: ALL PASS")
	else:
		print("CONE SPIKES TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _spawn(facing: ConeSpikes.Facing, size: Vector2) -> Area2D:
	var spikes: Area2D = CONE_SPIKES.instantiate()
	spikes.facing = facing
	spikes.size = size
	world.add_child(spikes)
	return spikes


func _shape_of(spikes: Area2D) -> CollisionShape2D:
	for child in spikes.get_children():
		if child is CollisionShape2D:
			return child
	return null


## The lethal region in the prop's own space.
func _kill_rect(spikes: Area2D) -> Rect2:
	var shape := _shape_of(spikes)
	var box: RectangleShape2D = shape.shape
	return Rect2(shape.position - box.size * 0.5, box.size)


## A small body on the player's collision layer, for asking the physics server
## what the hazard actually reports.
func _probe() -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = 2      # the player layer, which Hazard masks for
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2.0, 2.0)
	shape.shape = rect
	body.add_child(shape)
	return body


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
