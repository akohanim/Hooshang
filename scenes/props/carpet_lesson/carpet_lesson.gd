extends Node2D
## Presentation and contextual instructions; LDtk owns all playable geometry.
const ORNAMENTS := preload("res://assets/props/sky_gardens/ornaments.png")
var world: LdtkWorld
var room: Node2D
var carpet: MagicCarpet
@onready var hint: Label = $Prompts/Hint

func _ready() -> void:
	room = get_parent()
	var ancestor: Node = room
	while ancestor != null and not ancestor is LdtkWorld: ancestor = ancestor.get_parent()
	world = ancestor as LdtkWorld
	room.set_meta("return_at_spawn_edge",true)
	for entity in room.get_node("Entities").get_children():
		if entity is MagicCarpet: carpet = entity
		var sign := entity.get_node_or_null("ExitSign")
		if sign != null: sign.hide()

func _process(_delta: float) -> void:
	hint.visible = world != null and world.current_room == room and not world.player.input_locked
	if not hint.visible: return
	var x := world.player.global_position.x-room.global_position.x
	if x > 800: hint.text = "THE GARDENS AHEAD"
	elif carpet != null and carpet.carrying(world.player): hint.text = "UP / DOWN: STEER    JUMP: DISMOUNT"
	elif world.player.state == Player.State.SWIM: hint.text = "SWIM TO EITHER BANK TO RECOVER"
	elif x >= 640: hint.text = "JUMP UP TO THE GARDENS"
	else: hint.text = "LAND ON THE CARPET TO RIDE"

func _draw() -> void:
	# Ornament stays behind the usable surface; the dock and portal are distinct.
	draw_texture_rect_region(ORNAMENTS,Rect2(20,248,18,24),Rect2(102,70,18,24))
	draw_texture_rect_region(ORNAMENTS,Rect2(916,170,32,46),Rect2(0,0,64,92))
