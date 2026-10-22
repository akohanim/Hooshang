class_name VineMouse
extends AnimatedSprite2D
## The two mice share native art/timing; the white one mirrors to face the root.

## Chooses the ivory mouse's artwork; both variants have walk and gnaw loops.
@export var white := false


func _ready() -> void:
	flip_h = white
	play(_clip("walk"))


func gnaw() -> void:
	play(_clip("gnaw"))


func _clip(action: String) -> StringName:
	return StringName(("white_" if white else "black_") + action)
