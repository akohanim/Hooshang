extends Node2D
## Toggle the collision-only graybox without rebuilding the level.
@export var graybox := false
var player: Player
var room: Node2D
func _ready() -> void:
	SaveGame.slot = -1
	room = $Imported/OfficeMaterialLab
	player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	player.position = room.get_node("Props/PlayerStart").position
	add_child(player)
	player.has_dash = true
	player.set_camera_limits(Rect2i(-64,-42,320,180))
	player.died.connect(_respawn)
	set_graybox(graybox)
func set_graybox(value: bool) -> void:
	graybox = value
	for child in room.get_children():
		if child is TileMapLayer:
			child.visible = value if child.name == "Solids-values" else not value and child.name != "BackgroundGeometry-values"
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		set_graybox(not graybox)
func _physics_process(_delta: float) -> void:
	if player and player.position.y > 120 and player.state != Player.State.DEAD:
		player.die()
func _respawn() -> void:
	await get_tree().create_timer(player.death_time).timeout
	player.respawn(room.get_node("Props/PlayerStart").position)
