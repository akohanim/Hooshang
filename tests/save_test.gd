extends Node
## Save slots: the round trip, the three slots not touching each other, and a
## corrupt file reading as an empty slot instead of taking the menu down with it.
##
## The interesting assertions are not "the number came back". They are the pieces
## of progress that live somewhere other than the number, each of which restores
## WRONG by default rather than absent — which is the failure mode a save system
## has that a save system's test usually doesn't:
##
##   - `has_dash`, because Hooshang.tscn ships with the dash ON and only the
##     waking scene takes it away. A load that says nothing about it hands a
##     mid-Act run the ability it may not have earned, and hands the opening room
##     the ability the whole first cutscene is about giving you.
##   - the Darkshang re-route, because losing it silently points the boss room's
##     doorway back at the room he already cleared. Nothing looks broken; a story
##     beat has simply been undone.
##   - `_opening_played`, because replaying the waking scene mid-run is bad and
##     the way it FAILS is worse: the fade lifts inside that scene, so an early
##     return past it leaves the player looking at a black screen.
##   - the taken-fruit set, because a total without it re-spawns every banked
##     pomegranate to be collected again.
##
## Slots are written to a throwaway directory, not user://saves — a suite run
## must never be able to eat a real player's progress.
## Run:  godot --headless res://tests/save_test.tscn

const TEST_DIR := "user://test_saves"
const WORLD := "res://ldtk/Act1World.tscn"

var failures: Array[String] = []
var world: LdtkWorld
## A title screen in the tree, exactly as the real game has one: hidden and
## disabled while a run is up, so it cannot eat a key meant for the world. Stood
## up here rather than loaded as the main scene because MainMenu.open() falls
## back to change_scene_to_file when it finds none — which in a test would
## replace the test.
var menu: MainMenu


func _ready() -> void:
	# The test itself has to outlive the pause it takes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveGame.dir = TEST_DIR
	for i in SaveGame.SLOTS:
		SaveGame.erase(i)

	await _check_empty_to_start()
	await _check_round_trip()
	await _check_slots_are_independent()
	_check_corrupt_reads_as_empty()
	await _check_way_back_survives()
	await _check_practice_writes_nothing()
	await _check_menu_offers()
	await _check_quit_to_title()

	for i in SaveGame.SLOTS:
		SaveGame.erase(i)
	if failures.is_empty():
		print("SAVE TEST: ALL PASS")
	else:
		print("SAVE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Nothing on disk is the state the menu boots into, and it has to be describable
## without reading a file that isn't there.
func _check_empty_to_start() -> void:
	for i in SaveGame.SLOTS:
		_check(not SaveGame.has_save(i), "slot %d starts empty" % (i + 1))
	_check(not SaveGame.has_any(), "and so `has_any` says there is nothing to continue")
	_check(SaveGame.latest_slot() == -1, "and there is no most-recent slot")
	_check(SaveGame.summary(0).get("empty", false),
		"an empty slot summarises as empty rather than as zeroes")
	_check(SaveGame.unlocked_rooms(0).is_empty(),
		"and unlocks no rooms, so level select cannot skip the game")
	_check(not SaveGame.resume(0), "resuming an empty slot is refused")


## Save the whole of a run, throw every piece of it away in memory, load it back,
## and check each piece against the owner that actually holds it.
func _check_round_trip() -> void:
	await _open("Level_7", 0)

	Collectibles.collect("fruit:a")
	Collectibles.collect("fruit:b")
	Deaths.record()
	Deaths.record()
	Deaths.record()
	world.player.has_dash = true
	world.set_way_back(_room("Level_11"), "Level_12")
	_beats()._opening_played = true
	_beats()._collapsed["Level_13"] = true
	await _frames(5)

	_check(SaveGame.save_now(), "the run writes to slot 1")
	_check(SaveGame.has_save(0), "and the slot now holds something")

	var card := SaveGame.summary(0)
	_check(card.get("room", "") == "Level_7",
		"the card names the room he was in  [%s]" % card.get("room", ""))
	_check(int(card.get("room_number", 0)) == 8,
		"numbered the way the pickers number it  [%s]" % card.get("room_number", 0))
	_check(int(card.get("pomegranates", -1)) == 2 and int(card.get("deaths", -1)) == 3,
		"with the two counters on it  [%s / %s]"
			% [card.get("pomegranates"), card.get("deaths")])
	_check(SaveGame.unlocked_rooms(0).has("Level_7"),
		"and Level_7 is unlocked for the level select  %s" % str(SaveGame.unlocked_rooms(0)))

	# Wipe everything the run knew, in memory. Anything that survives this is
	# something the load did not have to do, which is the point of doing it.
	Collectibles.reset()
	Deaths.reset()
	SaveGame.unbind()
	world = null
	_check(Collectibles.total == 0 and Deaths.total == 0, "in-memory state wiped")

	_check(SaveGame.resume(0), "slot 1 loads")
	await _settle()

	_check(Collectibles.total == 2, "pomegranate total restored  [%d]" % Collectibles.total)
	_check(Collectibles.is_taken("fruit:a") and Collectibles.is_taken("fruit:b"),
		"and WHICH fruit were taken, so none of them come back")
	_check(Collectibles.shown() == 2,
		"the counter shows it outright rather than flying a fruit in  [%d]"
			% Collectibles.shown())
	_check(Deaths.total == 3, "death count restored  [%d]" % Deaths.total)
	_check(world.current_room != null and world.current_room.name == "Level_7",
		"opened in the room it was saved in  [%s]"
			% (world.current_room.name if world.current_room else "<none>"))
	_check(world.player.has_dash, "and he still has the dash he was given")
	_check(_beats()._opening_played, "the waking scene is not queued up again")
	_check(_beats()._collapsed.has("Level_13"),
		"and Level_13 is remembered as already fallen  %s" % str(_beats()._collapsed.keys()))
	_check(SaveGame.slot == 0, "the run is bound to slot 1, so it keeps saving")


## The one thing three slots have to do. Written last-to-first so a slot that
## quietly wrote to whatever was bound would show up as the WRONG one winning,
## not merely as one of them being empty.
func _check_slots_are_independent() -> void:
	await _open("Level_2", 1)
	Deaths.record()
	SaveGame.save_now()

	await _open("Level_5", 2)
	Deaths.record()
	Deaths.record()
	Deaths.record()
	Deaths.record()
	Deaths.record()
	SaveGame.save_now()

	var one := SaveGame.summary(0)
	var two := SaveGame.summary(1)
	var three := SaveGame.summary(2)
	_check(one.get("room") == "Level_7" and int(one.get("deaths")) == 3,
		"slot 1 is untouched  [%s / %s]" % [one.get("room"), one.get("deaths")])
	_check(two.get("room") == "Level_2" and int(two.get("deaths")) == 1,
		"slot 2 holds its own run  [%s / %s]" % [two.get("room"), two.get("deaths")])
	_check(three.get("room") == "Level_5" and int(three.get("deaths")) == 5,
		"slot 3 holds a third  [%s / %s]" % [three.get("room"), three.get("deaths")])
	_check(SaveGame.latest_slot() == 2,
		"and CONTINUE picks the one saved most recently  [slot %d]"
			% (SaveGame.latest_slot() + 1))

	# Erasing one leaves the others alone — the overwrite confirmation's job.
	SaveGame.erase(1)
	_check(not SaveGame.has_save(1), "erasing slot 2 empties it")
	_check(SaveGame.has_save(0) and SaveGame.has_save(2), "and leaves 1 and 3 standing")


## Alt-F4 mid-write, and every other way a file arrives damaged. All of them are
## the same answer — an empty slot — because a menu with an error case has an
## error case to get wrong on the way to the title screen.
func _check_corrupt_reads_as_empty() -> void:
	var good := SaveGame.read(0)
	_check(not good.is_empty(), "slot 1 is readable before this")
	var whole := FileAccess.open(SaveGame.slot_path(0), FileAccess.READ).get_as_text()

	for broken in [
		whole.substr(0, whole.length() / 2),   # truncated: the alt-F4 case
		"",                                     # zero bytes
		"{",                                    # started and abandoned
		"not json at all",
		'{"schema": 999, "world": "res://x.tscn"}',   # from a version we don't know
		'["a", "list"]',                        # valid JSON, wrong shape
		'{"schema": 1}',                        # no world to load
	]:
		var f := FileAccess.open(SaveGame.slot_path(0), FileAccess.WRITE)
		f.store_string(broken)
		f.close()
		_check(SaveGame.read(0).is_empty() and not SaveGame.has_save(0),
			"a slot holding %s reads as empty" % _describe(broken))
		_check(SaveGame.summary(0).get("empty", false),
			"  and summarises as an empty slot rather than throwing")
		_check(not SaveGame.resume(0), "  and refuses to be resumed")

	# A missing directory entirely — a first run, or a wiped user://.
	SaveGame.dir = "user://test_saves_missing"
	_check(SaveGame.read(0).is_empty() and SaveGame.latest_slot() == -1,
		"and a save folder that does not exist is just three empty slots")
	SaveGame.dir = TEST_DIR
	SaveGame.erase(0)


## The re-route, end to end, because it is the piece a "which room" save loses
## silently. Not asserted through the dictionary alone — the doorway is walked.
func _check_way_back_survives() -> void:
	await _open("Level_11", 0)
	var trigger := _find_chase(_room("Level_11"))
	_check(trigger != null, "Level_11 has its Darkshang trigger")
	if trigger == null:
		return

	# The crossing, not the reveal: `triggered` fires on the frame the player
	# breaks the line, before two lines of dialogue no headless run can advance.
	# `spent` is set by hand for the same reason — it is the other half of what
	# walking into the box does, and the rest of it is the part that blocks here.
	trigger.spent = true
	trigger.triggered.emit(world.player)
	await _frames(20)
	_check(world._way_back.get("Level_11", "") == "Level_12",
		"meeting him re-points the doorway  %s" % str(world._way_back))
	_check(SaveGame.save_now(), "the run saves with the encounter behind it")

	SaveGame.unbind()
	Collectibles.reset()
	Deaths.reset()
	_check(SaveGame.resume(0), "and loads again")
	await _settle()

	_check(world._way_back.get("Level_11", "") == "Level_12"
			and world._way_back.get("Level_12", "") == "Level_11",
		"both halves of the re-routed door came back  %s" % str(world._way_back))
	_check(_find_chase(_room("Level_11")).spent,
		"and the reveal does not play a second time")

	# Walk it. The dictionary being right and the door being wrong is exactly the
	# bug this whole field exists to prevent, so the assertion is the doorway.
	# Walked in through Level_10's Exit rather than dropped into Level_11,
	# because arriving is what hangs the return door — a room you were simply
	# placed in has no doorway behind you to try.
	await _open_room("Level_10")
	await _walk_forward()
	_check(world.current_room != null and world.current_room.name == "Level_11",
		"walked into Level_11  [%s]"
			% (world.current_room.name if world.current_room else "<none>"))
	await _walk_back()
	_check(world.current_room != null and world.current_room.name == "Level_12",
		"backing out of Level_11 continues the escape  [%s]"
			% (world.current_room.name if world.current_room else "<none>"))


## A level-select run plays the room with the slot's abilities and writes
## nothing. Both halves matter: the first is why it is not just the debug picker,
## the second is why replaying room 3 cannot cost you room 19.
func _check_practice_writes_nothing() -> void:
	var before := SaveGame.summary(0)
	# Whatever the slot's dash state actually is, not "true": that run started at
	# the beginning and the waking scene took the dash away, which is exactly the
	# case a practice run must not quietly hand back.
	var slot_dash := bool(SaveGame.read(0).get("world_state", {}).get("has_dash", true))
	_check(SaveGame.practice(0, "Level_3"), "a practice run starts from slot 1")
	await _settle()
	_check(world.current_room != null and world.current_room.name == "Level_3",
		"in the room that was picked  [%s]"
			% (world.current_room.name if world.current_room else "<none>"))
	_check(world.player.has_dash == slot_dash,
		"with the abilities that run had earned, and no others  [dash %s]" % slot_dash)
	_check(SaveGame.slot == -1, "and no slot bound")

	Deaths.record()
	Deaths.record()
	_check(not SaveGame.save_now(), "so a save is refused outright")
	await _frames(30)
	var after := SaveGame.summary(0)
	_check(after.get("room") == before.get("room")
			and int(after.get("deaths")) == int(before.get("deaths")),
		"and the slot is exactly as it was  [%s / %s]"
			% [after.get("room"), after.get("deaths")])


## The title screen only offers what a player can actually do. A LOAD GAME row
## with nothing behind it, or a level select listing rooms the run has never
## reached, are both ways a menu lies about a save file.
func _check_menu_offers() -> void:
	menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(menu)
	await _frames(2)

	menu.show_root()
	_check(_labels().has("CONTINUE") and _labels().has("LOAD GAME")
			and _labels().has("LEVEL SELECT"),
		"with runs on disk the title screen offers them  %s" % str(_labels()))
	_check(_labels()[0] == "CONTINUE",
		"and CONTINUE is the row you land on  [%s]" % _labels()[0])

	menu._show_levels(0)
	var rooms := _labels()
	_check(rooms.has("ROOM 12") and not rooms.has("ROOM 4"),
		"level select offers the rooms that run stood in and no others  %s" % str(rooms))

	menu._show_confirm(0)
	_check(_labels()[menu.selected] == "KEEP IT",
		"overwriting an occupied slot starts on the harmless answer  [%s]"
			% _labels()[menu.selected])

	# Nothing saved is a different menu, not a menu full of dead rows.
	var kept := {}
	for i in SaveGame.SLOTS:
		kept[i] = SaveGame.read(i)
		SaveGame.erase(i)
	menu.show_root()
	_check(not _labels().has("CONTINUE") and not _labels().has("LOAD GAME")
			and not _labels().has("LEVEL SELECT"),
		"with nothing saved it offers only NEW GAME and QUIT  %s" % str(_labels()))
	for i in SaveGame.SLOTS:
		if not kept[i].is_empty():
			SaveGame._write(i, kept[i])

	# Out of the way for the run below, the way _start() puts it away.
	menu.visible = false
	menu.process_mode = Node.PROCESS_MODE_DISABLED


## The pause menu's QUIT used to end the process because there was nowhere to go.
## Now it banks the run and hands it back to the title screen — and the title
## screen must not itself be pausable, which is the same `Screen.current` gate
## that already refuses a pause with no world.
func _check_quit_to_title() -> void:
	await _open("Level_9", 0)
	Deaths.record()
	await _frames(5)
	_check(Pause.pause_game(), "the run pauses")

	Pause.selected = PauseMenu.Item.QUIT
	Pause._choose()
	await _frames(30)

	_check(Screen.current == null, "quitting to the title takes the world down")
	_check(not get_tree().paused, "and lets go of the pause on the way out")
	_check(not Pause.can_pause(),
		"so the title screen cannot have a pause menu put over it")
	_check(menu.visible and menu.process_mode == Node.PROCESS_MODE_ALWAYS,
		"the title screen is back and taking input again")
	_check(SaveGame.slot == -1, "the run is unbound")

	var card := SaveGame.summary(0)
	_check(card.get("room") == "Level_9" and int(card.get("deaths")) >= 1,
		"and it was written down on the way out  [%s / %s]"
			% [card.get("room"), card.get("deaths")])


func _labels() -> Array[String]:
	var out: Array[String] = []
	for row in menu._rows:
		out.append(str(row["text"]))
	return out


# -------------------------------------------------------------- plumbing ----

## A fresh run in `slot`, opened in `room`. Goes through start_new so the wipe is
## the real one, then puts the world where the check wants it.
func _open(room: String, slot: int) -> void:
	SaveGame.start_new(slot)
	await _settle()
	await _open_room(room)


## Move the loaded world to `room` without walking there. The camera slide is a
## transition and holds input; this only needs the room to be current.
func _open_room(room: String) -> void:
	var target := _room(room)
	if target == null:
		_check(false, "no room named %s" % room)
		return
	world._enter_room(target, true)
	await _frames(5)


## Leave the current room by tripping its Exit — the forward door.
func _walk_forward() -> void:
	var from: Node2D = world.current_room
	var exit := world._exit_in(from)
	if exit == null:
		_check(false, "%s has no Exit to walk out of" % from.name)
		return
	world.player.global_position = exit.global_position + Vector2(0, -8)
	await _until_room_changes(from)


## Walk into the return strip on the edge we came in through.
func _walk_back() -> void:
	var from: Node2D = world.current_room
	world.player.global_position = world._return_zone.global_position
	await _until_room_changes(from)


func _until_room_changes(from: Node2D) -> void:
	for i in 200:
		await _frames(1)
		if not world._transitioning and world.current_room != from:
			break
	await _frames(25)   # let _arm_return finish its two-frame confirmation


## Wait for the world Screen was just handed to finish standing up. Act1Beats
## waits for the rooms itself, so this waits for the beats to have run too.
func _settle() -> void:
	world = Screen.current as LdtkWorld
	for i in 120:
		await get_tree().process_frame
		if world != null and not world.rooms.is_empty():
			break
	await _frames(10)
	if world != null and world.player != null:
		world.player.input_locked = false


func _room(name: String) -> Node2D:
	for r in world.rooms:
		if r.name == name:
			return r
	return null


func _beats() -> Act1Beats:
	for child in world.get_children():
		if child is Act1Beats:
			return child
	return null


func _find_chase(node: Node) -> DarkshangTrigger:
	if node == null or node is DarkshangTrigger:
		return node as DarkshangTrigger
	for child in node.get_children():
		var found := _find_chase(child)
		if found != null:
			return found
	return null


func _describe(text: String) -> String:
	if text == "":
		return "nothing at all"
	return '"%s"' % (text.substr(0, 24) + ("..." if text.length() > 24 else ""))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
