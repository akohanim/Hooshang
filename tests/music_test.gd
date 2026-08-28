extends Node
## The musical-tile puzzle (room 6 / Level_8): the glow is earned by stepping all
## five pads, once each, in order — and by nothing else.
##
## Written against two REPORTED bugs, both of which handed out the glow for a run
## that was never played:
##   1. Two pads counting off one landing. The pads sit shoulder to shoulder and
##      their detection skins overlap, so a player straddling a seam was inside
##      both — one touch, two notes, two steps of progress.
##   2. A pad counting twice. Backtracking onto a pad that had already had its
##      turn advanced the run again.
## Both are invisible in normal play until the glow turns up early, which is why
## they are pinned here.
##
## Drives the pads by PARKING the player on them rather than platforming to them:
## the bug is about which contacts count, and hand-flown jumps would make the
## test about jump arcs instead. Parking also holds him off the kill plane —
## dying revokes the glow and resets the run, which would hide every failure.
## Run:  godot --headless res://tests/music_test.tscn

## Room 6 in play order; "Level_8" is its LDtk identifier.
const ROOM := "Level_8"
## Where the player is parked between steps: clear of every pad's skin, so each
## pad gets a clean arrival rather than one long overlap.
const NEUTRAL := Vector2(1848, 300)
## Long enough to clear both repeat guards — NoteTile.retrigger_grace (0.25s) and
## NoteSequence.repeat_grace (0.6s) — so a step that SHOULD count is never
## swallowed by one of them and mistaken for the fix working.
const BETWEEN_STEPS := 0.75
## Long enough for the arrival to register and be seen.
const ON_PAD := 0.2

var failures: Array[String] = []
var world: LdtkWorld
var room: Node2D
var seq: NoteSequence
var player: Player
## note_index -> the pad carrying it, for this room.
var pads := {}
## Note indices that sounded, in order, since the last _watch_steps() reset.
var steps: Array[int] = []


func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(30)
	player = world.player
	room = _room_named(ROOM)
	_check(room != null, "the world has room 6 (Level_8)")
	if room == null:
		return _finish()
	world._enter_room(room, true)
	await _frames(10)

	seq = _find_sequence()
	_check(seq != null, "the world has a NoteSequence")
	if seq == null:
		return _finish()
	for tile in get_tree().get_nodes_in_group("note_tile"):
		if room.is_ancestor_of(tile):
			pads[(tile as NoteTile).note_index] = tile
			(tile as NoteTile).stepped.connect(func(t: NoteTile) -> void:
				steps.append(t.note_index))
	_check(pads.size() == 5, "room 6 has five pads  [got %d]" % pads.size())
	if pads.size() != 5:
		return _finish()

	# --- 1. one landing, one note ---
	# The reported case: standing where two pads meet. He is genuinely touching
	# both, so the question is not whether contact happened but which pad he is
	# ON, and the answer has to be exactly one of them.
	await _clear()
	steps.clear()
	await _park(_seam(2, 3), ON_PAD)
	_check(steps.size() == 1,
		"straddling the 2|3 seam sounds ONE pad, not two  [got %s]" % str(steps))
	_check(seq.progress <= 1,
		"and it cannot advance the run twice  [progress %d]" % seq.progress)

	await _clear()
	steps.clear()
	await _park(_seam(4, 5), ON_PAD)
	_check(steps.size() == 1,
		"same at the 4|5 seam  [got %s]" % str(steps))

	# --- 2. the exploit, end to end ---
	# One pad, then two seams: five notes out of three landings.
	#
	# This one only ever fired SOMETIMES, which is exactly how it was reported.
	# Two overlapping skins report in whatever order the physics server hands
	# them over, so a seam landing counted (2,3) — two free steps — or (3,2),
	# which broke the run instead. The seam checks above are the ones with teeth;
	# this is here because it is the shape the player actually sees.
	await _restart()
	await _step_pad(1)
	await _park(_seam(2, 3), ON_PAD)
	await _clear()
	await _park(_seam(4, 5), ON_PAD)
	_check(not player.has_glow,
		"three landings cannot buy five notes  [progress %d]" % seq.progress)

	# --- 3. a pad cannot count twice ---
	await _restart()
	await _step_pad(1)
	await _step_pad(2)
	await _step_pad(3)
	await _step_pad(3)   # backtrack onto one that already counted
	await _step_pad(4)
	await _step_pad(5)
	_check(not player.has_glow,
		"stepping a pad twice breaks the run  [progress %d]" % seq.progress)

	# --- 4. out of order ---
	await _restart()
	await _step_pad(1)
	await _step_pad(2)
	await _step_pad(4)
	await _step_pad(5)
	await _step_pad(3)
	_check(not player.has_glow,
		"and so does the wrong pad  [progress %d]" % seq.progress)

	# --- 5. the real thing still works ---
	# The point of the strictness is that the sequence stays PLAYABLE. If the
	# rules above also broke the honest run, every check so far would pass for
	# the worst possible reason.
	await _restart()
	steps.clear()
	for i in 5:
		await _step_pad(i + 1)
	_check(steps == [1, 2, 3, 4, 5],
		"all five sound, in order, one each  [got %s]" % str(steps))
	_check(seq.progress == 5, "the run completes  [progress %d]" % seq.progress)
	_check(player.has_glow, "and the glow is granted")

	_finish()


# ------------------------------------------------------------------ driving ----

## Park the player on a pad long enough to arrive on it, then step clear again.
func _step_pad(index: int) -> void:
	var pad: NoteTile = pads[index]
	await _park(_landing(pad.global_position), ON_PAD)
	await _clear()


## Stand him clear of every pad, so the next arrival is a real arrival.
func _clear() -> void:
	await _park(NEUTRAL, BETWEEN_STEPS)


## Wipe the puzzle AND the glow, so each case starts from the same place.
func _restart() -> void:
	seq.reset()
	player.revoke_glow()
	await _clear()


## Hold the player at `where` for `seconds`, re-placing him every frame.
##
## Every frame, not once: he is a CharacterBody2D under gravity, and a single
## teleport turns into a fall — into the kill plane, which revokes the glow and
## resets the run, i.e. into every assertion here passing for the wrong reason.
func _park(where: Vector2, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		player.global_position = where
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame


## Standing on top of a pad: his feet on its upper face, inside the skin.
func _landing(pad_centre: Vector2) -> Vector2:
	return pad_centre + Vector2(0.0, -14.0)


## The point where two pads meet, which is where he touches both at once.
func _seam(a: int, b: int) -> Vector2:
	var pa: NoteTile = pads[a]
	var pb: NoteTile = pads[b]
	return _landing((pa.global_position + pb.global_position) * 0.5)


# ----------------------------------------------------------------- plumbing ----

func _find_sequence() -> NoteSequence:
	for child in world.get_children():
		if child is NoteSequence:
			return child
	return null


func _room_named(name: String) -> Node2D:
	for r in world.rooms:
		if r.name == name:
			return r
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures.append(what)


func _finish() -> void:
	if failures.is_empty():
		print("MUSIC TEST: ALL PASS")
	else:
		print("MUSIC TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
