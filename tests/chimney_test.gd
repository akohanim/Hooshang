extends Node
## Regression: a ONE-CELL shaft is a chimney, not a wall.
##
## Level_1 has an 8px-wide slot cut down through its ceiling block. His hitbox
## used to be 8px across as well — a full cell — and a body exactly as wide as
## the grid cannot pass through a one-cell slot at all: Godot resolves two
## exactly-abutting AABBs as a collision, so he came to rest ON the lip with the
## whole drawn body hanging over the hole. Measured, the 8px box entered that
## shaft from 0 of 33 approach positions across its mouth.
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

## He must be able to GET IN, from anywhere over the mouth rather than from one
## sub-pixel alignment. Nine drops across the cell; a body one pixel too wide
## scores zero on all of them.
func _check_entry(shaft: Dictionary) -> void:
	var mouth: Vector2 = shaft["mouth"]
	var floor_y: float = shaft["floor_y"]
	var caught := 0
	var tried := 0
	for i in 9:
		var dx := -CELL * 0.5 + CELL * (float(i) + 0.5) / 9.0
		player.input_locked = false
		player.velocity = Vector2.ZERO
		player.respawn(Vector2(mouth.x + dx, mouth.y - 24.0))
		var deepest := player.global_position.y
		for f in 60:
			await _frames(1)
			player.input_locked = false
			deepest = maxf(deepest, player.global_position.y)
		tried += 1
		if deepest > mouth.y + CELL * 2.0:
			caught += 1
	_check(caught == tried,
		"he drops into the shaft from anywhere over its mouth  [%d of %d offsets]"
			% [caught, tried])
	_check(player.global_position.y > floor_y - CELL * 2.0,
		"the last drop reached the bottom  [y %.0f, shaft floor %.0f]"
			% [player.global_position.y, floor_y])


## Inside it, pressing into a wall must be a WALL SLIDE and not a free fall.
func _check_slide(shaft: Dictionary) -> void:
	var mouth: Vector2 = shaft["mouth"]
	for dir: int in [-1, 1]:
		player.input_locked = false
		player.velocity = Vector2.ZERO
		player.respawn(Vector2(mouth.x, mouth.y + CELL * 1.5))
		var action := "move_left" if dir < 0 else "move_right"
		Input.action_press(action)
		var slid := 0
		var fastest := 0.0
		for f in 45:
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
	player.respawn(Vector2(mouth.x, bottom - HALF_HEIGHT - CELL * 2.0))
	await _frames(4)
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
