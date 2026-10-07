extends Player
## Acceptance driver removes conveniences; required routes cannot use a mantle.
func _try_ledge_mantle(_input_x: float, _approach_speed := 0.0) -> bool:
	return false
func _try_bank_mantle(_input_x: float, _surface: float) -> bool:
	return false
