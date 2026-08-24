extends Node
## Regression: a ONE-CELL shaft is a chimney you choose to enter.
##
## Level_1 has an 8px-wide slot cut down through its ceiling block. His hitbox is
## 9px across — a cell and an eighth — and a body that wide cannot pass through a
## one-cell slot at all, so he came to rest ON the lip with the whole drawn body
## hanging over the hole. Measured back when the box was exactly a cell, it
## entered that shaft from 0 of 33 approach positions across its mouth, and 7.99
## was no better; at 9 it does not even abut.
##
## A hole in the floor takes him, so nothing has to be pressed: standing over one
## narrows his box to squeeze_width, puts him down the middle of it and drops him
## in, and he wall-slides the shaft on the way down without being asked. The
## narrowing lasts only as long as he is in there — he is a full cell everywhere
## else, which is what stops him slipping through gaps nobody meant as a route.
##
## The slide has to be unprompted for a reason worth keeping: falling down the
## middle of a one-cell shaft never touches either wall (there is a pixel of
## clearance on both sides), so is_on_wall() is false the whole way down and the
## ordinary "press into the wall" rule would free-fall him between two walls he
## is practically resting on.
##
## THE SHAFT IS FOUND, NOT WRITTEN DOWN. Rooms have moved twice in this project
## and every hand-measured coordinate landed in the wrong room without anything
## failing (see tests/world_bounds_test.gd for that story). This sweeps the
## world for a one-cell column with solid either side and open sky above it, and
## asserts what it found before using it — a shaft two cells wide would make
## every check below pass while testing nothing.
##
## Run:  godot --headless res://tests/chimney_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var player: Player

const CELL := 8.0
## Half his hitbox, for reading his feet and head off his origin.
const HALF_HEIGHT := 6.0
## Deep enough to be a chimney rather than a notch: he is 12px tall, so three
## cells is the shallowest hole he could be inside at all.
const MIN_DEPTH := 4


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(10)
	player = world.player
	player.input_locked = false

	var found := _a_chimney()
	if found.is_empty():
		_check(false, "found a one-cell chimney in the world")
		_finish()
		return
	var room: Node2D = found["room"]
	world.current_room = room
	print("  chimney: %s column %d, rows %d..%d  (mouth at world %.0f,%.0f)"
		% [room.name, found["cell"].x, found["cell"].y,
		   int(found["cell"].y) + int(found["depth"]) - 1,
		   found["mouth"].x, found["mouth"].y])
	# Prove the fixture before trusting it. One cell wide and open above, or the
	# drop below is just a drop.
	_check(int(found["width"]) == 1,
		"the shaft is exactly one cell wide  [%d cells]" % int(found["width"]))
	_check(int(found["depth"]) >= MIN_DEPTH,
		"the shaft is at least %d cells deep  [%d]" % [MIN_DEPTH, int(found["depth"])])

	await _check_entry(found)
	await _check_slide(found)
	await _check_climb(found)
	await _check_prop_slots()
	_finish()


# ------------------------------------------------------------------ checks ---

## He goes in from anywhere over the mouth, with nothing held down — walking on
## and running across alike.
func _check_entry(shaft: Dictionary) -> void:
	var mouth: Vector2 = shaft["mouth"]
	var floor_y: float = shaft["floor_y"]
	var caught := 0
	for i in 9:
		# Across the cell, stopping short of its edges: past those his middle is
		# over brick and there is no hole under him to go down.
		var dx := -3.5 + 7.0 * float(i) / 8.0
		if await _stand_on_slot(mouth, dx):
			caught += 1
	_check(caught == 9,
		"standing over the mouth takes him in  [%d of 9 offsets]" % caught)

	# All the way down, on its own budget: the slide caps him at 60px/s, so the
	# descent takes a couple of seconds and the entry sweep above never sees the
	# end of it.
	player.input_locked = false
	player.velocity = Vector2.ZERO
	player.respawn(Vector2(mouth.x, mouth.y - HALF_HEIGHT - 1.0))
	var landed := false
	for f in 240:
		await _frames(1)
		player.input_locked = false
		if player.is_on_floor() and player.global_position.y > mouth.y + CELL * 2.0:
			landed = true
			break
	_check(landed and player.global_position.y > floor_y - CELL * 2.0,
		"...and down to the bottom of it  [y %.0f, shaft floor %.0f]"
			% [player.global_position.y, floor_y])

	# At a run, too. This is the shot that started it: he used to cross the gap
	# without breaking stride, stood on eight pixels of nothing.
	player.input_locked = false
	player.velocity = Vector2.ZERO
	player.respawn(Vector2(mouth.x - CELL * 4.0, mouth.y - HALF_HEIGHT - 1.0))
	await _frames(6)
	Input.action_press("move_right")
	var lowest := player.global_position.y
	for f in 60:
		await _frames(1)
		player.input_locked = false
		lowest = maxf(lowest, player.global_position.y)
	Input.action_release("move_right")
	_check(lowest > mouth.y + CELL * 2.0,
		"and running over it drops him in rather than across  [fell %.0fpx]"
			% (lowest - (mouth.y - HALF_HEIGHT)))


## Stand him on the slot at `dx` from its centre. True if he ended up down it.
func _stand_on_slot(mouth: Vector2, dx: float) -> bool:
	player.input_locked = false
	player.velocity = Vector2.ZERO
	player.respawn(Vector2(mouth.x + dx, mouth.y - HALF_HEIGHT - 1.0))
	for f in 60:
		await _frames(1)
		player.input_locked = false
	return player.global_position.y > mouth.y + CELL * 2.0


## Inside it he WALL-SLIDES, without being asked and without a free-fall first.
##
## He is put in the way the game puts him in — dropped through the mouth — because
## a respawn inside the shaft would come back at full width and wedge him, which
## is the whole thing the squeeze exists to avoid.
func _check_slide(shaft: Dictionary) -> void:
	var mouth: Vector2 = shaft["mouth"]
	player.input_locked = false
	player.velocity = Vector2.ZERO
	player.respawn(Vector2(mouth.x, mouth.y - HALF_HEIGHT - 1.0))
	var slid := 0
	var fastest := 0.0
	var squeezed := false
	for f in 45:
		await _frames(1)
		player.input_locked = false
		squeezed = squeezed or player.squeezing
		if player.state == Player.State.WALL_SLIDE:
			slid += 1
			fastest = maxf(fastest, player.velocity.y)
	_check(squeezed, "he is squeezed while in the shaft")
	_check(slid > 10, "and slides down it with nothing held  [%d frames]" % slid)
	_check(fastest <= player.wall_slide_max_speed + 1.0,
		"that slide is speed-capped  [peak vy %.1f, cap %.0f]"
			% [fastest, player.wall_slide_max_speed])
	# The cap is the point of the assertion above, so prove it is a cap and not
	# a coincidence: free fall through that shaft is far faster than 60px/s.
	_check(fastest > player.wall_slide_max_speed * 0.5,
		"...and he was actually moving  [peak vy %.1f]" % fastest)


## And he must be able to get back OUT the top, which is what makes it a route
## rather than a hole. Alternating wall jumps up a one-cell shaft.
func _check_climb(shaft: Dictionary) -> void:
	var mouth: Vector2 = shaft["mouth"]
	# The bottom of the WALLED section, not the bottom of the column: below the
	# last cell with brick on both sides there is nothing to kick off, and a
	# climb started down there is a jump in open air.
	var bottom: float = mouth.y + float(int(shaft["depth"])) * CELL
	player.input_locked = false
	player.velocity = Vector2.ZERO
	player.respawn(Vector2(mouth.x, mouth.y - HALF_HEIGHT - 1.0))
	for f in 6:
		await _frames(1)
		player.input_locked = false
	# Down to the deep end of the walled section — below that there is nothing to
	# kick off and a climb started there is a jump in open air.
	for f in 60:
		await _frames(1)
		player.input_locked = false
		if player.global_position.y > bottom - HALF_HEIGHT - CELL * 2.0:
			break
	var start := player.global_position.y
	var highest := start
	var dir := 1
	for kick in 10:
		var action := "move_left" if dir < 0 else "move_right"
		Input.action_press(action)
		# Three frames to settle onto the wall, then a HELD jump. Holding is the
		# point: the jump has variable height, and a four-frame tap gains 10px
		# where a held one gains a wall's worth.
		for f in 3:
			await _frames(1)
			player.input_locked = false
			highest = minf(highest, player.global_position.y)
		Input.action_press("jump")
		for f in 12:
			await _frames(1)
			player.input_locked = false
			highest = minf(highest, player.global_position.y)
		Input.action_release("jump")
		Input.action_release(action)
		dir = -dir
	_check(highest <= mouth.y,
		"he can wall-jump back out of the shaft  [climbed %.0fpx of %.0f, to y %.0f]"
			% [start - highest, start - mouth.y, highest])
	# And on the way out he is a full cell again, without anything telling him to
	# be: the wide box is TRIED against the world every frame.
	await _frames(20)
	_check(not player.squeezing,
		"...and he is back to full width once he is out")


# ------------------------------------------------------------------- fixture --

## The deepest one-cell column in the world with solid either side and open sky
## above it. Returns {} if there is none.
func _a_chimney() -> Dictionary:
	var best := {}
	for room: Node2D in world.rooms:
		var layer: TileMapLayer = room.get_node_or_null("Collisions")
		if layer == null:
			continue
		var solid := {}
		for c: Vector2i in layer.get_used_cells():
			solid[c] = true
		var origin: Vector2 = room.position + layer.position
		for c: Vector2i in solid:
			# Walk right off a solid cell into the gap beside it, so every gap is
			# found once from its left wall.
			var gap := c + Vector2i(1, 0)
			if solid.has(gap) or solid.has(gap + Vector2i(0, -1)):
				continue                       # no gap, or roofed over
			var width := 0
			while width < 4 and not solid.has(gap + Vector2i(width, 0)):
				width += 1
			if width != 1 or not solid.has(gap + Vector2i(1, 0)):
				continue                       # not a one-cell slot
			# How far down it stays a one-cell slot with walls on both sides.
			var depth := 0
			while not solid.has(gap + Vector2i(0, depth)) \
					and solid.has(gap + Vector2i(-1, depth)) \
					and solid.has(gap + Vector2i(1, depth)):
				depth += 1
			if depth < MIN_DEPTH or (not best.is_empty() and depth <= int(best["depth"])):
				continue
			# Where the shaft bottoms out: the first solid cell under it, or the
			# point where its walls run out and it opens into the room.
			var out := depth
			while not solid.has(gap + Vector2i(0, out)):
				out += 1
			best = {
				"room": room, "cell": gap, "width": width, "depth": depth,
				"mouth": origin + Vector2(gap) * CELL + Vector2(CELL * 0.5, 0.0),
				"floor_y": origin.y + float(gap.y + out) * CELL,
			}
	return best


## The other kind of one-cell hole: the one between two PROPS.
##
## Everything above sweeps the room's `Collisions` TileMapLayer, and that is
## thinner coverage than it looks. Level_2's drop-throughs are gaps in a run of
## platform props under `Entities` — real StaticBody2Ds the player stands on and
## falls through, owned by no tilemap — so the sweep above walks straight past
## them. They were reported broken from play while this file was passing.
##
## Found from the COLLIDERS, not from a coordinate: two prop boxes with the same
## top edge and a cell of daylight between them that he could actually be
## standing over. That last clause is not tidiness. Six pairs match on geometry
## alone and only two of them are holes — the other four are gaps between CEILING
## panels, with a room's invisible lid (LdtkWorld's `seal_room_ceilings`) or
## another panel row filling the twelve pixels he would have to occupy to stand
## on them. He cannot drop through those at any width, 8px or 9, so a check that
## counted them would be failing on level design rather than on him. Finding none
## at all means the sweep has stopped working rather than that a designer removed
## them, so that is a failure and not a skip.
func _check_prop_slots() -> void:
	var slots := _prop_slots()
	_check(not slots.is_empty(), "found one-cell gaps between props  [%d]" % slots.size())
	if slots.is_empty():
		return
	var worst := 99
	var worst_at := ""
	for slot in slots:
		var caught := 0
		for i in 5:
			var dx := -3.0 + 6.0 * float(i) / 4.0
			if await _drops_through(slot, dx):
				caught += 1
		if caught < worst:
			worst = caught
			worst_at = "%s x%.0f" % [slot["room"], slot["centre"].x]
	_check(worst == 5,
		"he drops through every prop gap from anywhere across it  [worst %d of 5 at %s]"
			% [worst, worst_at])


## Stand him over a prop gap at `dx` from its centre; true if he went through.
##
## Measured on the DEEPEST point he reached, not on where he ends up. These gaps
## drop him out of the bottom of the room, so the kill plane has him a moment
## later — and he is parked on solid ground first so the previous trial's respawn
## cannot land in the middle of this one, which reads as an alternating,
## every-other-offset failure that is entirely the harness.
func _drops_through(slot: Dictionary, dx: float) -> bool:
	var centre: Vector2 = slot["centre"]
	player.input_locked = false
	player.velocity = Vector2.ZERO
	player.respawn(slot["park"])
	await _frames(20)
	player.input_locked = false
	player.velocity = Vector2.ZERO
	player.respawn(Vector2(centre.x + dx, centre.y - HALF_HEIGHT - 1.0))
	var deepest := player.global_position.y
	for f in 40:
		await _frames(1)
		player.input_locked = false
		deepest = maxf(deepest, player.global_position.y)
	return deepest > centre.y + CELL * 2.0


## Every one-cell gap between two prop colliders, world-wide.
func _prop_slots() -> Array:
	var out: Array = []
	for room: Node2D in world.rooms:
		var boxes := _prop_boxes(room)
		boxes.sort_custom(func(a: Rect2, b: Rect2) -> bool:
			return a.position.x < b.position.x)
		for i in range(boxes.size() - 1):
			var a: Rect2 = boxes[i]
			for j in range(i + 1, boxes.size()):
				var b: Rect2 = boxes[j]
				if absf(a.position.y - b.position.y) > 0.5:
					continue
				var gap: float = b.position.x - a.end.x
				if gap >= CELL - 1.0 and gap <= CELL + 1.0 \
						and _is_a_drop(Vector2((a.end.x + b.position.x) * 0.5,
							a.position.y)):
					out.append({
						"room": room.name,
						"centre": Vector2((a.end.x + b.position.x) * 0.5, a.position.y),
						# Somewhere on the prop itself to settle between trials.
						"park": Vector2(a.end.x - CELL, a.position.y - HALF_HEIGHT - 1.0),
					})
				break
	return out


## Is a gap whose top face is at `at` a hole he could fall down?
##
## Two questions, and the first is the one that matters. Somewhere to STAND: his
## squeezed box, feet on the face — that is what rules out the gaps between
## ceiling panels, where the twelve pixels he would occupy are already full of
## room lid. And somewhere to FALL: nothing within two cells under the face.
##
## The standing probe is made with HIS shape rather than with a ray, because the
## question is whether a body fits, and it is made at squeeze_width because that
## is the width he would be at if he were going down. `recovery_as_collision` is
## on for the reason player.gd's `_try_stand_up` documents at length: without it
## a box buried in the brick is quietly pushed out and reported as fitting.
func _is_a_drop(at: Vector2) -> bool:
	var space := player.get_world_2d().direct_space_state
	var below := PhysicsRayQueryParameters2D.create(
		at + Vector2(0.0, 0.5), at + Vector2(0.0, CELL * 2.0), 1)
	below.hit_from_inside = true
	below.exclude = [player.get_rid()]
	if not space.intersect_ray(below).is_empty():
		return false
	var shape: RectangleShape2D = player.get_node("CollisionShape2D").shape
	var was: float = shape.size.x
	shape.size.x = player.squeeze_width
	var stand := Transform2D(0.0, at + Vector2(0.0, -HALF_HEIGHT))
	var blocked: bool = player.test_move(stand, Vector2.ZERO, null, 0.08, true)
	shape.size.x = was
	return not blocked


## World-space rects of a room's prop colliders — the solid boxes that are not
## the tilemap. Rectangles only, which is every platform in the game.
func _prop_boxes(room: Node2D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var stack: Array[Node] = [room]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is CollisionShape2D) or not (n.shape is RectangleShape2D):
			continue
		var body := n.get_parent()
		if not (body is StaticBody2D) or body is TileMapLayer:
			continue
		if (body as StaticBody2D).collision_layer & 1 == 0:
			continue
		var size: Vector2 = (n.shape as RectangleShape2D).size
		out.append(Rect2((n as Node2D).global_position - size * 0.5, size))
	return out


# -------------------------------------------------------------------- rig ---

func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures.append(what)


func _finish() -> void:
	if failures.is_empty():
		print("CHIMNEY TEST: ALL PASS")
	else:
		print("CHIMNEY TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
