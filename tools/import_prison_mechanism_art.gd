@tool
extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var fs=EditorInterface.get_resource_filesystem()
	while fs.is_scanning():await process_frame
	fs.reimport_files(PackedStringArray(["res://assets/props/prison_circuits/circuit.png","res://assets/props/prison_circuits/timed.png","res://ldtk/art/prison/school.png"]))
	print("MECHANISM ART IMPORTED")
	quit()
