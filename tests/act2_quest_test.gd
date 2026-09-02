extends Node
## Act2Quest: which of the 4 keys are held, the JamshidCage that opens once
## all 4 are, and the Key pickup that reports to Act2Quest. Also covers the
## SaveGame integration Act2Quest was wired into, same shape as
## tests/save_test.tscn's Collectibles coverage.
##
## Run:  godot --headless res://tests/act2_quest_test.tscn

const KEY_SCENE := preload("res://scenes/props/Key.tscn")
const CAGE_SCENE := preload("res://scenes/props/JamshidCage.tscn")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")
const TEST_DIR := "user://test_saves_act2_quest"

var failures: Array[String] = []
var world: Node2D
var player: Player


func _ready() -> void:
	world = Node2D.new()
	# SaveGame.read() treats an empty "world" field as an empty slot (same
	# rule that lets a corrupt/incomplete save fail safe) — Screen.current_path()
	# reads scene_file_path, which a hand-built Node2D never has, so this
	# fakes one purely so the SLOT ROUND-TRIP section below has something
	# non-empty to write and read back. Nothing tries to actually load it.
	world.scene_file_path = "res://ldtk/Act2World.tscn"
	# Screen.set_scene, not add_child: SaveGame.save_now() requires
	# Screen.current to be set (it gathers the payload from it).
	Screen.set_scene(world)
	player = PLAYER.instantiate()
	world.add_child(player)
	await _run()


func _run() -> void:
	Act2Quest.reset()

	# --- collecting keys, idempotently -------------------------------------
	_check(Act2Quest.held_count() == 0, "starts with none held")
	_check(not Act2Quest.all_keys_collected(), "...so the cage should not open yet")
	_check(Act2Quest.collect("1"), "collecting a fresh key id returns true")
	_check(Act2Quest.is_taken("1"), "...and is_taken reports it")
	_check(Act2Quest.held_count() == 1, "...and the held count goes up  [1]")
	_check(not Act2Quest.collect("1"),
		"collecting the SAME id again returns false")
	_check(Act2Quest.held_count() == 1,
		"...and does not double-count  [still 1]")

	# --- the cage: derived state, no flag of its own ------------------------
	var cage: JamshidCage = CAGE_SCENE.instantiate()
	cage.position = Vector2(500, 500)
	world.add_child(cage)
	await _frames(2)
	_check(not cage._shape.disabled, "the cage is solid with only 1 of 4 keys held")

	for id in ["2", "3"]:
		Act2Quest.collect(id)
	await _frames(2)
	_check(Act2Quest.held_count() == 3, "3 of 4 held")
	_check(not cage._shape.disabled, "...still locked at 3 of 4")

	Act2Quest.collect("4")
	await _frames(2)
	_check(Act2Quest.all_keys_collected(), "all 4 keys collected")
	_check(cage._shape.disabled, "...and the cage unlocks  [collision off]")

	# A cage placed AFTER all 4 are already held opens immediately on _ready —
	# the whole point of deriving state instead of tracking an "opened" flag.
	var late_cage: JamshidCage = CAGE_SCENE.instantiate()
	late_cage.position = Vector2(600, 500)
	world.add_child(late_cage)
	await _frames(2)
	_check(late_cage._shape.disabled,
		"a cage placed after all 4 keys are already held starts open")

	# --- the Key prop: carry-and-deliver, not touch-to-collect ---------------
	# Touching the key only picks it up — it does not bank until it is carried
	# within deliver_radius of a JamshidCage. See key.gd's class doc.
	Act2Quest.reset()
	player.global_position = Vector2(-1000, -1000)  # clear of anything below
	var key: Key = KEY_SCENE.instantiate()
	key.key_id = "1"
	key.position = Vector2(100, 100)
	world.add_child(key)
	await _frames(2)
	player.global_position = key.position
	await _frames(4)
	_check(not Act2Quest.is_taken("1"),
		"touching the Key prop does NOT bank it to Act2Quest yet")
	_check(is_instance_valid(key) and not key.is_queued_for_deletion(),
		"...the key prop still exists")
	_check(key._carrying, "...and is now following the player")

	# Walk the player far away from any cage: still not delivered while out of
	# range.
	player.global_position = Vector2(100, 900)
	await _frames(6)
	_check(not Act2Quest.is_taken("1"),
		"carrying it away from any cage still does not bank it")

	# --- a death while carrying an undelivered key restores it ---------------
	var origin: Vector2 = key.position
	player.died.emit()
	await _frames(2)
	_check(not key._carrying, "dying while carrying clears the carry state")
	_check(is_equal_approx(key._sprite.scale.x, 1.0),
		"...the key un-shrinks  [scale %.2f]" % key._sprite.scale.x)
	_check(key.position == origin,
		"...and the prop itself never moved (only the sprite followed)  [%s]" % key.position)
	_check(not Act2Quest.is_taken("1"),
		"...and nothing was banked — collect() never fired")

	# --- walking it up to a JamshidCage delivers it ---------------------------
	var deliver_cage: JamshidCage = CAGE_SCENE.instantiate()
	deliver_cage.position = Vector2(700, 700)
	world.add_child(deliver_cage)
	await _frames(2)
	player.global_position = key.position  # re-pick it up
	await _frames(4)
	_check(key._carrying, "picking it back up re-arms the carry")
	player.global_position = deliver_cage.position + Vector2(30, 0)  # within 50px
	await _frames(4)
	_check(Act2Quest.is_taken("1"),
		"carrying it within deliver_radius of a JamshidCage banks it for real")
	# Past key.gd's own pop_time (0.12s = ~7 frames) so the flourish tween has
	# actually finished before checking the prop is gone.
	await _frames(12)
	_check(not is_instance_valid(key) or key.is_queued_for_deletion(),
		"...and the prop frees itself")

	# An instance for an already-taken id frees itself on _ready without
	# double-counting — same "already banked, don't re-spawn" rule Lemon
	# follows for Collectibles.
	var stale: Key = KEY_SCENE.instantiate()
	stale.key_id = "1"
	stale.position = Vector2(150, 100)
	world.add_child(stale)
	await _frames(2)
	_check(not is_instance_valid(stale) or stale.is_queued_for_deletion(),
		"a Key for an already-taken id removes itself on _ready")

	# --- the LDtk side --------------------------------------------------
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()
	var built: Area2D = importer._build_key({
		"position": Vector2(20.0, 30.0), "fields": {"KeyID": "3"},
	})
	_check(built.position == Vector2(20.0, 30.0) and built.key_id == "3",
		"the importer places it and reads KeyID  [%s %s]" % [built.position, built.key_id])
	built.free()
	var built_cage: StaticBody2D = importer._build_jamshid_cage(
		{"position": Vector2(40.0, 50.0)})
	_check(built_cage is JamshidCage and built_cage.position == Vector2(40.0, 50.0),
		"the importer places a JamshidCage  [%s]" % built_cage.position)
	built_cage.free()

	# --- save_state()/load_state() round trip, direct ------------------------
	Act2Quest.reset()
	Act2Quest.collect("1")
	Act2Quest.collect("3")
	var saved := Act2Quest.save_state()
	Act2Quest.reset()
	_check(Act2Quest.held_count() == 0, "reset wipes the held set")
	Act2Quest.load_state(saved)
	_check(Act2Quest.is_taken("1") and Act2Quest.is_taken("3") and Act2Quest.held_count() == 2,
		"load_state restores exactly the keys that were saved  [%d]" % Act2Quest.held_count())
	_check(not Act2Quest.is_taken("2"), "...and no others  [key 2 was never held]")

	# --- the SaveGame integration: a real slot round trip --------------------
	SaveGame.dir = TEST_DIR
	SaveGame.erase(0)
	Act2Quest.reset()
	Act2Quest.collect("1")
	Act2Quest.collect("2")
	SaveGame.slot = 0
	var wrote := SaveGame.save_now()
	_check(wrote, "SaveGame writes with Act2Quest holding 2 keys")
	Act2Quest.reset()
	_check(Act2Quest.held_count() == 0, "cleared in memory before loading back")
	# read() + _apply() directly, not resume(): resume() also calls
	# _enter_world(), which loads Screen.current_path() as a real scene — and
	# this test's "world" is a bare Node2D stood up by hand (never loaded from
	# a .tscn), so it has no real scene_file_path to reload. The world-loading
	# half is orthogonal to what this test is checking: that Act2Quest's held
	# keys round-trip through save_game.gd's own composition.
	var payload := SaveGame.read(0)
	_check(not payload.is_empty(), "the slot reads back")
	SaveGame._apply(payload)
	_check(Act2Quest.held_count() == 2 and Act2Quest.is_taken("1") and Act2Quest.is_taken("2"),
		"...and Act2Quest's held keys came back with it  [%d]" % Act2Quest.held_count())
	SaveGame.erase(0)
	SaveGame.unbind()

	# start_new() wipes it, same as Collectibles/Deaths — a fresh game must not
	# start with a stale run's keys already held.
	Act2Quest.collect("1")
	SaveGame.start_new(0)
	_check(Act2Quest.held_count() == 0, "start_new() resets the held keys")
	SaveGame.erase(0)
	SaveGame.unbind()
	Act2Quest.reset()

	if failures.is_empty():
		print("ACT2 QUEST TEST: ALL PASS")
	else:
		print("ACT2 QUEST TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
