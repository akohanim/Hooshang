extends Node
## Regression: a ONE-CELL shaft is a chimney you choose to enter.
##
## Level_1 has an 8px-wide slot cut down through its ceiling block. His hitbox is
## 8px across too — a full cell — and a body exactly as wide as the grid cannot
## pass through a one-cell slot at all: Godot resolves two exactly-abutting AABBs
## as a collision, so he came to rest ON the lip with the whole drawn body
## hanging over the hole. Measured, the 8px box entered that shaft from 0 of 33
## approach positions across its mouth, and 7.99 was no better.
##
## The answer is not a narrower man. A gap in a floor should be something you
## stride over, and a permanently thinner Hooshang drops through one while
## WALKING. So he squeezes on purpose: hold DOWN over a slot and his box narrows
## to squeeze_width, he is placed down the middle of the hole and goes in.
## Everything below is that bargain — he must go down it when asked, and he must
## NOT go down it when simply walking across.
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
	_finish()


# ------------------------------------------------------------------ checks ---

## He must be able to GET IN when he asks — from anywhere over the mouth, not
## from one sub-pixel alignment — and he must NOT get in when he does not ask.
func _check_entry(shaft: Dictionary) -> void:
	var mouth: Vector2 = shaft["mouth"]
	var floor_y: float = shaft["floor_y"]
	var caught := 0
	var tried := 0
	for i in 9:
		# Across the cell, stopping short of its edges: past those his middle is
		# over brick and there is no hole under him to go down.
		var dx := -3.5 + 7.0 * float(i) / 8.0
		if await _drop_in(mouth, dx, true):
			caught += 1
		tried += 1
	_check(caught == tried,
		"holding DOWN over the mouth takes him in  [%d of %d offsets]"
			% [caught, tried])
	_check(player.global_position.y > floor_y - CELL * 2.0,
		"...and down to the bottom  [y %.0f, shaft floor %.0f]"
			% [player.global_position.y, floor_y])

	# The other half of the bargain, and the reason his box is still a full cell
	# wide: standing on the slot without asking must leave him standing on it.
	var stayed := 0
	for i in 9:
		var dx := -3.5 + 7.0 * float(i) / 8.0
		if not await _drop_in(mouth, dx, false):
			stayed += 1
	_check(stayed == 9,
		"without DOWN he stands on the slot instead  [%d of 9 offsets]" % stayed)

	# And walking across it at speed is a walk across it, not a fall down it.
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
	_check(lowest < mouth.y + CELL,
		"and running over the slot crosses it  [dropped %.0fpx]"
			% (lowest - (mouth.y - HALF_HEIGHT)))


## Stand him on the slot at `dx` from its centre, optionally holding DOWN.
## Returns true if he ended up down the shaft.
func _drop_in(mouth: Vector2, dx: float, press_down: bool) -> bool:
	player.input_locked = false
	player.velocity = Vector2.ZERO
	player.respawn(Vector2(mouth.x + dx, mouth.y - HALF_HEIGHT - 1.0))
	# Let him settle onto the lip before asking for anything.
	for f in 6:
		await _frames(1)
		player.input_locked = false
	if press_down:
		Input.action_press("move_down")
	for f in 60:
		await _frames(1)
		player.input_locked = false
	if press_down:
		Input.action_release("move_down")
	return player.global_position.y > mouth.y + CELL * 2.0


## Inside it, pressing into a wall must be a WALL SLIDE and not a free fall.
##
## He is put in the way the game puts him in — down through the mouth holding
## DOWN — because a respawn inside the shaft would come back at full width and
## wedge him, which is exactly the thing the squeeze exists to avoid.
func _check_slide(shaft: Dictionary) -> void:
	var mouth: Vector2 = shaft["mouth"]
	for dir: int in [-1, 1]:
		player.input_locked = false
		player.velocity = Vector2.ZERO
		player.respawn(Vector2(mouth.x, mouth.y - HALF_HEIGHT - 1.0))
		for f in 6:
			await _frames(1)
			player.input_locked = false
		Input.action_press("move_down")
		for f in 6:
			await _frames(1)
			player.input_locked = false
		Input.action_release("move_down")
		_check(player.squeezing, "he is squeezed while in the shaft")
		var action := "move_left" if dir < 0 else "move_right"
		Input.action_press(action)
		var slid := 0
		var fastest := 0.0
		for f in 40:
			await _frames(1)
			player.input_locked = false
			if player.state == Player.State.WALL_SLIDE:
				slid += 1
				fastest = maxf(fastest, player.velocity.y)
		Input.action_release(action)
		_check(slid > 10,
			"pressing %s inside the shaft wall-slides  [%d frames]" % [action, slid])
		_check(fastest <= player.wall_slide_max_speed + 1.0,
			"that slide is speed-capped  [peak vy %.1f, cap %.0f]"
				% [fastest, player.wall_slide_max_speed])


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
	Input.action_press("move_down")
	# In, and down to the deep end of the walled section — below that there is
	# nothing to kick off and a climb started there is a jump in open air.
	for f in 40:
		await _frames(1)
		player.input_locked = false
		if player.global_position.y > bottom - HALF_HEIGHT - CELL * 2.0:
			break
	Input.action_release("move_down")
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
