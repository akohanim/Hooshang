extends Node
## One death per respawn, whatever killed him.
##
## Every Hazard actually placed in the LDtk world is walked into, one at a time.
## That breadth is the point, and it is why this test exists in this shape: an
## earlier version stood up a Hazard of its own with Hazard.new(), which did NOT
## reproduce the bug, so a fix that changed nothing in the real game looked
## verified. Hazards as the game builds them — instanced from Hazard.tscn by the
## LDtk import, sitting inside a room — are the only ones worth asserting on.
##
## THE BUG. Death disabled Hooshang's collision and respawn re-enabled it.
## Taking a body out of an Area2D's detection and putting it back makes that area
## fire `body_entered` again at the position it was removed from — so every spike
## killed him a second time ~25 frames after he respawned, 200px away. He is
## alive by then, so die()'s "already DEAD" guard cannot catch it. Toggling
## `collision_layer` instead has the identical fault; the fix is to never remove
## him at all.
##
## The kill plane never doubled, which is why both paths are checked: they have
## to keep agreeing.
## Run:  godot --headless res://tests/death_test.tscn

var failures: Array[String] = []
var world: LdtkWorld
var player: Player


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	Screen.set_scene(world)
	for i in 30:
		if not world.rooms.is_empty():
			break
		await get_tree().process_frame
	await _frames(20)
	player = world.player
	player.input_locked = true  # no stray input walking him back in

	var hazards: Array[Node] = []
	_collect(world, hazards)
	_check(hazards.size() > 0, "the world has hazards to test (%d)" % hazards.size())

	# The sweep runs with the death animation turned down, and that is a
	# deliberate trade. What it is testing is the COUNT, which has to hold at any
	# delay, and the world now holds 68 hazards — at the real 1s hold that is
	# over two minutes of waiting to answer a question about arithmetic. The full
	# 1s hold is exercised once, in the animation section below.
	var full_death_time: float = player.death_time
	player.death_time = 0.05

	var doubled: Array[String] = []
	for h in hazards:
		var hz: Hazard = h
		world._enter_room(_room_holding(hz), true)
		await _frames(10)
		Deaths.reset()
		player.global_position = hz.global_position
		await _wait_out_death()
		if Deaths.total != 1:
			doubled.append("%s in %s counted %d" % [
				hz.global_position, _room_holding(hz).name, Deaths.total])
	_check(doubled.is_empty(),
		"every hazard counts exactly one death  %s" % ("" if doubled.is_empty() else str(doubled)))
	player.death_time = full_death_time

	# --- broken glass kills like everything else ---
	# A stand-in instance, which the note at the top of this file is rightly
	# suspicious of — but no level places one yet, and the alternative is a new
	# prop shipping with nothing asserting it is lethal at all. It is instanced
	# from the same GlassSpikes.tscn the LDtk import uses, and dropped into a real
	# room, so the only thing missing is the import step. That step is checked
	# separately below, against the builder the importer actually calls.
	var room: Node2D = world.rooms[0]
	world._enter_room(room, true)
	await _frames(10)
	for facing in [GlassSpikes.Facing.UP, GlassSpikes.Facing.DOWN,
			GlassSpikes.Facing.RIGHT, GlassSpikes.Facing.LEFT]:
		await _check_glass(room, facing)

	# The LDtk side: the same calls the importer makes for placed entities. A
	# strip dragged out along its surface keeps that length; the other side is
	# forced back to one cell, or the kill box ends up somewhere nobody asked
	# for. Checked per surface, because the two axes swap between them.
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()
	var built: GlassSpikes = importer._build_glass_spikes(
		{"position": Vector2(48.0, 32.0), "size": Vector2i(80, 48)},
		GlassSpikes.Facing.UP)
	_check(built.position == Vector2(48.0, 32.0),
		"the importer places it where LDtk put it")
	_check(built.size == Vector2(80.0, GlassSpikes.CELL),
		"a floor strip keeps its width and is one cell tall  [%s]" % built.size)
	var wall: GlassSpikes = importer._build_glass_spikes(
		{"position": Vector2.ZERO, "size": Vector2i(48, 80)},
		GlassSpikes.Facing.LEFT)
	_check(wall.size == Vector2(GlassSpikes.CELL, 80.0),
		"a wall strip keeps its HEIGHT and is one cell wide  [%s]" % wall.size)
	# In the tree before asking what it drew: the builder only sets properties,
	# and the shards are not built until _ready runs. High above the floor and
	# freed immediately, so it cannot kill anything during the checks below.
	add_child(wall)
	await _frames(2)
	var wall_cells: int = wall.get_node("Shards").get_child_count()
	_check(wall_cells == 5, "and lays its 5 cells out down the wall  [%d]" % wall_cells)
	wall.free()
	built.free()

	# --- dying is an EVENT, not a teleport ---
	# The burst is what makes a death read as one. Checked through the real
	# die() path rather than by calling juice.on_death() directly, because the
	# thing that breaks is the wiring: a burst nobody throws is exactly as
	# invisible in a test that throws it itself as it is in the game.
	world._enter_room(world.rooms[0], true)
	await _frames(10)
	player.respawn(world.rooms[0].global_position + Vector2(72.0, 88.0))
	await _frames(20)
	var before := _shard_count()
	Deaths.reset()
	player.die()
	await _frames(2)
	var during := _shard_count()
	_check(before == 0 and during >= 8,
		"dying throws a burst of shards  [%d before, %d after]" % [before, during])
	# They have to leave. A ring that never expands is a ring sitting on the
	# respawn point, and it would be there for the next death to count twice.
	var spread_start := _shard_spread()
	await _frames(12)
	_check(_shard_spread() > spread_start + 2.0,
		"and they travel outward  [%.1fpx -> %.1fpx]" % [spread_start, _shard_spread()])
	# Nothing outlives the beat: shards are tweened and self-freeing, and a leak
	# here would pile up one ring per death for the whole run.
	await _frames(90)
	_check(_shard_count() == 0, "and clean themselves up  [%d left]" % _shard_count())
	# The hold is the player's, so every level agrees on it.
	_check(player.state == Player.State.DEAD or player.visible,
		"he is either still dead or already back, never a hidden live player")
	await _frames(60)

	# --- the kill plane, which always counted correctly ---
	Deaths.reset()
	player.global_position = Vector2(player.global_position.x, 900.0)
	await _wait_out_death()
	_check(Deaths.total == 1, "falling out of the world counts one death (%d)" % Deaths.total)

	# --- the corpse stays put, which is what makes leaving collision on safe ---
	Deaths.reset()
	var resting := player.global_position
	player.die()
	await _frames(5)
	_check(player.global_position == resting,
		"a dead player does not move, so it cannot enter anything new")
	await _wait_out_death()

	# --- and two real deaths really are two ---
	Deaths.reset()
	player.die()
	await _wait_out_death()
	player.die()
	await _wait_out_death()
	_check(Deaths.total == 2, "two separate deaths count two (%d)" % Deaths.total)

	if failures.is_empty():
		print("DEATH TEST: ALL PASS")
	else:
		print("DEATH TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## One surface's worth of broken glass: does it draw, does it kill, and is the
## lethal part of it where the shards are?
func _check_glass(room: Node2D, facing: GlassSpikes.Facing) -> void:
	var surface: String = ["floor", "ceiling", "left wall", "right wall"][facing]
	var spikes: GlassSpikes = load("res://scenes/props/hazards/GlassSpikes.tscn").instantiate()
	spikes.facing = facing
	var length := GlassSpikes.CELL * 4.0
	spikes.size = Vector2(GlassSpikes.CELL, length) if facing in [
		GlassSpikes.Facing.RIGHT, GlassSpikes.Facing.LEFT] \
		else Vector2(length, GlassSpikes.CELL)
	room.add_child(spikes)
	spikes.global_position = room.global_position + Vector2(200.0, 88.0)
	await _frames(5)

	_check(spikes.is_in_group("hazard"), "%s glass is a hazard like any other" % surface)
	var shards: Node2D = spikes.get_node("Shards")
	_check(shards.get_child_count() == 4,
		"%s: a 4-cell strip draws 4 cells  [got %d]" % [surface, shards.get_child_count()])
	_check(_box_hugs_the_glass(spikes, facing),
		"%s: the kill box is on the shards, not the rubble  %s" % [
			surface, _box_report])

	Deaths.reset()
	player.global_position = spikes.global_position
	await _wait_out_death()
	_check(Deaths.total == 1,
		"%s: walking into it counts one death (%d)" % [surface, Deaths.total])
	spikes.queue_free()
	await _frames(5)


var _box_report := ""

## Does the kill box lie within the glass end of the cell?
##
## Measured along the way the spikes point, so one check covers all four
## surfaces: the box must not stick out past the tips, and must not reach back
## into the rubble bed behind them. Getting this wrong on a ceiling strip means
## dying to the mortar an inch below the actual spikes, which reads as the game
## being broken rather than as the player being careless.
func _box_hugs_the_glass(spikes: GlassSpikes, facing: GlassSpikes.Facing) -> bool:
	var box: CollisionShape2D = null
	for child in spikes.get_children():
		if child is CollisionShape2D:
			box = child
	if box == null:
		_box_report = "[no collision shape]"
		return false
	var dir: Vector2 = [Vector2.UP, Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT][facing]
	var half: Vector2 = box.shape.size * 0.5
	var tips: float = (box.position + half * dir).dot(dir)
	var back: float = (box.position - half * dir).dot(dir)
	var outer := GlassSpikes.CELL * 0.5
	_box_report = "[reaches %.0f of %.0f, backs off at %.0f (bed starts %.0f)]" % [
		tips, outer, back, outer - GlassSpikes.GLASS_HEIGHT]
	return tips <= outer and back >= outer - GlassSpikes.GLASS_HEIGHT


## The death shards currently in the world. Found by their texture rather than
## by a group or a name: they are bare Sprite2Ds spawned into the room, and the
## sheet they point at is the only thing that makes one a shard.
func _shards() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var s := n as Sprite2D
		if s != null and s.texture is AtlasTexture \
				and (s.texture as AtlasTexture).atlas != null \
				and (s.texture as AtlasTexture).atlas.resource_path.ends_with(
					"death_shard.png"):
			out.append(s)
		for c in n.get_children():
			stack.append(c)
	return out


func _shard_count() -> int:
	return _shards().size()


## How far the ring has opened: the mean distance from its own centre.
func _shard_spread() -> float:
	var live := _shards()
	if live.is_empty():
		return 0.0
	var centre := Vector2.ZERO
	for s in live:
		centre += s.global_position
	centre /= float(live.size())
	var total := 0.0
	for s in live:
		total += s.global_position.distance_to(centre)
	return total / float(live.size())


## Wait out one whole death: the animation hold, the respawn, AND the window the
## phantom body_entered used to arrive in (~25 frames after he is back).
##
## Waiting a fixed 120 frames was fine while a respawn took 0.15s and stopped
## being fine the moment it took 1s: a death that landed late in the window left
## him still DEAD when the next hazard's turn began, and die() is a no-op on a
## corpse — so the NEXT hazard counted 0 and the failure pointed at the hazard
## instead of at the clock. Waiting for the state rather than for a frame count
## cannot go wrong again when the timing changes.
func _wait_out_death() -> void:
	for i in 400:
		await get_tree().process_frame
		if Deaths.total >= 1 and player.state != Player.State.DEAD:
			break
	await _frames(60)


func _collect(n: Node, out: Array[Node]) -> void:
	if n is Hazard:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _room_holding(n: Node) -> Node2D:
	var p := n.get_parent()
	while p != null:
		if world.rooms.has(p):
			return p
		p = p.get_parent()
	return world.current_room


func _check(ok: bool, msg: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
