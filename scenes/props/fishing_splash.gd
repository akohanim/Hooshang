extends Node2D
## One-pixel droplets and a widening surface ripple, on the world pixel grid.
var elapsed := 0.0
func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.5:
		queue_free()
	else:
		queue_redraw()
func _draw() -> void:
	var color := Color(0.76, 0.93, 0.90, 1.0 - elapsed * 2.0)
	var radius := roundf(2.0 + elapsed * 16.0)
	draw_line(Vector2(-radius, 0), Vector2(-radius + 3, 0), color, 1.0)
	draw_line(Vector2(radius - 3, 0), Vector2(radius, 0), color, 1.0)
	for side in [-1, 1]:
		var point := Vector2(side * (2 + elapsed * 12), -sin(elapsed * PI * 2) * 6).round()
		draw_rect(Rect2(point, Vector2.ONE), color)
