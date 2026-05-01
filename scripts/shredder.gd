extends Node2D
## Industrial paper shredder — kills on blade contact, pulls nearby
## players toward it with a subtle vacuum effect.

signal player_hit

## Pull force in px/s² applied toward shredder when player is in vacuum zone.
const VACUUM_ACCEL := 90.0

@onready var _kill_zone   : Area2D = $KillZone
@onready var _vacuum_zone : Area2D = $VacuumZone


func _ready() -> void:
	_kill_zone.body_entered.connect(_on_kill_zone_entered)


func _physics_process(delta: float) -> void:
	# Apply gentle pull toward this shredder for every player in vacuum range.
	for body in _vacuum_zone.get_overlapping_bodies():
		if body.has_method("add_force"):
			var dir := (global_position - body.global_position).normalized()
			body.add_force(dir * VACUUM_ACCEL * delta)


func _on_kill_zone_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_hit.emit()
