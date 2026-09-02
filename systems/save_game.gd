extends Node
## Three independent runs, written to disk (autoload "SaveGame").
##
## WHAT A SAVE IS HERE. Progress in this game is not "which room". It is spread
## across half a dozen owners that each hold one piece of it, and a slot that
## restored only the room would hand back a world that looks right and is quietly
## wrong: the dash gone (Hooshang.tscn ships with it ON, and only the waking
## scene turns it off, so a mid-game load that says nothing about it gets
## whatever the prefab happened to have), the opening cutscene playing again in
## the middle of the run, rooms collapsing a second time, and — the one that
## costs a story beat rather than a moment — the Darkshang re-route undone, so
## the doorway out of the boss room leads back into the room he already cleared
## instead of onward into the escape.
##
## So every owner keeps its own state and this file only composes them.
## Collectibles and Deaths expose save_state()/load_state(); LdtkWorld and
## Act1Beats expose the same pair and PULL theirs back themselves at load time
## (see state_for). Nothing here reaches into another node's privates, and a new
## piece of progress means teaching its owner two methods rather than teaching
## this file about a part of the game it has no business knowing.
##
## PUSH vs PULL, and why both. The two counters are autoloads that already exist
## when a slot is chosen, so their state is pushed into them before the world
## loads — it has to be, or a lemon's _ready would check an empty "already
## taken" set and re-spawn fruit you had banked. The world's own state cannot be
## pushed: the nodes that own it are created by the load itself, and a parent's
## _ready runs after its children's, so there is no moment afterwards that is
## reliably "everything exists but nothing has decided anything yet". They pull
## instead, each in its own _ready, which has no ordering to get wrong.
##
## WHEN IT WRITES. On every room transition, deferred by a frame so everything
## else listening to room_changed has finished reacting first (the collapse marks
## its room down in that same signal). Rooms are already this game's checkpoint
## granularity — LdtkWorld respawns you at the one you are standing in — so the
## save and the respawn agree by construction, and there is never an "unsaved
## progress" question to put to the player. Quitting to the title from the pause
## menu writes once more on the way out, which is the only other moment progress
## could go missing.
##
## ALT-F4 MID-WRITE. The payload goes to a .tmp beside the slot and is renamed
## over it, so a slot file is either the whole of the last save or the whole of
## the one before it, never half of either. A file that is missing, truncated,
## empty, not JSON, or written by a schema this build doesn't know reads back as
## {} — an empty slot — and no path in here throws.

## Emitted when the active slot changes, so a HUD or a title screen can follow
## it without polling.
signal slot_changed(slot: int)

## How many runs a player can keep. Three is the genre's convention and, more
## usefully, is small enough that the menu never needs to scroll.
const SLOTS := 3

## Payload format version. Bump it when the shape changes. A file claiming a
## schema this build does not know reads as EMPTY rather than as something to
## guess at — a save from a version you have since rolled back from is not worth
## half-restoring into a broken world.
const SCHEMA := 1

## The world a new run starts in. One entry today because Act I is one LDtk
## world; Act II gets a second and the saved `world` field is what picks between
## them on load.
const FIRST_WORLD := "res://ldtk/Act1World.tscn"

## Where slots live. A folder rather than three loose files at the root of
## user://, and a plain var rather than a const so tests can point it somewhere
## disposable — a suite run must never be able to eat a real player's progress.
var dir := "user://saves"

## The slot this run writes to, or -1 for a run that writes nothing at all: the
## debug picker, the level select's practice runs, and every headless test.
## Autosave checks this and nothing else, so "not bound to a slot" is the single
## switch that makes the whole system inert.
var slot := -1

## The last payload loaded or written — what a world pulls its state out of as it
## comes up. Kept in step with the file on every save rather than only being set
## at load, so it is always "the last known good state" and a world reloaded
## mid-run would come back where it actually is rather than where the run began.
var _pending := {}

## Room names this run has stood in, which is what the level select offers. A set
## rather than a "furthest reached" number because the escape row runs backwards
## through the world and a single high-water mark cannot describe it.
var _visited := {}

## Seconds of actual play in this run, for the slot card. Counted here rather
## than by the world, since it has to survive the world being swapped.
var _play_seconds := 0.0


func _ready() -> void:
	Screen.scene_loaded.connect(_on_scene_loaded)


## Time only accrues with a world up. The tree is paused while the pause menu is
## open and this node is not PROCESS_MODE_ALWAYS, so a pause stops the clock for
## free; sitting on the title screen never had a world and so never counted.
func _process(delta: float) -> void:
	if slot >= 0 and Screen.current != null:
		_play_seconds += delta


# ------------------------------------------------------------- reading it ----

func slot_path(i: int) -> String:
	return "%s/slot_%d.json" % [dir, i]


## The payload in slot `i`, or {} for "empty slot".
##
## Every failure funnels into that same {}: no file, no permission, truncated
## JSON, JSON that parses to something other than a dictionary, a schema from the
## future, a payload with no world to load. The menu has exactly one empty case
## to draw and no error case at all, which is the point — a corrupt save is a
## slot you can start a new game in, not a crash on the way to the title screen.
func read(i: int) -> Dictionary:
	if i < 0 or i >= SLOTS:
		return {}
	var f := FileAccess.open(slot_path(i), FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = parsed
	var schema := int(payload.get("schema", 0))
	if schema <= 0 or schema > SCHEMA:
		return {}
	if str(payload.get("world", "")) == "":
		return {}
	return payload


func has_save(i: int) -> bool:
	return not read(i).is_empty()


func has_any() -> bool:
	for i in SLOTS:
		if has_save(i):
			return true
	return false


## The slot a bare "Continue" should pick up: the most recently written one, or
## -1 if none of them hold anything.
func latest_slot() -> int:
	var best := -1
	var best_at := -1
	for i in SLOTS:
		var payload := read(i)
		if payload.is_empty():
			continue
		var at := int(payload.get("saved_at", 0))
		if at >= best_at:
			best_at = at
			best = i
	return best


## Everything the menu draws on a slot card, already unpacked. Returns
## `{"empty": true}` for a slot with nothing in it — the one case the menu has to
## handle differently.
func summary(i: int) -> Dictionary:
	var payload := read(i)
	if payload.is_empty():
		return {"empty": true}
	var world_state: Dictionary = payload.get("world_state", {})
	var collectibles: Dictionary = payload.get("collectibles", {})
	var deaths: Dictionary = payload.get("deaths", {})
	var points: Dictionary = payload.get("points", {})
	var room := str(world_state.get("room", ""))
	return {
		"empty": false,
		"room": room,
		# +1 because Level_0 is the first room; the debug picker counts the same
		# way, so a room named in one menu means the same room in the other.
		"room_number": LdtkWorld.index_in_name(room) + 1,
		"lemons": int(collectibles.get("total", 0)),
		"deaths": int(deaths.get("total", 0)),
		"points": int(points.get("total", 0)),
		"play_seconds": float(payload.get("play_seconds", 0.0)),
		"visited": _names(payload.get("visited", [])),
	}


## The rooms a slot has actually stood in, in play order — what its level select
## is allowed to offer. Empty for an empty slot, which reads as "nothing unlocked
## yet" rather than as a way to skip the game.
func unlocked_rooms(i: int) -> Array[String]:
	var rooms := _names(read(i).get("visited", []))
	rooms.sort_custom(func(a: String, b: String) -> bool:
		return LdtkWorld.index_in_name(a) < LdtkWorld.index_in_name(b))
	return rooms


func world_of(i: int) -> String:
	return str(read(i).get("world", FIRST_WORLD))


# ------------------------------------------------------------- starting it ---

## Begin a fresh run in slot `i`, throwing away whatever was there.
##
## The wipe is deliberate and total: an empty `_pending` is what tells the world
## and the story script that there is nothing to restore, so the waking scene
## plays, the dash is taken away again, and no room remembers having fallen.
func start_new(i: int) -> void:
	_bind(i)
	_pending = {}
	_visited = {}
	_play_seconds = 0.0
	Collectibles.reset()
	Act2Quest.reset()
	Deaths.reset()
	Points.reset()
	Game.current_index = 0
	Game.completed = false
	_enter_world(FIRST_WORLD, "")


## Pick a run back up. Returns false — and changes nothing — if the slot is
## empty or unreadable, so a menu can offer it and be refused rather than having
## to check first and race itself.
func resume(i: int) -> bool:
	var payload := read(i)
	if payload.is_empty():
		return false
	_bind(i)
	_apply(payload)
	var world_state: Dictionary = payload.get("world_state", {})
	_enter_world(str(payload.get("world", FIRST_WORLD)), str(world_state.get("room", "")))
	return true


## Play one room of slot `i` without the run being at stake.
##
## The slot's state is staged exactly as `resume` stages it — the dash, the fruit
## already taken, the re-routed doorway — because a room played with the wrong
## abilities is not the room the player remembers. What it does NOT do is bind
## the slot, so nothing written on this trip goes anywhere: dying, collecting and
## walking on all count for the session and for nothing else.
func practice(i: int, room: String) -> bool:
	var payload := read(i)
	if payload.is_empty():
		return false
	_apply(payload)
	_bind(-1)
	_enter_world(str(payload.get("world", FIRST_WORLD)), room)
	return true


## Open any room as if the whole game had already been played, writing nothing.
##
## The debug picker's problem, and the reason this exists rather than the picker
## just naming a room: a room dropped into cold is not the room a player reaches.
## Level_18 entered raw has no dash (Hooshang.tscn's default is only true by
## accident of the prefab), and — worse — an empty `way_back`, so Level_14's
## doorway still points at Level_13 and the escape route is simply not there.
## Testing the back half of Act I that way tests a world no player will ever see.
##
## What "finished" means here, precisely:
##   - the DASH is his
##   - the Darkshang re-route is in place, both halves, so 12 -> 13 -> 14 works
##   - the shadow has been met, so the reveal does not replay on a backtrack
##   - the opening cutscene does not run, so Level_0 is walkable immediately
##
## `collapsed` is deliberately left EMPTY. A finished save would have every
## escape room already down, but a room that has already collapsed is a room
## whose collapse you cannot watch — and that is the thing this picker is most
## likely being opened to look at.
func open_finished(room: String) -> void:
	_bind(-1)                       # writes nothing, ever
	_visited = {}
	_play_seconds = 0.0
	Collectibles.reset()
	Act2Quest.reset()
	Deaths.reset()
	Points.reset()
	Game.current_index = 0
	Game.completed = false
	_pending = {
		"world_state": {
			"has_dash": true,
			"way_back": {"Level_14": "Level_15", "Level_15": "Level_14"},
		},
		"act1": {
			"opening_played": true,
			"chase_seen": true,
			"collapsed": [],
		},
	}
	_enter_world(FIRST_WORLD, room)


## Forget a run. Deliberately narrow: the only caller is the menu's overwrite
## confirmation, so a slot is never dropped without the player having said so on
## the screen that names what is in it.
func erase(i: int) -> void:
	if i < 0 or i >= SLOTS:
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(i)))
	if slot == i:
		_bind(-1)


## Let go of the slot without touching the disk — leaving a level for the title
## screen, and the reset every test wants so a previous run's staged state cannot
## leak into a world it stands up by hand.
func unbind() -> void:
	_bind(-1)
	_pending = {}
	_visited = {}
	_play_seconds = 0.0


# ------------------------------------------------------------- writing it ----

## Gather the run and put it on disk. Returns whether it wrote.
##
## No-ops without a slot, which is what makes the debug picker, the level select
## and the whole test suite unable to touch a player's saves however far they
## play. Also no-ops with no world up: there would be nothing to ask.
func save_now() -> bool:
	if slot < 0 or Screen.current == null:
		return false
	var payload := _gather()
	if payload.is_empty():
		return false
	if not _write(slot, payload):
		return false
	# The file and the staged copy are the same thing or neither is trustworthy:
	# a world reloaded after this should come back HERE, not where the run began.
	_pending = payload
	return true


## What a world pulls its own slice of the save out of, by owner key —
## "world_state" for LdtkWorld, "act1" for Act1Beats. Empty for a new game, which
## is exactly the "restore nothing" signal, so the owners need no separate "is
## there a save?" question of their own.
##
## The keys are the ones _gather() writes and they do NOT overlap the payload's
## own fields: "world" up there is the scene PATH, which is why the room manager
## pulls "world_state" and not the name you would guess. Asking for the wrong one
## fails silently and safely — a non-dictionary comes back as {} and the owner
## restores nothing — which is exactly how it hid the first time.
func state_for(key: String) -> Dictionary:
	var slice: Variant = _pending.get(key, {})
	return slice if typeof(slice) == TYPE_DICTIONARY else {}


# -------------------------------------------------------------- plumbing ----

func _bind(i: int) -> void:
	if slot == i:
		return
	slot = i
	slot_changed.emit(slot)


## Push the parts that live in autoloads, BEFORE the world is loaded. Order is
## load-bearing: a lemon asks Collectibles whether it has been taken in its
## own _ready, so a fruit banked an hour ago comes back on screen if this runs
## even one frame late.
func _apply(payload: Dictionary) -> void:
	_pending = payload
	_visited = {}
	for name in _names(payload.get("visited", [])):
		_visited[name] = true
	_play_seconds = float(payload.get("play_seconds", 0.0))
	Collectibles.load_state(payload.get("collectibles", {}))
	Act2Quest.load_state(payload.get("act2_quest", {}))
	Deaths.load_state(payload.get("deaths", {}))
	Points.load_state(payload.get("points", {}))
	Game.current_index = int(payload.get("game_index", 0))
	Game.completed = false


## Hand the world over. `room` is fed through LdtkWorld's start-room hook rather
## than through the pulled state, so there is exactly one answer to "which room
## does this world open in" — and the level select, which wants a room the save
## does not name, does not need a second one.
func _enter_world(path: String, room: String) -> void:
	LdtkWorld.debug_start_room = room
	Screen.load_scene(path)


func _gather() -> Dictionary:
	var world := Screen.current
	var payload := {
		"schema": SCHEMA,
		"saved_at": int(Time.get_unix_time_from_system()),
		"play_seconds": _play_seconds,
		"world": Screen.current_path(),
		"game_index": Game.current_index,
		"visited": _visited.keys(),
		"collectibles": Collectibles.save_state(),
		"act2_quest": Act2Quest.save_state(),
		"deaths": Deaths.save_state(),
		"points": Points.save_state(),
	}
	if world is LdtkWorld:
		payload["world_state"] = (world as LdtkWorld).save_state()
	var beats := _beats_in(world)
	if beats != null:
		payload["act1"] = beats.save_state()
	return payload


## The story script belonging to the loaded world, if it has one. Found by class
## rather than by path so a world that simply has no beats (the token density
## prototype, a bare test scene) saves without one and loads without missing it.
func _beats_in(world: Node) -> Act1Beats:
	if world == null:
		return null
	for child in world.get_children():
		if child is Act1Beats:
			return child
	return null


## Write, then move into place. The rename is the whole trick: the slot file is
## replaced in one step, so a power cut during a save costs the newest save and
## not the slot.
func _write(i: int, payload: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)) != OK \
			and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		push_warning("SaveGame: cannot create %s — slot %d not written." % [dir, i])
		return false
	var final := ProjectSettings.globalize_path(slot_path(i))
	var temp := final + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: cannot write %s (error %d)." % [temp, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	if DirAccess.rename_absolute(temp, final) != OK:
		# Platforms whose rename refuses an existing destination. Clearing it
		# first re-opens the window this method exists to close, so it is the
		# fallback and not the path.
		DirAccess.remove_absolute(final)
		if DirAccess.rename_absolute(temp, final) != OK:
			push_warning("SaveGame: could not move %s into place." % temp)
			return false
	return true


## Follow whatever world Screen puts up, and autosave its room changes.
##
## Wired from out here rather than by LdtkWorld calling in, so the room manager
## stays a room manager: it knows nothing about slots, and a world loaded by a
## test or by the picker behaves identically because the slot is -1 and every
## save is a no-op.
func _on_scene_loaded(scene: Node) -> void:
	if scene is LdtkWorld and not (scene as LdtkWorld).room_changed.is_connected(_on_room_changed):
		(scene as LdtkWorld).room_changed.connect(_on_room_changed)


## Deferred, not immediate. room_changed is emitted from inside the camera slide
## and other listeners react to it on the same emit — the collapse marks its room
## as fallen there — so saving on the spot would depend on connection order for
## whether that room comes back already down. A frame later, everyone has
## finished and there is no order to depend on.
func _on_room_changed(room: Node2D) -> void:
	_visited[room.name] = true
	if slot >= 0:
		save_now.call_deferred()


## JSON gives arrays back as untyped Variants; every caller here wants strings.
func _names(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v in raw as Array:
		out.append(str(v))
	return out
