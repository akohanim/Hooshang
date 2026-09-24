class_name SecurityGate
extends StaticBody2D
## A doorway-sized sliding security shutter. The room owns authorization;
## the gate owns its matching collision and visible opening animation.
const FONT = preload("res://assets/fonts/pixel5x7.fnt")
## Opening dimensions in native game pixels, measured from the top-left origin.
@export var opening_size := Vector2(32,32)
## Seconds for the shutter panels to retract after authorization.
@export var opening_time := 0.4
var authorized := false
var completed := 0
var total := 3
var slide := 0.0
@onready var barrier: CollisionShape2D = $Barrier

func _ready() -> void:
	var box := RectangleShape2D.new()
	box.size = opening_size
	barrier.shape = box
	barrier.position = opening_size / 2
	set_access(false)

func set_access(value: bool) -> void:
	authorized = value
	if is_instance_valid(barrier):barrier.set_deferred("disabled",value)
	queue_redraw()

func set_progress(value: int, count: int) -> void:
	completed = value
	total = count
	queue_redraw()

func _process(delta: float) -> void:
	slide = move_toward(slide,1.0 if authorized else 0.0,delta / opening_time)
	queue_redraw()

func _draw() -> void:
	var w := opening_size.x
	var h := opening_size.y
	var ink := Color("78e7f2") if not authorized else Color("9ce8a4")
	# Recessed steel jambs, bright access strips and a two-piece shutter.
	draw_rect(Rect2(0,0,w,h),Color("14202e"))
	var leaf := floorf((w/2-3)*(1-slide))
	for right in [false,true]:
		var x := w-3-leaf if right else 3.0
		if leaf>0:
			draw_rect(Rect2(x,3,leaf,h-5),Color("435466"))
			draw_rect(Rect2(x,3,leaf,1),Color("a4b8c6"))
			for y in range(7,int(h)-3,6):draw_line(Vector2(x,y),Vector2(x+leaf-1,y),Color("283747"),1)
	# An open doorway shows the room instead of an opaque slab.
	if slide>0:draw_rect(Rect2(w/2-floorf((w/2-3)*slide),3,floorf((w-6)*slide),h-5),Color("0c111b"))
	for x in [0.0,w-3]:
		draw_rect(Rect2(x,0,3,h),Color("63798a"))
		draw_rect(Rect2(x+1,5,1,h-10),ink)
	draw_rect(Rect2(0,0,w,3),Color("91a3b0"))
	draw_rect(Rect2(0,h-2,w,2),Color("354b5f"))
	draw_string(FONT,Vector2(4,-3),"EXIT",HORIZONTAL_ALIGNMENT_LEFT,-1,7,ink)
	var label := "OPEN" if authorized else "%d/%d" % [completed,total]
	var label_width := FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x
	draw_rect(Rect2(w/2-label_width/2-2,h/2-6,label_width+4,10),Color("101b29"))
	draw_string(FONT,Vector2(roundf((w-label_width)/2),h/2+2),label,HORIZONTAL_ALIGNMENT_LEFT,-1,7,ink)
