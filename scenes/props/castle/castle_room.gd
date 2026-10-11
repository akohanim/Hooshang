extends Node2D
## Presentation only. All masonry, water, ornaments and fruit are LDtk-authored.
const FONT := preload("res://assets/fonts/pixel5x7.fnt")
var interior := false
var room_size := Vector2.ZERO
@onready var entrance: Node2D = $Entrance

func _ready() -> void:
	var room := get_parent() as LDTKLevel
	interior = str(room.fields.get("wing", "")) == "CastleGatehouse"
	room_size = Vector2(room.size)
	room.set_meta("return_at_spawn_edge", true)
	room.get_node("CastleBackground").modulate = Color(0.54, 0.48, 0.47) if interior else Color(0.74, 0.71, 0.69)
	for exit in room.get_node("Entities").get_children():
		var sign := exit.get_node_or_null("ExitSign")
		if sign != null: sign.hide()
	entrance.draw.connect(_draw_entrance)
	queue_redraw()
	entrance.queue_redraw()

func _draw() -> void:
	if interior:
		draw_rect(Rect2(Vector2.ZERO, room_size), Color("29242b"))
		# Warm window recesses stay behind all solid surfaces and the player.
		for x in [32, 200, 400]:
			draw_rect(Rect2(x-8, 56, 48, 64), Color("58463c"))
	else:
		draw_rect(Rect2(448, 48, 192, 152), Color("524447"))

func _draw_entrance() -> void:
	# The entry arch is scenery; its physical opening remains unobstructed.
	var x := room_size.x - 64
	entrance.draw_rect(Rect2(x, 136, 48, 64), Color("211f29"))
	entrance.draw_rect(Rect2(x+4, 140, 40, 60), Color("40313a"))
	if interior:
		entrance.draw_string(FONT, Vector2(x-19, 128), "ASSEMBLY HALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("ffdf9e"))
