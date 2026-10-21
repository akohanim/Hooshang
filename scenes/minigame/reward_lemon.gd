class_name MirrorRewardLemon
extends Node2D
## A bright, cropped world-space lemon that visibly exits the dark TV screen.
const ART := preload("res://assets/props/lemon/dense/frame_000.png")
var clock := 0.0

func _ready() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	set_process(true)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(clock * 13.0) * 0.1
	draw_circle(Vector2.ZERO, 13.0 * pulse, Color("fff4a0", 0.18))
	draw_circle(Vector2.ZERO, 8.0 * pulse, Color("ffe063", 0.35))
	draw_texture_rect_region(ART, Rect2(-7, -11, 14, 22), Rect2(5, 3, 10, 16))
	for i in 4:
		var angle := clock * 2.2 + i * TAU / 4.0
		var ray := Vector2.from_angle(angle)
		draw_line(ray * 12.0, ray * 17.0, Color("fff1a2", 0.75), 1.0)
