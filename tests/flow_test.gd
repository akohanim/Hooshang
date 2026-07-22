extends Node
## Entry point for the real level-flow test. Spawns a persistent observer on the
## tree root (which survives the scene change) and hands control to it.


func _ready() -> void:
	var obs := Node.new()
	obs.set_script(load("res://tests/flow_observer.gd"))
	get_tree().root.add_child.call_deferred(obs)
