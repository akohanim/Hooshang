extends Node2D
## Boss encounters keep the original animated silhouette at a fixed scale.
## The earlier atmospheric manifestations retain their procedural forms.
const ORIGINAL=preload("res://scenes/characters/darkshang/DarkshangVisual.tscn")
var recognizable:=false
var visual:Node2D
var velocity:=Vector2.ZERO
var form:=1
var iteration:=0
var presence:=0.0
var clock:=0.0
var fading:=false
var warning:=false
var room_size:=Vector2(320,192)
var anchor:=Vector2(260,144)
func _ready()->void:
	if recognizable:
		visual=ORIGINAL.instantiate()
		visual.scale=Vector2(.9,.9)
		visual.z_as_relative=false
		visual.z_index=1
		visual.use_parent_material=true
		add_child(visual)
		visual.get_node("Body").use_parent_material=true
		visual.get_node("Body/Sprite").use_parent_material=true

func _process(delta:float)->void:
	clock+=delta
	if recognizable and visual!=null:
		visual.position=anchor.round()
		visual.modulate.a=presence
		visual.set_motion(2 if warning else (1 if velocity.length()>1 else 0),velocity)
	queue_redraw()
func _draw()->void:
	if recognizable:return
	if presence<=0 or form==0:return
	var ink:=Color(0.008,0.01,0.021,presence)
	var edge:=Color(0.24,0.28,0.35,0.38*presence)
	if form==5:
		# Shoulder arches, head and two long arms dissolve into the room itself.
		var centre:=Vector2(room_size.x*0.52,36)
		var polygons:=[PackedVector2Array([Vector2(-18,12),Vector2(-32,34),Vector2(-76,50),Vector2(-104,136),Vector2(-42,118),Vector2(48,144),Vector2(100,132),Vector2(74,50),Vector2(28,32),Vector2(16,10)])]
		for poly:PackedVector2Array in polygons:
			for i in poly.size():poly[i]+=centre
			draw_colored_polygon(poly,ink)
			draw_polyline(poly,Color(.21,.25,.32,presence*.55),1)
		draw_circle(centre+Vector2(0,3),19,ink)
		draw_arc(centre+Vector2(0,3),19,PI,TAU,24,Color(.21,.25,.32,presence*.55),1)
		for i in 12:
			var y:=52+i*9
			var x:=centre.x-96+sin(clock*.5+i)*12
			draw_rect(Rect2(floorf(x),y,184,3),Color(0.08,0.095,0.13,presence*(.18 if fading else .4)))
		for side in [-1,1]:
			var end:=centre+Vector2(side*(112+sin(clock*.7)*9),124)
			draw_line(centre+Vector2(side*54,50),end,ink,17)
			draw_line(end,end+Vector2(-side*27,18),ink,9)
		if warning:
			for x in [-6,5]:draw_rect(Rect2(centre+Vector2(x,0),Vector2(2,2)),Color(.6,.49,.51,presence))
	else:
		var h:float=[0,25,33,46,68][form]+(iteration%3)*2
		var w:float=[0,8,12,19,32][form]
		var origin:=anchor
		# Collapse, shear and fragmentation distinguish each departure.
		if fading and form==2:h=maxf(22,h*presence);w*=2-presence
		if fading and form==4:h*=1.0+(1.0-presence)*.8
		for ghost in range(3 if form>=3 else 1):
			var shift:=Vector2(sin(clock*1.7+ghost+iteration)*float(form-1)*2,0)
			if form==3:shift.x+=(1-presence)*(ghost-1)*30
			var o:=origin+shift
			var c:=ink;c.a*=1.0 if ghost==0 else .18
			draw_circle(o+Vector2(0,-h+5),5+form,c)
			draw_arc(o+Vector2(0,-h+5),5+form,PI,TAU,12,edge,1)
			if ghost==0:draw_rect(Rect2(o+Vector2(-3,-h+5),Vector2(1,1)),Color(.43,.46,.5,presence*.7))
			var poly:=PackedVector2Array([o+Vector2(-w*.3,-h+10),o+Vector2(-w,-h*.6),o+Vector2(-w*.8,-5),o+Vector2(-3,0),o+Vector2(0,-10),o+Vector2(4,0),o+Vector2(w*.75,-4),o+Vector2(w,-h*.6),o+Vector2(w*.3,-h+9)])
			draw_colored_polygon(poly,c)
			draw_polyline(poly,edge,1)
			if warning:draw_line(o+Vector2(-w,-h*.6),o+Vector2(-w-20,-h*.4),c,3+form)
		if form>=3:
			for i in 7:
				var yy:=origin.y-h+i*h/7
				if (int(clock*7)+i)%4==0:draw_rect(Rect2(origin.x-w-3,yy,w*2+6,2),Color(.12,.14,.19,presence*.65))
	# Detached fog curls, never Light2D and never a collision shape.
	for i in range(form*6):
		var x:=fposmod(i*43+clock*(3+form),room_size.x)
		var y:=room_size.y-18-fposmod(i*17+clock*2,40+form*9)
		draw_rect(Rect2(floorf(x),floorf(y),12+form*5,2),Color(.08,.095,.125,.22*presence))
