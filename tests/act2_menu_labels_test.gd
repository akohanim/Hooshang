extends Node
var failures: Array[String] = []

func _ready() -> void:
	SaveGame.dir = "user://act2_menu_label_test"
	for i in 3: SaveGame.erase(i)
	SaveGame.unbind()
	SaveGame._write(0, {"schema":SaveGame.SCHEMA, "world":"res://ldtk/Act2World.tscn",
		"saved_at":1, "world_state":{"room":"Prison_B03"},
		"visited":["Act_2_Level_0","Level_2","Prison_Hub","Prison_B03"],
		"collectibles":{"total":16},"deaths":{"total":2},"play_seconds":125})
	var menu := preload("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu.subtitle.text == "ACT II  —  THE POND", "latest Act 2 run gets its own subtitle")
	check(menu.detail.text.begins_with("PUMP ROOM"), "continue describes the saved school room")
	check(SaveGame.room_label("res://ldtk/Act2World.tscn", "Act_2_Level_13") == "ROOM 14", "Act 2 labels omit sort-key scaling")
	check(SaveGame.room_label("res://ldtk/Act2World.tscn", "Level_2") == "ROOM 3", "legacy carpet identifier labels correctly")
	menu._show_levels(0)
	var labels: Array = menu._rows.map(func(row: Dictionary): return row.text)
	check(labels.has("ROOM 1") and labels.has("ROOM 3") and labels.has("ASSEMBLY HALL") and labels.has("PUMP ROOM"), "level select names both linear and branching rooms")
	SaveGame._write(1, {"schema":SaveGame.SCHEMA,"world":SaveGame.FIRST_WORLD,
		"saved_at":2,"world_state":{"room":"Level_5"}})
	menu.show_root()
	check(menu.subtitle.text == "ACT I  —  THE OFFICE", "Act 1 title behavior is unchanged")
	check(menu.detail.text.begins_with("ROOM %d" % (LdtkWorld.index_in_name("Level_5") + 1)), "Act 1 label behavior is unchanged")
	for i in 3: SaveGame.erase(i)
	print("ACT 2 MENU LABELS: ", "ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)
