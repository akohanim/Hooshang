extends RefCounted
## New barriers must not strand saves made before those barriers existed.
## Increase REVISION and tag new puzzle entries when another migration is needed.
const REVISION := 9
const PUZZLES := [
	["completed_circuits", "library_reading", "G", 1, "Green", 1],
	["completed_circuits", "library_stacks", "G", 2, "Green", 1],
	["completed_circuits", "library_archive", "G", 3, "Green", 1],
	["completed_timers", "cafeteria_intro", "R", 1, "Red", 1],
	["completed_timers", "cafeteria_serving", "R", 2, "Red", 1],
	["completed_timers", "cafeteria_pantry_shelf", "R", 3, "Red", 2],
	["completed_timers", "cafeteria_pantry_upper", "R", 3, "Red", 2],
	["completed_circuits", "basement_landing", "B", 1, "Blue", 3],
	["completed_circuits", "basement_stores", "B", 2, "Blue", 4],
	["completed_circuits", "basement_pump_valve", "B", 3, "Blue", 5],
	["completed_circuits", "basement_pump_key", "B", 3, "Blue", 5],
	["completed_timers", "gym_plate_intro", "Y", 1, "Gold", 6],
	["completed_timers", "gym_balcony", "Y", 2, "Gold", 7],
	["completed_timers", "gym_ascent", "Y", 3, "Gold", 8],
	["completed_timers", "gym_reverse", "Y", 3, "Gold", 8],
	["completed_circuits", "gym_music", "Y", 3, "Gold", 9],
]

static func upgrade(raw: Dictionary, saved_room: String) -> Dictionary:
	var result := raw.duplicate(true)
	var revision := int(raw.get("puzzle_revision", 0))
	if revision >= REVISION: return result
	var keys: Variant = raw.get("collected", [])
	if not keys is Array: keys = []
	# Only a matching saved checkpoint proves previous forward progress.
	# Debug/practice room selection must not manufacture completion.
	var checkpoint := str(raw.get("checkpoint_room", ""))
	var valid_checkpoint: bool = raw.get("checkpoint_mode", "") == "room_entry" and checkpoint == saved_room
	for puzzle in PUZZLES:
		if revision >= int(puzzle[5]): continue
		var past_room := false
		if valid_checkpoint:
			for number in range(int(puzzle[3]) + 1, 5):
				if checkpoint == "Prison_%s%02d" % [puzzle[2], number]: past_room = true
		if not (keys.has(puzzle[4]) or past_room): continue
		var completed: Variant = result.get(puzzle[0], [])
		if not completed is Array: completed = []
		if not completed.has(puzzle[1]): completed.append(puzzle[1])
		result[puzzle[0]] = completed
	result["puzzle_revision"] = REVISION
	return result
