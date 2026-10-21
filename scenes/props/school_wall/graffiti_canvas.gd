extends Node2D
var paint_marks: Array[Dictionary] = []
const PAINT_COLORS := [Color("4d8da3"), Color("d66e65"), Color("d7a94e")]

func spray(at: Vector2, color_index: int) -> void:
	# Quantized, deterministic droplets stay crisp and keep repainting bounded.
	var center := at.round()
	for mark: Dictionary in paint_marks:
		if mark.at == center and mark.color == color_index: return
	if paint_marks.size() >= 1800: paint_marks.pop_front()
	paint_marks.append({"at": center, "color": color_index})
	queue_redraw()
## The cousins build one mural together over several dialogue beats.
var stage := 0:
	set(value):
		stage = value
		queue_redraw()

func _draw() -> void:
	if stage >= 1:
		# Jamshid starts with the sun.
		draw_arc(Vector2(83, -77), 17, 0, TAU, 24, Color("dc8c45"), 3)
		for angle in 8:
			var direction := Vector2.RIGHT.rotated(angle * TAU / 8.0)
			draw_line(Vector2(83, -77) + direction * 22, Vector2(83, -77) + direction * 28, Color("e2a65c"), 2)
	if stage >= 2:
		# Hooshang adds birds crossing the sun.
		for center in [Vector2(121, -83), Vector2(145, -70), Vector2(166, -88)]:
			draw_polyline(PackedVector2Array([center + Vector2(-10, 0), center + Vector2(-4, -4), center, center + Vector2(5, -4), center + Vector2(11, -2)]), Color("416d82"), 3)
	if stage >= 3:
		# They finish with a shared vine and bright flowers.
		draw_polyline(PackedVector2Array([Vector2(45, -29), Vector2(77, -39), Vector2(116, -33), Vector2(150, -45), Vector2(190, -35)]), Color("65875d"), 3)
		for center in [Vector2(77, -39), Vector2(150, -45)]:
			for angle in 5:
				draw_circle(center + Vector2(5, 0).rotated(angle * TAU / 5.0), 3, Color("c96865"))
			draw_circle(center, 2, Color("f6c56f"))
	for mark: Dictionary in paint_marks:
		var at: Vector2 = mark.at
		var ink: Color = PAINT_COLORS[mark.color]
		draw_circle(at, 2.0, ink)
		for dot in [Vector2(-3,-2), Vector2(3,1), Vector2(-1,3), Vector2(2,-3)]:
			draw_rect(Rect2(at + dot, Vector2.ONE), ink.lightened(0.12))
