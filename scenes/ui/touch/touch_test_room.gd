extends Node2D
## Opt-in browser diagnostic room. Never binds or writes a save slot.
var player: Player

func _ready() -> void:
	SaveGame.unbind()
	_floor(Vector2(160, 160), Vector2(320, 16))
	_floor(Vector2(0, 90), Vector2(8, 180))
	_floor(Vector2(320, 90), Vector2(8, 180))
	var ladder := preload("res://scenes/props/zones/Ladder.tscn").instantiate()
	ladder.position = Vector2(160, 120)
	ladder.height = 64
	add_child(ladder)
	player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	player.position = Vector2(160, 144)
	player.has_dash = true
	add_child(player)
	player.get_node("Camera2D").enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(160, 90)
	add_child(camera)
	TouchControls.enabled = true
	InputDevice.note_touch()

func _floor(at: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color("18232d"))
	for x in range(0, 321, 16):
		draw_line(Vector2(x, 70), Vector2(x, 152), Color("263944"))
	draw_rect(Rect2(0, 152, 320, 28), Color("69877e"))

func _physics_process(_delta: float) -> void:
	if player.position.y > 185:
		player.respawn(Vector2(160, 144))
