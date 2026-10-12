extends Control
## A lightweight architectural miniature, drawn from the same LDtk geometry.
var room: Dictionary = {}
var accent := Color("e6bb78")
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("101c29"))
	for x in range(0,int(size.x),24):
		draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.8,0.9,1,0.035))
	for y in range(0,int(size.y),24):
		draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.8,0.9,1,0.035))
	if room.is_empty(): return
	var extent := Vector2(room.size[0],room.size[1])
	var zoom := minf((size.x-48)/extent.x,(size.y-48)/extent.y)
	var origin := (size-extent*zoom)*0.5
	for cell in room.cells:
		draw_rect(Rect2(origin+Vector2(cell[0],cell[1])*zoom,Vector2.ONE*float(cell[2])*zoom),(Color("65b7d0") if cell[3]==4 else Color("d37c76") if cell[3]==3 else accent.darkened(0.25)))
	draw_rect(Rect2(origin,extent*zoom),Color(accent,0.35),false,1)

	for marker in room.markers:
		var color := Color("8fdfbb") if marker[2] in ["PlayerStart","PlayerSpawn","Checkpoint"] else Color("f6da86")
		var at := origin+Vector2(marker[0],marker[1])*zoom
		draw_circle(at,4,color)
		draw_circle(at,7,Color(color,0.18))
