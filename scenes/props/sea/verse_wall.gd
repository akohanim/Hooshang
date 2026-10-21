class_name VerseWall
extends Node2D
## The alley wall from the end of Act II, with both lines of the verse on it,
## standing on the Act III shore for the opening beat: "The paint begins to run.
## Not down — outward. Every stroke loosens into a line of white that ripples,
## until the whole wall is water standing upright. Then it is not standing at
## all."
##
## Drawn in the act's line language: a white outline, the two lines of paint as
## strokes (the verse is Persian; at this size it reads as script, not words).
## `dissolve()` runs the beat: each row of the wall slides and thins into a
## horizontal line, then the lines fall to the sea and are gone. The origin is
## the wall's BOTTOM-CENTRE.

const SIZE := Vector2(56.0, 44.0)

var _t := -1.0  # < 0: standing; 0..1 rippling; 1..2 falling
var _rows: Array[float] = []


func _ready() -> void:
	z_index = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 1979
	for i in int(SIZE.y):
		_rows.append(rng.randf())


func dissolve(duration := 3.2) -> void:
	_t = 0.0
	var t := create_tween()
	t.tween_property(self, "_t", 2.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	visible = false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := SIZE.x
	var h := SIZE.y
	var origin := Vector2(-w * 0.5, -h)
	if _t < 0.0:
		_draw_standing(origin)
		return
	var ripple := clampf(_t, 0.0, 1.0)
	var fall := clampf(_t - 1.0, 0.0, 1.0)
	var time := Time.get_ticks_msec() / 1000.0
	for i in int(h):
		var r: float = _rows[i]
		# Every row becomes a line: it slides on its own wave, loses its
		# middle, and finally drops toward the waterline (y = 0).
		var shift := sin(time * (2.0 + r * 2.0) + i * 0.4) * ripple * (4.0 + r * 10.0)
		var keep := 1.0 - ripple * (0.45 + r * 0.5)
		var len := w * maxf(keep, 0.12)
		var y := origin.y + i + fall * fall * (h - i + 6.0 + r * 14.0)
		var x := origin.x + (w - len) * 0.5 + shift
		var alpha := (1.0 - fall) * (0.55 + 0.45 * ripple)
		var row_is_paint := (i > 12 and i < 18) or (i > 24 and i < 30)
		if i % 2 == 0 or row_is_paint or ripple > 0.6:
			draw_rect(Rect2(Vector2(x, y).floor(), Vector2(roundf(len), 1.0)), Color(1, 1, 1, alpha))


func _draw_standing(origin: Vector2) -> void:
	var w := SIZE.x
	var h := SIZE.y
	draw_rect(Rect2(origin, SIZE), Color(0, 0, 0, 1))
	draw_rect(Rect2(origin, SIZE), Color(1, 1, 1, 1), false, 1.0)
	# The two lines of paint, right to left, as joined script strokes.
	for line in 2:
		var y := origin.y + 15.0 + line * 12.0
		var x := origin.x + w - 6.0
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + line
		while x > origin.x + 6.0:
			var seg := rng.randi_range(3, 7)
			draw_line(Vector2(x, y), Vector2(x - seg, y), Color(1, 1, 1), 1.0)
			if rng.randf() < 0.6:
				var up := rng.randi_range(2, 5)
				draw_line(Vector2(x - seg * 0.5, y), Vector2(x - seg * 0.5, y - up), Color(1, 1, 1), 1.0)
			if rng.randf() < 0.35:
				draw_rect(Rect2(Vector2(x - seg * 0.5, y + 2), Vector2.ONE), Color(1, 1, 1))
			x -= seg + rng.randi_range(1, 3)
	# A drip from the newest line: the paint is still wet.
	draw_line(Vector2(origin.x + 20, origin.y + 28), Vector2(origin.x + 20, origin.y + 33), Color(1, 1, 1, 0.7), 1.0)
