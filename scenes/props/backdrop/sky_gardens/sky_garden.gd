extends Node2D
## Room-local non-solid garden dressing. Native pixels and existing art ramps.
@export var recipe: Dictionary = {}
const FONT := preload("res://assets/fonts/pixel5x7.fnt")
const SHEET := preload("res://assets/props/sky_gardens/ornaments.png")
var _clock := 0.0
var _finished := false

func _ready() -> void:
	var room := get_parent()
	for node in get_tree().get_nodes_in_group("checkpoint"):
		if room.is_ancestor_of(node):
			node._visual.hide()
	for node in get_tree().get_nodes_in_group("exit"):
		if room.is_ancestor_of(node):
			var sign := node.get_node_or_null("ExitSign")
			if sign != null: sign.hide()
			if recipe.name == "Act_2_Level_8": node.body_entered.connect(_complete)
	queue_redraw()

func _complete(body: Node2D) -> void:
	if body is not Player or _finished: return
	_finished = true
	var label := Label.new()
	label.text = "GARDEN OF KINGS\nYOU MADE IT."
	label.position = Vector2(float(recipe.exit[0])-92,8)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size",7)
	label.add_theme_color_override("font_color",Color("ffe9b5"))
	add_child(label)

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _sprite(at: Vector2, source: Rect2, tint := Color.WHITE) -> void:
	draw_texture_rect_region(SHEET,Rect2(at,source.size),source,tint)

func _draw() -> void:
	if recipe.is_empty():return
	for l: Array in recipe.ledges:
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
		var x := fposmod(i*57.0+_clock*3.0,630.0)
		var y := 64.0+fposmod(i*31.0+sin(_clock*0.6+i)*4.0,206.0)
		draw_rect(Rect2(Vector2(x,y).floor(),Vector2(2,1)),Color(1,0.83,0.58,0.35))

