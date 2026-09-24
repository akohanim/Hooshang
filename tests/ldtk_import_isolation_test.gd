@tool
extends SceneTree
## Run with --headless --editor --path . --script res://tests/ldtk_import_isolation_test.gd
## Import two minimal projects sharing Level_2, in BOTH orders, then reload
## each world from disk. No changes to the user's LDtk projects or settings.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var importer = load("res://addons/ldtk-importer/ldtk-importer.gd").new()
	var options := {}
	for option: Dictionary in importer._get_import_options("", 0):
		options[option.name] = option.default_value
	options.pack_levels = true
	var template: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ldtk/hooshang_act1.ldtk"))
	var fixture: Dictionary = template.levels[0].duplicate(true)
	fixture.identifier = "Level_2"
	fixture.layerInstances = []
	fixture.fieldInstances = []
	fixture.__neighbours = []
	fixture.bgRelPath = null
	template.worldLayout = "Free"
	template.externalLevels = false
	for key in template.defs:
		if template.defs[key] is Array:
			template.defs[key] = []
	var folder := "user://import_isolation_%s/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	# Root properties can be overridden by the world scene even while its
	# inherited children come from the wrong packed room. Give each room a
	# unique child, exactly like the PlayerStart that disappeared in Act 1.
	var hook := FileAccess.open(folder + "origin.gd", FileAccess.WRITE)
	hook.store_string("@tool\nextends RefCounted\nfunc post_import(level):\n\tvar marker = Marker2D.new()\n\tmarker.name = \"Origin_\" + level.iid\n\tlevel.add_child(marker)\n\treturn level\n")
	hook.close()
	options.level_post_import = folder + "origin.gd"
	for name in ["act_one", "act_two"]:
		var source := template.duplicate(true)
		var room := fixture.duplicate(true)
		room.iid = name + "_room"
		room.pxWid = 320 if name == "act_one" else 640
		source.iid = name + "_world"
		source.levels = [room]
		var file := FileAccess.open(folder + name + ".ldtk", FileAccess.WRITE)
		file.store_string(JSON.stringify(source))
		file.close()
	for order in [["act_one", "act_two"], ["act_two", "act_one"]]:
		for name: String in order:
			var generated: Array[String] = []
			var variants: Array[String] = []
			var result: int = importer._import(folder + name + ".ldtk", folder + name,
				options.duplicate(true), variants, generated)
			_check(result == OK, "%s imports successfully" % name)
		for name in ["act_one", "act_two"]:
			var packed := ResourceLoader.load(folder + name + ".scn", "PackedScene",
				ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
			var world := packed.instantiate()
			var room: LDTKLevel = world.get_node("Level_2")
			_check(room.iid == name + "_room", "%s preserves its own room after order %s" % [name, order])
			_check(room.has_node("Origin_" + name + "_room"), "%s preserves its own child nodes" % name)
			_check(room.size.x == (320 if name == "act_one" else 640), "%s preserves its own geometry" % name)
			_check(room.scene_file_path == folder + "levels/" + name + "/Level_2.scn",
				"%s owns a separate scene file" % name)
			world.free()
	importer = null
	_remove_fixture(folder)
	print("LDTK IMPORT ISOLATION: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _remove_fixture(folder: String) -> void:
	var dir := DirAccess.open(folder)
	for file in dir.get_files():
		dir.remove(file)
	for subdir in dir.get_directories():
		_remove_fixture(folder.path_join(subdir))
	DirAccess.remove_absolute(folder)

func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
