extends SceneTree
## Read-only dependencies, including binary packed scenes. Does not prove that
## an unreferenced asset is unused: scripts/LDtk fields can construct paths.
var resources := {}
var missing: Array[Dictionary] = []

func _initialize() -> void:
	for folder in ["scenes", "resources", "ldtk", "systems", "scripts"]:
		_scan("res://" + folder)
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://output/cleanup/resource-audit.json"
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write resource audit: " + output)
		quit(1)
		return
	file.store_string(JSON.stringify({"resources": resources, "missing": missing}, "\t"))
	print("RESOURCE AUDIT: %d resources, %d missing dependencies; %s" % [resources.size(), missing.size(), output])
	quit(0 if missing.is_empty() else 1)

func _scan(path: String) -> void:
	for name in DirAccess.get_files_at(path):
		var full := path.path_join(name)
		if name.get_extension() not in ["tscn", "scn", "tres", "res", "ldtk"]:
			continue
		var dependencies := Array(ResourceLoader.get_dependencies(full))
		resources[full] = dependencies
		for dependency: String in dependencies:
			# Godot 4 dependencies are UID::type::fallback-path or type::path.
			var target: String = dependency.get_slice("::", dependency.get_slice_count("::") - 1)
			if target.begins_with("res://") and not ResourceLoader.exists(target):
				missing.append({"owner": full, "dependency": target})
	for folder in DirAccess.get_directories_at(path):
		if folder != "backups":
			_scan(path.path_join(folder))
