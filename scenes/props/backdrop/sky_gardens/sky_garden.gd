extends Node2D
## Room-local non-solid garden dressing. Native pixels and existing art ramps.
@export var recipe: Dictionary = {}
const FONT := preload("res://assets/fonts/pixel5x7.fnt")
const SHEET := preload("res://assets/props/sky_gardens/ornaments.png")
var _clock := 0.0

func _ready() -> void:
	var room := get_parent()
	for node in get_tree().get_nodes_in_group("checkpoint"):
		if room.is_ancestor_of(node):
			node._visual.hide()
	for node in get_tree().get_nodes_in_group("exit"):
		if room.is_ancestor_of(node):
			var sign := node.get_node_or_null("ExitSign")
			if sign != null: sign.hide()
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _sprite(at: Vector2, source: Rect2, tint := Color.WHITE) -> void:
	draw_texture_rect_region(SHEET,Rect2(at,source.size),source,tint)

func _draw() -> void:
	if recipe.is_empty():return
	# Resting islands retain their checkpoint behavior without flags competing
	# with the route. Their broad grass edge is the landing cue.
	draw_string(FONT,Vector2(17,265),str(recipe.title),HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color(0.24,0.20,0.13,0.9))
	draw_string(FONT,Vector2(16,264),str(recipe.title),HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("ffe9b5"))
	for l: Array in recipe.ledges:
		# Small transfer ledges need their whole silhouette to read as footing.
		# Reserve botanical accents for the broad resting islands.
		if float(l[2]) < 64:continue
		var transfer_island:=false
		for step: Dictionary in recipe.get("routes",[]):
			if step.kind=="weave":
				for island: Array in step.islands:
					if island[0]==l[0]:transfer_island=true
		if transfer_island:continue
		var at := Vector2(l[0],l[1])
		# Botanical details never cover a spring face or its approach.
		var clear := true
		for spring: Array in recipe.get("side_springs", []):
			if absf(float(spring[0])-at.x-10)<26 and absf(float(spring[1])-at.y)<24:clear=false
		for spring: Array in recipe.springs:
			if absf(float(spring[0])-at.x-10)<26 and absf(float(spring[1])-at.y)<8:clear=false
		if clear:_sprite(at+Vector2(2,-24),Rect2(102,70,18,24),Color(1,1,1,0.85))
	for c: Array in recipe.carpets:
		# A fixed launch arrow describes forward travel, without implying a
		# bobbing or sweeping autonomous pattern.
		var p := Vector2(c[0]+34,c[1])
		draw_line(p-Vector2(10,0),p,Color("d7a453"))
		draw_line(p,p-Vector2(4,3),Color("d7a453"))
		draw_line(p,p-Vector2(4,-3),Color("d7a453"))
	# The destination is an open tiled portal, consistent through the five rooms.
	var end: Array = recipe.exit
	draw_texture_rect_region(SHEET,Rect2(Vector2(end[0]-8,end[1]-46),Vector2(32,46)),Rect2(0,0,64,92),Color(1,0.96,0.86,0.9))
	# A few drifting petals provide motion without covering jumps or platforms.
	for i in 12:
		var x := fposmod(i*57.0+_clock*3.0,float(recipe.width)-10.0)
		var y := 64.0+fposmod(i*31.0+sin(_clock*0.6+i)*4.0,206.0)
		draw_rect(Rect2(Vector2(x,y).floor(),Vector2(2,1)),Color(1,0.83,0.58,0.35))
