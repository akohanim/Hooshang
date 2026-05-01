extends StaticBody2D
## Temporary document platform spawned by the player's dash.
## Lasts LIFETIME seconds, flickers, then vanishes.

const LIFETIME    := 1.5    # seconds before the platform disappears
const FADE_START  := 0.40   # seconds remaining when alpha fade begins
const FLICKER_T   := 0.18   # seconds remaining when rapid flicker begins

var _t : float = 0.0


func _process(delta: float) -> void:
	_t += delta
	var remaining := LIFETIME - _t

	if remaining <= 0.0:
		queue_free()
		return

	if remaining < FLICKER_T:
		# Rapid flicker as the platform is about to vanish.
		modulate.a = 0.35 + 0.65 * abs(sin(_t * 55.0))
	elif remaining < FADE_START:
		modulate.a = remaining / FADE_START
	else:
		modulate.a = 1.0
