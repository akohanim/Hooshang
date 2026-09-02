extends Node
## Which of Act 2's four keys are held (autoload "Act2Quest").
##
## Same shape as systems/collectibles.gd, minus the HUD/flight machinery — no
## on-screen counter is being built in this pass, just the tracked state a
## Key prop and JamshidCage both need. Lives here rather than on the player or
## a level for the same reason Collectibles does: the held set has to survive
## room changes, deaths and reloads within Act 2, and an autoload is this
## project's home for cross-level state (STYLE_GUIDE §5).
##
## Deliberately SEPARATE from Collectibles: a lemon is currency (spent on the
## lemon-glow ability, farmable in principle), a key is a fixed quest item —
## the two have no numbers in common and mixing them would make "how many
## lemons do I have" and "how many keys" the same kind of question when they
## are not.

signal changed(held: int)

## How many keys the cage needs. A constant, not a count of placed Key props —
## nothing here scans the world, so a level that (by mistake) placed a fifth
## key would simply never matter: the fourth one collected already opens it.
const TOTAL_KEYS := 4

## key_id -> true, for keys already collected this run.
var _taken := {}


## Idempotent — touching the same key twice (a respawn standing on the exact
## pickup frame, say) counts it once. Returns true only when it changes the
## held count. Mirrors Collectibles.collect()'s is_taken guard.
func collect(id: String) -> bool:
	if id == "" or _taken.has(id):
		return false
	_taken[id] = true
	changed.emit(held_count())
	return true


func is_taken(id: String) -> bool:
	return _taken.has(id)


func held_count() -> int:
	return _taken.size()


func all_keys_collected() -> bool:
	return held_count() >= TOTAL_KEYS


## Wipe the run — a fresh game, not a respawn. SaveGame.start_new() calls this,
## same as Collectibles.reset().
func reset() -> void:
	_taken.clear()
	changed.emit(held_count())


## This much of a save slot (see systems/save_game.gd). The keys held are the
## whole of it — there is no separate "total" the way Collectibles has one,
## since held_count() is just how many ids are in the set.
func save_state() -> Dictionary:
	return {"taken": _taken.keys()}


func load_state(state: Dictionary) -> void:
	_taken.clear()
	var taken: Variant = state.get("taken", [])
	if typeof(taken) == TYPE_ARRAY:
		for id in taken as Array:
			_taken[str(id)] = true
	changed.emit(held_count())
