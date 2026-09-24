@tool
extends Node2D
const PATH_ART = preload("res://scenes/props/backdrop/thought_path_art.gd")
@export var thought_paths:Array=[]
## Native-resolution modular pixel scenery: amber glass, planters, tea station,
## book niches and upholstery. Background only; all gameplay lives in LDtk.
@export var theme := "garden"
var _time := 0.0
func _process(delta:float)->void:
	_time += delta
	queue_redraw()
func box(x:float,y:float,w:float,h:float,c:String)->void:
	draw_rect(Rect2(x,y,w,h),Color(c))
func _draw()->void:
	# Warm plaster with fine coursing, darker skirting and copper trim.
	box(8,8,304,176,"4b3b37")
	for y in range(8,168):
		var t:=float(y-8)/160.0
		draw_line(Vector2(8,y),Vector2(312,y),Color("715749").lerp(Color("352e32"),t),1)
	for y in range(20,164,12):
		for x in range(12,308,24):
			box(x+(6 if y%24==8 else 0),y,8,1,"6a5043")
	box(8,160,304,8,"483931")
	box(8,160,304,1,"a17e54")
	for x in [20,120,220]:window(x,20)
	if theme=="garden":
		for x in [32,92,132,202,264,288]:plant(x,159,22+(x%3)*7)
		bench(128,144)
	elif theme=="tea":
		box(28,130,76,4,"c49868");box(32,134,4,26,"735343");box(96,134,4,26,"735343")
		box(38,119,12,11,"759288");box(39,118,10,2,"b9c4a0")
		box(50,121,4,5,"b9c4a0");box(51,122,2,3,"4b3b37")
		for x in [64,78]:
			box(x,125,6,5,"e2c795");box(x+1,124,4,1,"886146")
			var sy:=119-int(fposmod(_time*3+x,6))
			box(x+2,sy,1,3,"a49a80")
		bench(176,150);plant(276,160,34)
	else:
		for x in [28,234]:
			box(x,98,52,61,"392f30")
			for y in [101,120,139]:
				for i in 7:
					var h:=10+(i*3)%6
					box(x+3+i*6,y+16-h,4,h,["9a745b","64827b","a89268","836573"][i%4])
					box(x+4+i*6,y+13,2,1,"d4bc87")
				box(x,y+17,52,2,"bc9365")
		bench(130,146);plant(204,160,26)
	PATH_ART.draw_paths(self,thought_paths)
	# Tiny motes, deliberately behind the readable platform silhouettes.
	for i in 14:
		var x:=20+(i*37)%276
		var y:=36+int(fposmod(i*23+_time*2,100))
		box(x,y,1,1,"b49a6e")
func window(x:int,y:int)->void:
	box(x-2,y-2,80,86,"322c30");box(x-1,y-1,78,84,"b18b5e")
	for row in 78:
		var c:=Color("c89c70").lerp(Color("776e70"),float(row)/78)
		draw_line(Vector2(x+2,y+2+row),Vector2(x+72,y+2+row),c,1)
	# Softly layered skyline and small lit windows, always snapped to pixels.
	for i in 7:
		var h:=8+(i*13+x)%23
		box(x+3+i*10,y+78-h,8,h,"70646a")
		box(x+5+i*10,y+80-h,2,2,"d8b37e")
	box(x+36,y,3,82,"594943");box(x,y+40,76,3,"665047")
	box(x-3,y+82,82,4,"c19b6b");box(x-3,y+86,82,2,"634e40")
	box(x+4,y+4,1,30,"e2bd84");box(x+6,y+4,18,1,"d5ac7b")
func plant(x:int,y:int,h:int)->void:
	box(x-6,y-10,12,10,"986952");box(x-7,y-11,14,3,"c28b60")
	box(x-4,y-7,2,6,"c59368");box(x-1,y-h,2,h-10,"788164")
	for i in 4:
		var yy:=y-h+i*5
		var side:=1 if i%2==0 else -1
		box(x+side*2-(7 if side<0 else 0),yy,7,4,"526e5d")
		box(x+side*2-(6 if side<0 else 0),yy,5,1,"9aaf79")
func bench(x:int,y:int)->void:
	box(x-3,y-17,58,16,"69544e");box(x,y-16,52,13,"9c7964")
	box(x,y-16,52,1,"c4a07a")
	for xx in range(x+12,x+52,13):box(xx,y-14,1,10,"7f6358")
	box(x-4,y-3,60,5,"b38b67");box(x,y+2,3,8,"5c4941");box(x+48,y+2,3,8,"5c4941")
