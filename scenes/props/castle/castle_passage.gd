extends Node2D
## An always-open return to the courtyard, with an explicit Up interaction.
@export var destination := "Act_2_Level_15"
const MASONRY := preload("res://ldtk/art/castle/castle-02.png")
const FONT := preload("res://assets/fonts/pixel5x7.fnt")
var world: LdtkWorld
var room: LDTKLevel
var nearby := false

func _ready() -> void:
	room = get_parent().get_parent() as LDTKLevel
	var ancestor: Node = room
	while ancestor != null and not ancestor is LdtkWorld: ancestor = ancestor.get_parent()
	world = ancestor as LdtkWorld
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if world == null or world.current_room != room: return
	var at := to_local(world.player.global_position)
	var now := Rect2(-20,-28,40,36).has_point(at)
	if now != nearby:
		nearby = now
		queue_redraw()
	if nearby and Input.is_action_just_pressed("move_up") and world.player.is_on_floor() \
			and not world.player.input_locked and not world._transitioning:
		var threshold := world.get_node_or_null("CastleThreshold")
		if threshold != null: threshold.return_to_courtyard(destination)

func _draw() -> void:
	draw_rect(Rect2(-16,-40,32,40),Color("24232d"))
	for y in range(-40,0,8):
		for x in [-24,16]:
			draw_texture_rect_region(MASONRY,Rect2(x,y,8,8),Rect2(32,48,8,8))
	for x in range(-24,24,8):
		draw_texture_rect_region(MASONRY,Rect2(x,-48,8,8),Rect2(48,32,8,8))
	draw_string(FONT,Vector2(-27,-53),"COURTYARD",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("f0d4a0"))
	if nearby:
		draw_string(FONT,Vector2(-18,-32),"UP: EXIT",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("fff1ca"))
