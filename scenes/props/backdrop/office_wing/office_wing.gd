@tool
extends Node2D
const PATH_ART = preload("res://scenes/props/backdrop/thought_path_art.gd")
@export var thought_paths:Array=[]
## Room-local architectural dressing. Routes remain editable in LDtk; this
## prefab renders no collision and never owns story or chase state.
@export var room_size := Vector2(640,224)
@export var theme := "copper"
@export var route: Array = []
@export var is_escape := false
@export var is_encounter := false
@export var is_return_portal := false
var _clock := 0.0
var _alarm := 0.0
var _last_frame := -1

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if is_encounter:
		for node in get_tree().get_nodes_in_group("darkshang_trigger"):
			if get_parent().is_ancestor_of(node):
				node.triggered.connect(_reveal)
				node.chase_begun.connect(_chase)

func _reveal(_player: Player) -> void:
	create_tween().tween_property(self, "_alarm", 0.4, 0.8)
func _chase() -> void:
	create_tween().tween_property(self, "_alarm", 1.0, 2.0)
func _process(delta: float) -> void:
	_clock += delta
	var frame := int(_clock * 10)
	if frame != _last_frame:
		_last_frame = frame
		queue_redraw()
func box(x: float,y: float,w: float,h: float,c: String) -> void:
	draw_rect(Rect2(x,y,w,h),Color(c))

func _draw() -> void:
	if not is_escape and not is_encounter:
		# Freestanding service architecture in front of the subdued painted wall.
		for x in range(28,int(room_size.x)-24,96):
			match theme:
				"archive": _shelves(x,40)
				"vent": _fan(Vector2(x+30,56 + (x/96%2)*96))
				"copper": _pipes(x)
				"glass": _glass(x,24)
				"threshold": _pipes(x)
		if theme == "threshold":
			box(room_size.x-100,24,68,128,"10151f")
			box(room_size.x-99,24,1,128,"66594b")
			box(room_size.x-66,24,1,128,"42414a")
			box(room_size.x-72,92,2,8,"a98b60")
	# Hangers imply load and make masonry platforms belong to the building.
	for r in route:
		var x: float=r[0];var y: float=r[1];var w: float=r[2]
		if y < room_size.y-32:
			for xx in [x+5,x+w-6]:
				draw_line(Vector2(xx,maxf(10,y-64)),Vector2(xx,y+4),Color("29333a"),1)
				box(xx-1,y-4,3,3,"55616a")
		# A tiny direction marker sits above the landing; no route text/HUD.
		if is_escape: _arrow(Vector2(x+w/2,y-21),-1,Color("ad7656"))
	if is_escape:
		# Sparse, fixed cracks and debris silhouettes: readable even while moving.
		for x in range(40,int(room_size.x),104):
			var p:=Vector2(x,12)
			for i in 5:
				var q:=p+Vector2(7 if i%2==0 else -4,11)
				draw_line(p,q,Color("0d131d"),2)
				p=q
			box(x-4,20,8,3,"623a3c")
			box(x-2,21,4,1,"bd755b")
	if is_return_portal:
		box(294, 88, 24, 40, "080b12")
		box(292, 86, 2, 42, "4f4754")
		box(294, 86, 24, 2, "4f4754")
		for y in range(92, 128, 5):box(296, y, 22, 1, "232737")
		if _alarm > 0:
			_arrow(Vector2(278, 103), -1, Color("e3aa77"))
	if is_encounter:
		# Quiet procession toward the reveal; reverse arrows wake with the alarm.
		for x in range(40,int(room_size.x)-24,48):
			box(x,158,20,2,"58434a")
			box(x,160,20,1,"24212c")
			if _alarm>0:
				var color:=Color("e38962")
				color.a=_alarm*(0.65+0.15*sin(_clock*3))
				_arrow(Vector2(x+10,144),-1,color)
		# Tall shutter and dark frame behind the shadow, clear of the real moon.
		box(610,24,40,140,"10151e")
		box(609,24,1,140,"47505c")
		for y in range(32,158,7):box(614,y,30,1,"232d3a")
	PATH_ART.draw_paths(self,thought_paths)
	for i in 24:
		var xx:=16+(i*79)%maxi(1,int(room_size.x)-32)
		var yy:=16+fposmod(i*31+_clock*(3 if is_escape else 0.6),room_size.y-32)
		draw_rect(Rect2(xx,floorf(yy),1,1),Color(0.55,0.58,0.59,0.2))

func _pipes(x: int) -> void:
	for i in 3:
		box(x+i*7,16,4,room_size.y-32,"302b31")
		box(x+i*7+1,16,1,room_size.y-32,"72554b")
		for y in range(40,int(room_size.y)-16,48):box(x+i*7-1,y,6,2,"666063")
	box(x-4,60,30,20,"26323b")
	for i in 4:box(x+i*6,64,3,2,"68877f" if i%2==0 else "b18a65")

func _shelves(x: int,y: int) -> void:
	for row in range(y,int(room_size.y)-16,36):
		box(x,row,68,32,"19212a")
		for i in 10:
			var h:=15+(i*7+row)%12
			box(x+3+i*6,row+28-h,4,h,["4b4547","46545a","626055","3c4855"][i%4])
			box(x+4+i*6,row+24,2,1,"858878")
		box(x-2,row+29,72,3,"62666a")
		box(x-2,row+32,72,2,"1d2831")

func _glass(x: int,y: int) -> void:
	box(x,y,68,room_size.y-y-24,"1a2a36")
	box(x,y,1,room_size.y-y-24,"4c6571")
	box(x+33,y,2,room_size.y-y-24,"33444f")
	for yy in range(y+36,int(room_size.y)-24,40):box(x,yy,68,2,"354853")
	for i in 12:box(x+5+(i*13)%56,y+8+(i*19)%120,1,1,"677d89")

func _fan(at: Vector2) -> void:
	draw_circle(at,25,Color("111a24"))
	draw_arc(at,25,0,TAU,32,Color("58636a"),1,false)
	draw_arc(at,22,0,TAU,32,Color("293a45"),1,false)
	for i in 4:
		var angle:=i*PI/2+floorf(_clock*3)*0.1
		var a:=at+Vector2.from_angle(angle)*5
		var b:=at+Vector2.from_angle(angle+0.45)*19
		var c:=at+Vector2.from_angle(angle+0.9)*15
		draw_colored_polygon(PackedVector2Array([a.round(),b.round(),c.round()]),Color("394952"))
	draw_circle(at,4,Color("768084"))
	for i in [-14,0,14]:draw_line(at+Vector2(-20,i),at+Vector2(20,i),Color("192732"),1)

func _arrow(at:Vector2,direction:int,color:Color)->void:
	for i in 2:
		var p:=at+Vector2(i*5*direction,0)
		draw_line(p+Vector2(-2*direction,-2),p,color,1)
		draw_line(p,p+Vector2(-2*direction,2),color,1)
