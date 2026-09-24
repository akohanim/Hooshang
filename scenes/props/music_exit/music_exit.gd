class_name MusicExit
extends Node2D
## Reuses the security shutter; opening it releases a warm pool of light.
## Brightness of the light spilling through the unlocked doorway.
@export var open_energy := 1.25
@onready var gate: SecurityGate = $SecurityGate
@onready var spill: PointLight2D = $Spill

func set_state(progress: int, total: int, opened: bool) -> void:
	gate.set_progress(progress, total)
	gate.set_access(opened)

func _process(delta: float) -> void:
	spill.energy = move_toward(spill.energy, open_energy if gate.authorized else 0.0, delta * open_energy)
