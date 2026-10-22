extends Node2D
## Minimal world used to prove loading never runs hidden gameplay.
var ticks := 0


func _physics_process(_delta: float) -> void:
	ticks += 1
