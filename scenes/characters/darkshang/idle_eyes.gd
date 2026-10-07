@tool
extends Node2D
## The humanoid idle sheet has no eyes. Keep its breathing silhouette and add
## a separate blink, so holding dialogue never leaves the face blank.
@export var blink_interval := 3.7
@export var blink_duration := 0.24
var age := 0.0
var openness := 1.0

func _process(delta: float) -> void:
	var sprite := get_parent() as AnimatedSprite2D
	visible = sprite.animation == &"idle"
	if not visible: return
	age = fmod(age + delta, maxf(blink_interval, 0.01))
	var duration := clampf(blink_duration, 0.001, blink_interval)
	var phase := (age - (blink_interval - duration)) / duration
	openness = 1.0
	if phase >= 0.0:
		openness = 0.0 if phase >= 0.25 and phase < 0.75 else 0.5
	# Matches the idle sheet's one-pixel rise in frames 1 and 2.
	position.y = -1.0 if sprite.frame in [1, 2] else 0.0
	scale.x = -1.0 if sprite.flip_h else 1.0
	queue_redraw()

func _draw() -> void:
	for x in [-3.0, 3.0]:
		if openness == 0.0:
			draw_rect(Rect2(x - 1, -36, 3, 1), Color("354451"))
		else:
			draw_rect(Rect2(x - 1, -37, 3, 3), Color(0.33, 0.57, 0.72, 0.25))
			draw_rect(Rect2(x - 1, -36, 3, 2 if openness == 1.0 else 1), Color("d8f0ff"))
