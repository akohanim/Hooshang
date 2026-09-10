@tool
extends Node2D
## Static single-pixel stars, seeded per window rather than re-rolled on entry.
## Openings and exclusions are in the parent's coordinates.

## Approximate glass area per star; sparse enough to keep the player readable.
@export var pixels_per_star := 180.0
## Muted blue-white sky light, independent of the room's interior lights.
@export var star_color := Color(0.42, 0.51, 0.66, 0.8)
var points: Array[Vector2] = []
var _brightness: Array[float] = []

func configure(openings: Array, identity: String, excluded := Rect2()) -> void:
	points.clear()
	_brightness.clear()
	for opening: Rect2 in openings:
		if excluded.has_area() and opening.intersects(excluded):
			continue
		var glass := opening.grow(-2.0)
		if glass.size.x < 1 or glass.size.y < 1:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(identity + str(opening))
		var count := maxi(1, roundi(glass.get_area() / pixels_per_star))
		var pane_points: Array[Vector2] = []
		for attempt in range(count * 12):
			if pane_points.size() >= count:
				break
			var point := Vector2(rng.randi_range(ceili(glass.position.x), floori(glass.end.x) - 1),
				rng.randi_range(ceili(glass.position.y), floori(glass.end.y) - 1))
			var crowded := false
			for previous in pane_points:
				if previous.distance_squared_to(point) < 16:
					crowded = true
					break
			if crowded:
				continue
			pane_points.append(point)
			points.append(point)
			_brightness.append(rng.randf_range(0.55, 1.0))
	queue_redraw()

func _draw() -> void:
	for i in points.size():
		draw_rect(Rect2(points[i], Vector2.ONE), star_color * Color(1, 1, 1, _brightness[i]))
