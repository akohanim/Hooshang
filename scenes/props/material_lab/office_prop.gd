@tool
extends Node2D
## The imported enum selects one repeatable, non-colliding decorative silhouette.
@export_enum("Paper", "Rubble", "Pipe", "Sign", "Plant") var variant := "Paper":
	set(value):
		variant = value
		queue_redraw()
func _draw() -> void:
	match variant:
		"Paper":
			draw_rect(Rect2(-3,-2,7,2), Color("b9b5a3"))
			draw_line(Vector2(-1,-2),Vector2(2,-2),Color("73777c"))
		"Rubble":
			draw_rect(Rect2(-4,-2,4,2),Color("725354"))
			draw_rect(Rect2(1,-3,3,3),Color("969f9b"))
		"Pipe":
			draw_rect(Rect2(0,-12,3,18),Color("4b5765"))
			draw_line(Vector2(0,-10),Vector2(0,5),Color("647180"))
			draw_rect(Rect2(-1,-8,5,2),Color("353e4c"))
		"Sign":
			draw_rect(Rect2(-8,-6,16,7),Color("353e4c"))
			draw_line(Vector2(-5,-3),Vector2(5,-3),Color("8097a5"))
		"Plant":
			draw_rect(Rect2(-3,-4,6,4),Color("725354"))
			draw_line(Vector2(0,-4),Vector2(0,-11),Color("647180"))
			draw_line(Vector2(0,-7),Vector2(-4,-10),Color("969f9b"))
			draw_line(Vector2(0,-8),Vector2(4,-12),Color("969f9b"))
