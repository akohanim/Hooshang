@tool
extends SceneTree
## Targeted import avoids touching another Act's open authoring session.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var importer = load("res://addons/ldtk-importer/ldtk-importer.gd").new()
	var config := ConfigFile.new()
	config.load("res://ldtk/hooshang_act2.ldtk.import")
	var options := {}
	for option: Dictionary in importer._get_import_options("",0):
		options[option.name] = config.get_value("params",option.name,option.default_value)
	var generated: Array[String] = []
	var variants: Array[String] = []
	var path: String = config.get_value("remap","path")
	var result: int = importer._import("res://ldtk/hooshang_act2.ldtk",path.trim_suffix(".scn"),options,variants,generated)
	print("ACT2_TARGETED_IMPORT ",result)
	quit(result)
