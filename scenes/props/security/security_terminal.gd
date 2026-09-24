class_name SecurityTerminal
extends Node2D
## A numbered console on a scaffold deck. One consistent interaction:
## stand at the lit terminal until its visible charge meter fills.
const FONT = preload("res://assets/fonts/pixel5x7.fnt")
var touch_mode := false
var number := 1
var next_number := 1
var enabled := false
var charged := false
var progress := 0.0
var nearby := false

func show_state(next: bool, done: bool, fraction: float, near_player: bool) -> void:
	enabled = next
	charged = done
	progress = fraction
	nearby = near_player
	queue_redraw()

func _draw() -> void:
	var color := Color("9ce8a4") if charged else (Color("78e7f2") if enabled else Color("7d8996"))
	# A physical monitor and plinth, rather than an unexplained floor symbol.
	draw_rect(Rect2(-2,-7,4,7),Color("56697d"))
	draw_rect(Rect2(-7,-2,14,2),Color("b6c3cd"))
	draw_rect(Rect2(-9,-20,18,14),Color("33485c"))
	draw_rect(Rect2(-8,-19,16,12),Color("14202d"))
	draw_rect(Rect2(-9,-20,18,14),color,false,1)
	if charged:
		draw_polyline(PackedVector2Array([Vector2(-4,-13),Vector2(-1,-10),Vector2(5,-16)]),color,1)
	else:
		draw_string(FONT,Vector2(-3,-10),str(number),HORIZONTAL_ALIGNMENT_LEFT,-1,7,color)
	if enabled:
		draw_colored_polygon(PackedVector2Array([Vector2(-3,-27),Vector2(3,-27),Vector2(0,-23)]),color)
		draw_rect(Rect2(-8,-5,16,2),Color("263c50"))
		draw_rect(Rect2(-8,-5,roundf(16*progress),2),color)
	if nearby:
		var text := "CHARGED" if charged else (("TOUCH" if touch_mode else "HOLD STILL") if enabled else "FIRST %d" % next_number)
		var w := FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x
		draw_rect(Rect2(-w/2-3,-40,w+6,11),Color("111d2c"))
		draw_string(FONT,Vector2(roundf(-w/2),-32),text,HORIZONTAL_ALIGNMENT_LEFT,-1,7,color)
