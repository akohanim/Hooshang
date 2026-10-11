extends Node
## Save compatibility fixtures, not earned traversal evidence.
const Migration := preload("res://scripts/prison/prison_save_migration.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func _ready() -> void:
	var fresh := Migration.upgrade({}, "Prison_R03")
	check(fresh.get("completed_timers", []).is_empty(), "debug start does not grant completion")
	var old := {"checkpoint_mode":"room_entry", "checkpoint_room":"Prison_R02", "collected":[], "inserted":[]}
	var upgraded := Migration.upgrade(old, "Prison_R02")
	check(upgraded.get("completed_timers", []) == ["cafeteria_intro"], "legacy R02 opens only previous room")
	check(not old.has("completed_timers"), "migration does not mutate staged save")
	check(Migration.upgrade(old, "Prison_Hub").get("completed_timers", []).is_empty(), "mismatched checkpoint grants nothing")
	old.checkpoint_room = "Prison_G03"
	upgraded = Migration.upgrade(old, "Prison_G03")
	check(upgraded.get("completed_circuits", []) == ["library_reading", "library_stacks"], "legacy archive retains its current challenge")
	old.collected = ["Green"]
	old.inserted = ["Green"]
	upgraded = Migration.upgrade(old, "Prison_Hub")
	check(upgraded.completed_circuits.size() == 3, "legacy key proves whole wing completion")
	check(upgraded.collected == ["Green"] and upgraded.inserted == ["Green"], "keys and cage locks unchanged")
	check(upgraded.get("completed_timers", []).is_empty(), "one wing does not solve another")
	check(Migration.upgrade(upgraded, "Prison_G03") == upgraded, "migration is idempotent")
	var earlier_revision := Migration.upgrade({"puzzle_revision":1, "collected":["Red"]}, "Prison_Hub")
	check(earlier_revision.get("completed_timers", []) == ["cafeteria_pantry_shelf", "cafeteria_pantry_upper"], "later revision migrates only newly introduced gates")
	var flood_revision := Migration.upgrade({"puzzle_revision":2, "collected":["Blue"]}, "Prison_Hub")
	check(flood_revision.get("completed_circuits",[]) == ["basement_landing", "basement_stores", "basement_pump_valve", "basement_pump_key"], "legacy Blue key preserves new sluice access")
	var gold_revision := Migration.upgrade({"puzzle_revision":5, "collected":["Gold"]}, "Prison_Hub")
	check(gold_revision.get("completed_timers",[]) == ["gym_plate_intro", "gym_balcony", "gym_ascent", "gym_reverse"], "legacy Gold key preserves new plate passage")
	check(gold_revision.get("completed_circuits",[]) == ["gym_music"], "legacy Gold keeps new musical key roof open")
	old.puzzle_revision = Migration.REVISION
	check(Migration.upgrade(old, "Prison_G03") == old, "current saves never infer success from location or keys")
	old.erase("puzzle_revision")
	old.collected = "invalid"
	old.completed_circuits = "invalid"
	check(Migration.upgrade(old, "Prison_G03").completed_circuits.size() == 2, "malformed legacy ledger does not break migration")
	SaveGame.dir = "user://prison_migration_acceptance_saves"
	SaveGame.unbind()
	SaveGame.erase(0)
	SaveGame._bind(0)
	LdtkWorld.debug_start_room = "Prison_R03"
	Screen.load_scene("res://ldtk/Act2World.tscn")
	await frames(20)
	var payload := SaveGame._gather()
	var prison: Dictionary = payload.world_state.prison
	prison.erase("puzzle_revision")
	prison.erase("completed_timers")
	prison.erase("completed_circuits")
	prison.collected = ["Green"]
	prison.inserted = ["Green"]
	check(SaveGame._write(0, payload), "legacy fixture written to dedicated disk slot")
	SaveGame.unbind()
	check(SaveGame.resume(0), "legacy slot resumes")
	await frames(30)
	var world = Screen.current
	check(str(world.current_room.name) == "Prison_R03", "legacy room preserved")
	check(world.collected == ["Green"] and world.inserted == ["Green"], "runtime retains key and lock progress")
	check(world.timers.solved("cafeteria_intro") and world.timers.solved("cafeteria_serving"), "previous cafeteria passages migrated")
	for prop in world.props:
		if prop.kind in ["TimedGate", "TimedShutter", "CircuitGate", "FloodGate", "MusicalGate"]:
			var previous_room: bool = prop.circuit_id.begins_with("library_") if prop.kind in ["CircuitGate", "FloodGate", "MusicalGate"] else prop.puzzle_id in ["cafeteria_intro", "cafeteria_serving"]
			check(prop.barrier.disabled == previous_room, "legacy previous gates open, current-room challenge stays closed: " + str(prop.name))
	world.player.die()
	await frames(90)
	check(world.timers.solved("cafeteria_serving"), "migration survives death")
	check(SaveGame.save_now(), "upgraded state saved")
	check(SaveGame.read(0).world_state.prison.puzzle_revision == Migration.REVISION, "disk saves record migration revision")
	SaveGame.unbind()
	check(SaveGame.resume(0), "upgraded state resumes again")
	await frames(30)
	world = Screen.current
	check(world.timers.solved("cafeteria_serving") and world.circuits.solved("library_archive"), "completion survives second disk resume")
	# A modern interrupted attempt at the same checkpoint must remain unsolved.
	payload = SaveGame._gather()
	payload.world_state.prison.completed_timers = []
	payload.world_state.prison.completed_circuits = []
	check(SaveGame._write(0, payload), "current interrupted fixture written")
	SaveGame.unbind()
	check(SaveGame.resume(0), "current interrupted fixture resumes")
	await frames(30)
	world = Screen.current
	check(not world.timers.solved("cafeteria_serving") and not world.circuits.solved("library_archive"), "modern incomplete puzzles are not auto-completed")
	SaveGame.unbind()
	SaveGame.erase(0)
	print("PRISON SAVE MIGRATION: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
